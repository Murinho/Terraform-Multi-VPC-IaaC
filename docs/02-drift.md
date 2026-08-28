# Drill 1: create and reconcile security-group drift

## Objective

Observe the three-way comparison among configuration, Terraform state, and AWS reality.

The service security group intentionally uses authoritative inline rules for this drill. That means its configured rule set is treated as complete, so an extra console-created rule appears as drift. In normal reusable modules, standalone `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` resources are usually easier to compose; they do not automatically claim ownership of unrelated rules.

## 1. Establish a clean baseline

```bash
cd live/dev
terraform plan
```

Expected result: no changes.

Find the service SG:

```bash
terraform output -raw service_security_group_id
```

## 2. Mutate AWS outside Terraform

In **VPC console -> Security Groups**, select the service SG and add:

```text
Type:       Custom TCP
Port:       9999
Source:     consumer VPC CIDR, normally 10.10.0.0/16
Description: MANUAL-DRIFT-DRILL
```

This is an out-of-band control-plane write. Terraform state still records the old rule set.

## 3. Detect drift

```bash
terraform plan -out=drift.tfplan
```

During refresh, the provider reads the current SG. Terraform then compares it with HCL and proposes removing the unmanaged port 9999 rule.

Useful contrast:

```bash
terraform plan -refresh=false
```

That command may not detect the console mutation because it deliberately trusts prior state instead of refreshing AWS. Do not use `-refresh=false` as a normal drift strategy.

## 4. Reconcile intentionally

Choose one owner:

- **Terraform owns the rule set:** apply `drift.tfplan`; the manual rule is removed.
- **The new rule is desired:** add it to reviewed HCL, create a new plan, and apply that plan.

For the lab, let Terraform remove it:

```bash
terraform apply drift.tfplan
terraform plan
```

## What this teaches

Drift is not automatically "bad." Emergency changes can be appropriate. The dangerous condition is unacknowledged drift with unclear ownership. The safe workflow is detect, understand, encode or revert, review, and reconcile.
