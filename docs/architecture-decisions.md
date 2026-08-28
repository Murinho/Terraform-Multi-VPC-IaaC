# Architecture decisions

## Modules are separated by ownership, not file count

- `network`: address space, subnets, route tables, connectivity, and network policy shells.
- `compute`: EC2 lifecycle and boot behavior. The same module is instantiated once as a service and once as a consumer probe.
- `application`: service exposure through an NLB and PrivateLink endpoint service/consumer endpoint.

The root module owns orchestration and passes only the IDs/attributes each layer needs.

## One AZ is deliberate for the lab

A production service should normally span multiple AZs. One AZ keeps TGW attachments, NLB nodes, interface endpoints, EBS, and data transfer small enough for a controlled exercise. High availability is out of scope; change safety is in scope.

## No NAT or public IP

The boot image already contains Bash and Python. User data starts the application and uses Bash TCP support for the probe, so no package repository is required. This removes NAT Gateway and public ingress from the learning path.

## Authoritative SG is an exercise-specific exception

The service SG uses inline rules so Terraform detects and removes a manually added extra rule. The PrivateLink endpoint SG demonstrates the normal composable pattern with standalone rule resources. The contrast is intentional.

## Native S3 locking

The backend uses `use_lockfile = true`. Lock permission is separable from state-write permission, allowing a CI plan role to coordinate while remaining unable to overwrite the state object.
