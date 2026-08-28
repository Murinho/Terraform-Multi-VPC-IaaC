# Drill 3: rename a module without destroying infrastructure

## Objective

Refactor a Terraform address while preserving the same AWS objects.

Terraform identity is address-based. Renaming `module.network` to `module.core_network` without migration makes the old address appear removed and the new address appear added. A `moved` block tells Terraform that this is identity continuity, not replacement.

## 1. Confirm a clean state

```bash
cd live/dev
terraform plan
```

Commit the repository or copy `main.tf` before editing.

## 2. Rename the module call

In `main.tf`, change:

```hcl
module "network" {
```

to:

```hcl
module "core_network" {
```

Update references from `module.network.` to `module.core_network.` throughout `live/dev`.

## 3. Add the migration declaration

Create `moved.tf`:

```hcl
moved {
  from = module.network
  to   = module.core_network
}
```

If `imports.tf` still exists from the previous drill, also update its destination address to `module.core_network...`.

## 4. Prove that this is not a recreate

```bash
terraform fmt
terraform validate
terraform plan -out=move.tfplan
terraform show move.tfplan
```

Expected plan messages say resources "have moved" and show zero destroys caused by the refactor. Apply the move so the remote state records the new addresses:

```bash
terraform apply move.tfplan
terraform state list | grep core_network
```

Keep the `moved` block in version control until every long-lived environment has upgraded through this refactor. Removing it too early breaks environments whose state still uses the old address.

## Why `terraform state mv` is not the first choice here

`terraform state mv` can perform the same state mutation interactively, but a `moved` block is declarative, reviewable, repeatable across environments, and visible in CI plans.
