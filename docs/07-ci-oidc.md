# CI/CD: GitHub Actions with a speculative-plan role

## Security model

The workflow has two jobs:

```text
Untrusted/static job:
  checkout -> fmt -> init -backend=false -> validate -> terraform test
  No AWS credentials and no remote state.

Trusted plan job:
  GitHub OIDC -> short-lived AWS role -> remote-state read/lock -> refresh -> plan
  No AWS infrastructure writes, no terraform apply, no tfstate PutObject.
```

A speculative plan still needs to read AWS and remote state. It also needs temporary permission to create/delete the S3 lock object. The CI role therefore has:

- EC2/VPC, ELB, SSM, and STS read calls used by refresh and data sources.
- `s3:GetObject` for the exact state key.
- `s3:PutObject` and `s3:DeleteObject` only for the corresponding `.tflock` object.
- No `s3:PutObject` for the `.tfstate` object.
- No EC2, ELB, or VPC mutation calls.

This role can temporarily block another run by holding a lock, but it cannot apply infrastructure or overwrite state.

## 1. Push the repository to GitHub

Create the repository first so you know `owner/repository`.

## 2. Bootstrap the OIDC provider and role

```bash
cd bootstrap/ci
cp backend.hcl.example backend.hcl
cp terraform.tfvars.example terraform.tfvars
# Fill state bucket, region, github_owner, github_repository.
# The GitHub owner and repository must exactly match the repo slug.
terraform init -backend-config=backend.hcl
terraform plan -out=ci-bootstrap.tfplan
terraform apply ci-bootstrap.tfplan
terraform output
```

Repositories created after 2026-07-15 use immutable OIDC subject claims by default. For those repositories, also set `github_owner_id` and `github_repository_id` in `terraform.tfvars`. You can get both with:

```bash
gh api repos/OWNER/REPOSITORY --jq '{github_owner_id: .owner.id, github_repository_id: .id}'
```

If the account already has the GitHub Actions OIDC provider, set:

```hcl
create_github_oidc_provider = false
existing_oidc_provider_arn  = "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
```

## 3. Configure GitHub repository variables

Create these GitHub Actions repository variables:

```text
TF_PLAN_ROLE_ARN = output plan_role_arn
TF_STATE_BUCKET  = the state bucket name
TF_STATE_KEY     = multi-vpc-lifecycle/dev/terraform.tfstate
AWS_REGION       = us-east-1
```

The default live state key is:

```text
multi-vpc-lifecycle/dev/terraform.tfstate
```

## 4. Run CI

Open a pull request from a branch in the same repository. The static job runs without AWS. The plan job is intentionally skipped for fork-based pull requests because exposing state read access to untrusted workflow code is unsafe.

The workflow uploads the text plan as an artifact. It never calls `terraform apply`.

## 5. Add a protected apply stage only after the lab

A production apply job should use a separate role, protected GitHub Environment, human approval, branch protection, and the exact reviewed plan artifact. Do not reuse the broad local learning identity or the plan role.
