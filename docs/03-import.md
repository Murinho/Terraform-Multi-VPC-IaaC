# Drill 2: import a resource created outside Terraform

## Objective

Adopt an existing AWS security group without recreating it.

Import changes Terraform state; it does not magically author a correct resource block. This repository already contains an optional matching block in `modules/network/imported.tf`.

## 1. Create the object manually

Find the consumer VPC ID:

```bash
cd live/dev
terraform output -raw consumer_vpc_id
```

In **VPC console -> Security Groups**, create:

```text
Name:        tf-lifecycle-dev-imported
Description: Imported observer security group
VPC:         the consumer VPC from the output
Inbound:     none
Outbound:    allow all IPv4
```

Add tags if convenient:

```text
Name        = tf-lifecycle-dev-imported
Project     = multi-vpc-lifecycle
Environment = dev
ManagedBy   = Terraform
```

Copy the resulting `sg-...` ID.

## 2. Enable the matching HCL, but do not apply

In `dev.auto.tfvars`:

```hcl
manage_imported_security_group = true
```

```bash
terraform plan
```

Terraform proposes creating a new SG because the address exists in configuration but has no state binding. Do not apply that plan.

## 3. Import the AWS identity into the resource address

Before the moved-block drill, the address is:

```bash
terraform import \
  'module.network.aws_security_group.imported[0]' \
  'sg-REPLACE_WITH_REAL_ID'
```

Then:

```bash
terraform state show 'module.network.aws_security_group.imported[0]'
terraform plan -out=post-import.tfplan
```

A small in-place tag or rule normalization is acceptable. A proposed destroy/create means the HCL does not match an immutable attribute such as VPC, name, or description; fix the configuration before applying.

## 4. Declarative alternative

Terraform 1.5 and newer also supports reviewable import blocks. Copy `live/dev/imports.tf.example` to `imports.tf`, replace the ID, and run `terraform plan`/`terraform apply`. An import block can remain as documentation; after the import succeeds it becomes a no-op for the already managed object.

## Mental model

```text
Before import:
  HCL address -----------------> no remote identity in state
  AWS SG ----------------------> exists independently

After import:
  HCL address -- state binding --> sg-0123456789abcdef0 in AWS
```
