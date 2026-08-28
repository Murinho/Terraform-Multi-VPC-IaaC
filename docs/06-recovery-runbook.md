# Recovery runbook: failed apply, stale lock, and state damage

Use this as an operational checklist. Do not improvise state mutations under pressure.

## A. Apply failed partway through

1. **Stop parallel writers.** Pause CI apply jobs and ask teammates not to run Terraform against the same state key.
2. **Preserve evidence.** Save the full Terraform error, the plan file, run URL, timestamp, state key, AWS request ID, and CloudTrail event when available.
3. **Do not roll back by editing state.** Some operations may already have succeeded in AWS and been recorded.
4. **Reinitialize the exact revision and provider lock file.** Use the same commit that produced the failed apply.
5. **Refresh and inspect.** Run `terraform plan` normally. Use `terraform state list` and `terraform state show ADDRESS` for the failed objects, and inspect AWS through its API/console.
6. **Classify the cause.** Common classes are transient API failure, missing permission, quota, invalid immutable change, dependency ordering/eventual consistency, or an out-of-band mutation.
7. **Correct configuration or prerequisites.** Prefer an HCL fix or permission/quota correction over manual state surgery.
8. **Create a new plan.** Never assume the old saved plan is still valid after partial execution.
9. **Apply and verify.** Check both Terraform outputs and the AWS data plane.

Terraform operations are intended to be convergent. Replanning after a partial apply is usually safer than attempting to reverse every successful API call manually.

## B. State is locked

First determine whether the lock is legitimate.

```bash
ps aux | grep '[t]erraform'
# Check CI workflow runs using the same backend key.
terraform plan -lock-timeout=5m
```

If an active run exists, let it finish or cancel it cleanly. If there is no active writer and the lock is demonstrably stale, use the lock ID printed by Terraform:

```bash
terraform force-unlock LOCK_ID
```

Read the prompt carefully. Force-unlock removes coordination; it does not repair state. Never force-unlock merely because another legitimate apply is slow.

Break-glass fallback: inspect the S3 `.tflock` object and its metadata/version history. Delete it manually only when `force-unlock` cannot work, the owning process is certainly dead, and the action is peer-reviewed.

## C. Suspected state corruption or wrong state version

1. Block all writers.
2. Back up what Terraform currently sees:

```bash
terraform state pull > state-backup-$(date +%Y%m%d-%H%M%S).json
```

3. Inspect S3 object versions for the state key. Do not overwrite the current version yet.
4. Compare lineage, serial, resource addresses, and AWS identities.
5. Prefer restoring an S3 object version through S3 versioning after peer review.
6. Use `terraform state push` only as an expert break-glass operation. A wrong lineage/serial or stale snapshot can orphan or duplicate management relationships.
7. Run a normal plan and verify every unexpected operation before applying.

## D. Wrong workspace, account, region, or backend key

Before every recovery action:

```bash
terraform workspace show
terraform providers
aws sts get-caller-identity
aws configure get region
```

Inspect `backend.hcl` and the initialized backend. Many apparent "Terraform deleted everything" incidents are actually plans against an empty or wrong state key.

## E. Preventive controls

- S3 versioning and encryption.
- Native S3 lockfile.
- One state key per environment.
- Saved and reviewed plans.
- CI plan role without apply or state-write permissions.
- Protected apply environment with human approval.
- Provider lock file committed in a real repository.
- Backups before state commands.
