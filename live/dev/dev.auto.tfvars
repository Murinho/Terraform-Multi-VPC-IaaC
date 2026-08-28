aws_region  = "us-east-1"
environment = "dev"

consumer_vpc_cidr = "10.10.0.0/16"
service_vpc_cidr  = "10.20.0.0/16"

# Safe baseline.
connectivity_mode     = "peering"
allow_paid_networking = false
enable_compute        = false

# Verify account-specific eligibility before changing enable_compute to true.
instance_type = "t3.micro"

# Used later by the additive CIDR drill.
consumer_secondary_cidrs = []

# Used later by the import drill.
manage_imported_security_group = false
