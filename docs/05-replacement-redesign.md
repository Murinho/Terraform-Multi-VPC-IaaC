# Drill 4: inspect a replacement and redesign it as an additive migration

## Objective

Do not blindly accept `-/+`. Understand which provider/API constraint caused replacement and redesign the rollout.

## 1. Deliberately request a dangerous primary-CIDR change

In `dev.auto.tfvars`, temporarily change:

```hcl
consumer_vpc_cidr = "10.30.0.0/16"
```

Run a plan only:

```bash
terraform plan -out=replace-vpc.tfplan
terraform show replace-vpc.tfplan
```

The primary CIDR of an existing VPC is not a mutable field in this Terraform resource model. The VPC therefore shows `-/+`, and replacement cascades to subnets, route tables, peering/TGW attachments, security groups, and optional instances.

**Do not apply this plan.** A valid plan is not automatically a safe rollout.

## 2. Find the force-replacement signal

In the human-readable plan, inspect the attribute annotated with `# forces replacement`. Also inspect the dependency blast radius rather than focusing only on the first resource.

## 3. Redesign as expand -> migrate -> contract

Restore:

```hcl
consumer_vpc_cidr = "10.10.0.0/16"
```

Then add:

```hcl
consumer_secondary_cidrs = ["10.30.0.0/16"]
```

The network module models secondary CIDR associations, a new private subnet, route table association, and connectivity routes. Run:

```bash
terraform plan -out=expand.tfplan
```

Expected shape: additive creates and route updates, but no replacement of the original VPC.

Apply only after confirming the old VPC identity remains:

```bash
OLD_VPC_ID=$(terraform output -raw consumer_vpc_id)
terraform apply expand.tfplan
NEW_VPC_ID=$(terraform output -raw consumer_vpc_id)
test "$OLD_VPC_ID" = "$NEW_VPC_ID" && echo 'VPC identity preserved'
```

## 4. Production migration logic

A real migration would proceed in stages:

```text
Expand:   associate new CIDR; create new subnets/routes/security policy
Migrate:  move workloads and dependencies in controlled batches
Verify:   traffic, DNS, observability, rollback path, capacity
Contract: remove old subnets, then disassociate old secondary CIDRs when empty
```

The original primary CIDR cannot simply be disassociated. If it truly must disappear, a new VPC and a workload migration may be the correct architecture. Terraform cannot remove an AWS API constraint; it helps expose the consequence before execution.
