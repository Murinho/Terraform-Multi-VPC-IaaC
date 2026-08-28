# Cost and safety boundary

The repository distinguishes **structural learning** from **billable packet-path testing**.

## Baseline

The default plan creates VPCs, subnets, route tables, security groups, and an in-region VPC peering connection. These objects do not create the hourly charges associated with NAT Gateway, Transit Gateway, load balancers, or interface endpoints. Ordinary data-transfer and S3 state request/storage charges can still apply.

## Explicitly disabled by default

### Compute

`enable_compute = false` prevents EC2 and EBS creation. Instance-type Free Tier eligibility depends on the account's AWS Free Tier program and usage. The lab also assigns no public IPv4 addresses and creates no NAT Gateway.

### Transit Gateway

TGW mode creates one transit gateway and two VPC attachments. Attachments accrue hourly charges; data processing adds usage charges. The root precondition requires both:

```hcl
connectivity_mode     = "transit_gateway"
allow_paid_networking = true
```

### PrivateLink

PrivateLink mode creates an internal Network Load Balancer, a VPC endpoint service, one interface endpoint, and two EC2 instances. NLB and interface-endpoint hourly/usage charges apply. The root precondition additionally requires `enable_compute = true`.

## Guardrails before every apply

```bash
terraform plan -out=tfplan
terraform show tfplan
```

Search the plan for these resource types before approval:

```text
aws_ec2_transit_gateway
aws_ec2_transit_gateway_vpc_attachment
aws_lb
aws_vpc_endpoint
aws_instance
```

Create a small AWS Budget notification before the paid phases. A budget is an alerting control, not a hard spending cap.
