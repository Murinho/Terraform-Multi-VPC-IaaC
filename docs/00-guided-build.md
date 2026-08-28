# Guided build: from an empty AWS account to reviewed infrastructure changes

Run commands from the repository root unless a step says otherwise. Examples use `us-east-1`; choose one region and use it consistently.

## 0. Prerequisites and identity check

Install Terraform 1.10 or newer and AWS CLI v2. Configure a non-root AWS identity for the lab. For a personal sandbox, broad permissions are convenient during learning, but the GitHub CI role created later is deliberately read-only.

```bash
terraform version
aws --version
aws sts get-caller-identity
```

Set a shell profile when you use named AWS credentials:

```bash
export AWS_PROFILE=terraform-lab
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
```

Why this matters: the Terraform AWS provider uses the same standard credential chain as AWS tooling. Credentials do not belong in `.tf` or `.tfvars` files.

## 1. Create the remote-state bucket

The backend is infrastructure too, but it cannot store its own first state before it exists. This is the bootstrap problem. We create it once with local state, then use it for all later stacks.

```bash
cd bootstrap/state
cp dev.auto.tfvars.example dev.auto.tfvars
# Edit bucket_prefix and aws_region.
terraform init
terraform fmt -check
terraform validate
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan
terraform output
```

Copy the bucket output. The bucket has versioning, server-side encryption, public-access blocking, `force_destroy = false`, and `prevent_destroy = true`. Retiring it requires an explicit code change plus removal of all object versions and delete markers.

Keep `bootstrap/state/terraform.tfstate` private and backed up. It is the small root-of-trust state for the backend itself.

## 2. Configure the live backend

```bash
cd ../../live/dev
cp backend.hcl.example backend.hcl
# Review the committed, non-secret dev.auto.tfvars file.
```

Edit `backend.hcl`:

```hcl
bucket       = "YOUR-OUTPUT-BUCKET"
key          = "multi-vpc-lifecycle/dev/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
```

Initialize:

```bash
terraform init -backend-config=backend.hcl
terraform providers
terraform validate
terraform test
```

`terraform init` does three different jobs here: initializes the S3 backend, downloads providers, and resolves child modules. It does not create AWS networking resources.

## 3. Read the first plan as an execution graph

```bash
terraform plan -out=peering.tfplan
terraform show peering.tfplan
```

Before applying, verify these invariants:

- Two VPCs and one private subnet in each.
- No EC2 instances because `enable_compute = false`.
- One VPC peering connection and reciprocal routes.
- No Transit Gateway, NLB, endpoint service, or interface endpoint.
- No Internet Gateway, NAT Gateway, or public IPv4 address.

Apply exactly the reviewed file:

```bash
terraform apply peering.tfplan
```

Why save a plan? `terraform apply` without a plan computes a fresh plan. Applying the saved plan preserves the reviewed set of operations, provided the state lock and dependency checks still succeed.

## 4. Inspect AWS and Terraform from both sides

Terraform's state is an index from resource addresses to AWS object identities. It is not the cloud itself.

```bash
terraform state list
terraform state show 'module.network.aws_vpc.consumer'
terraform output
```

Inspect the corresponding AWS control-plane objects:

```bash
PEERING_ID=$(terraform output -raw peering_connection_id)
aws ec2 describe-vpc-peering-connections --vpc-peering-connection-ids "$PEERING_ID"

CONSUMER_RT=$(terraform output -raw consumer_route_table_id)
SERVICE_RT=$(terraform output -raw service_route_table_id)
aws ec2 describe-route-tables --route-table-ids "$CONSUMER_RT" "$SERVICE_RT"
```

The route table chooses the peering connection as the next hop for the opposite VPC's CIDR. The peering object does not insert routes automatically.

## 5. Optional packet test without SSH, NAT, or public IPs

First verify which instance type is eligible for your account. Free Tier eligibility varies by account age and offer; do not assume the example type is free.

```bash
aws ec2 describe-instance-types \
  --filters Name=free-tier-eligible,Values=true \
  --query 'InstanceTypes[*].InstanceType' \
  --output text
```

Edit `dev.auto.tfvars`:

```hcl
enable_compute = true
instance_type   = "YOUR_ELIGIBLE_SMALL_TYPE"
```

Then:

```bash
terraform plan -out=compute.tfplan
terraform apply compute.tfplan
```

The service instance starts a tiny Python HTTP server on port 8080. The consumer instance makes an HTTP request through its private address and writes the result to the EC2 serial console:

```bash
CONSUMER_ID=$(terraform output -raw consumer_instance_id)
aws ec2 get-console-output \
  --instance-id "$CONSUMER_ID" \
  --latest \
  --query Output \
  --output text
```

There is intentionally no SSH path. The exercise tests data-plane connectivity while avoiding public ingress, keys, bastions, NAT, and package installation.

Turn compute back off after the test:

```bash
# Set enable_compute = false
terraform plan -out=remove-compute.tfplan
terraform apply remove-compute.tfplan
```

## 6. Run the lifecycle drills

Continue in this order:

- [Security-group drift](02-drift.md)
- [Import an externally created security group](03-import.md)
- [Rename the network module with a moved block](04-moved-block.md)
- [Turn a replacement proposal into an additive migration](05-replacement-redesign.md)
- [Configure GitHub Actions OIDC](07-ci-oidc.md)
- [Practice recovery](06-recovery-runbook.md)

## 7. Brief Transit Gateway phase

Read the cost notes first. Set:

```hcl
connectivity_mode      = "transit_gateway"
allow_paid_networking  = true
enable_compute         = false
```

```bash
terraform plan -out=tgw.tfplan
terraform apply tgw.tfplan
terraform output transit_gateway_id
```

Inspect the TGW, its two VPC attachments, the TGW route table, propagation, and the VPC route tables. Billing begins while the attachments exist, even with no traffic.

Return immediately to peering:

```hcl
connectivity_mode     = "peering"
allow_paid_networking = false
```

```bash
terraform plan -out=remove-tgw.tfplan
terraform apply remove-tgw.tfplan
```

## 8. Brief PrivateLink phase

Set an account-eligible instance type, then:

```hcl
connectivity_mode     = "privatelink"
allow_paid_networking = true
enable_compute        = true
```

Apply and inspect:

```bash
terraform plan -out=privatelink.tfplan
terraform apply privatelink.tfplan
terraform output
```

Expected path:

```text
consumer instance
  -> endpoint DNS
  -> interface endpoint ENI in consumer subnet
  -> AWS PrivateLink service
  -> internal NLB in service VPC
  -> service instance:8080
```

Notice that there is no route to `10.20.0.0/16` in the consumer route table. PrivateLink exposes a service, not the provider VPC.

Fetch the probe output, then disable compute and return to peering immediately.

## 9. Cleanup

```bash
# In live/dev, restore safe defaults first.
terraform plan -destroy -out=destroy.tfplan
terraform apply destroy.tfplan
```

Confirm that paid resources are gone:

```bash
aws ec2 describe-transit-gateways \
  --filters Name=tag:Project,Values=multi-vpc-lifecycle
aws ec2 describe-vpc-endpoints \
  --filters Name=tag:Project,Values=multi-vpc-lifecycle
aws elbv2 describe-load-balancers
```

Do not immediately destroy `bootstrap/state`; it contains versioned state history and can support future labs. When you intentionally retire it, empty all object versions and delete markers first, then destroy the bootstrap stack.
