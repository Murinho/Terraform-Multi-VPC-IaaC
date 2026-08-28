# Terraform Multi-VPC Lifecycle and Change-Safety Lab

This repository turns a two-VPC networking exercise into a small production-style Terraform system. The baseline is intentionally inexpensive: two VPCs, private subnets, route tables, security groups, and VPC peering. Compute, Transit Gateway, and PrivateLink are opt-in.

The main learning objective is not memorizing HCL. It is learning Terraform's operating model:

```text
Configuration (.tf) + prior state + refreshed AWS reality
                         |
                         v
                    Terraform plan
                         |
                 reviewed change set
                         |
                         v
                    Terraform apply
```

Terraform does not "run a script from top to bottom." It builds a dependency graph, refreshes remote objects, compares desired configuration with state and AWS, and proposes graph operations.

## Architecture

```text
Low-cost default: connectivity_mode = "peering"

  Consumer VPC 10.10.0.0/16                   Service VPC 10.20.0.0/16
  +--------------------------------+           +--------------------------------+
  | private subnet 10.10.10.0/24   |           | private subnet 10.20.10.0/24   |
  | route table                    |===========| route table                    |
  | optional probe EC2             |  peering  | optional HTTP EC2 :8080        |
  +--------------------------------+           +--------------------------------+

Optional paid phase: connectivity_mode = "transit_gateway"

  Consumer VPC ---- TGW attachment ---- Transit Gateway ---- TGW attachment ---- Service VPC

Optional paid phase: connectivity_mode = "privatelink"

  Consumer EC2 -> Interface endpoint ENI -> PrivateLink -> internal NLB -> Service EC2 :8080
  There is no consumer-to-service VPC route in this mode; only the service is exposed.
```

## Repository layout

```text
bootstrap/state/       Create the versioned, encrypted S3 state bucket
bootstrap/ci/          Create a GitHub OIDC plan-only role
modules/network/       VPCs, subnets, routes, peering/TGW, security groups
modules/compute/       One private EC2 workload; instantiated for server and probe
modules/application/   PrivateLink service: NLB, endpoint service, interface endpoint
live/dev/              Root composition, committed environment inputs, backend, outputs, tests
docs/                  Guided lifecycle drills and recovery runbook
.github/workflows/     Formatting, validation, mock tests, speculative plan
```

## Safety defaults

| Setting | Default | Why |
|---|---:|---|
| `connectivity_mode` | `peering` | No hourly TGW or PrivateLink resources |
| `allow_paid_networking` | `false` | A precondition blocks TGW/PrivateLink by accident |
| `enable_compute` | `false` | No EC2 or EBS by default |
| Public IPv4 addresses | none | Instances remain private and avoid public-address exposure/cost |
| NAT Gateway | none | The boot scripts install no packages and require no egress |
| Availability Zones | one | Keeps this learning environment small; not a production HA design |

## Recommended sequence

1. Read [Cost and safety](docs/01-cost-and-safety.md).
2. Install Terraform and authenticate the AWS CLI.
3. Bootstrap the S3 backend in `bootstrap/state`.
4. Initialize and apply `live/dev` in peering mode.
5. Inspect state, graph, AWS routes, and peering.
6. Add GitHub Actions OIDC and run CI.
7. Perform the [drift drill](docs/02-drift.md).
8. Perform the [import drill](docs/03-import.md).
9. Perform the [moved-block drill](docs/04-moved-block.md).
10. Perform the [replacement redesign drill](docs/05-replacement-redesign.md).
11. Briefly enable TGW and PrivateLink only after reading their cost gates.
12. Practice the [recovery runbook](docs/06-recovery-runbook.md).
13. Destroy the live stack, then separately decide whether to retain the protected state bucket.

The detailed commands are in [the guided build](docs/00-guided-build.md). `live/dev/dev.auto.tfvars` is intentionally committed because it contains desired environment configuration, not credentials; CI must plan the same inputs that operators apply.
