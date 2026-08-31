aws_region  = "us-east-1"
environment = "dev"

consumer_vpc_cidr = "10.10.0.0/16"
service_vpc_cidr  = "10.20.0.0/16"

# Safe baseline.
connectivity_mode     = "privatelink"
allow_paid_networking = true
enable_compute        = true

# Verify account-specific eligibility before changing enable_compute to true.
instance_type = "t3.micro"

# Used later by the additive CIDR drill.
consumer_secondary_cidrs = ["10.30.0.0/16"]

# Used later by the import drill.
manage_imported_security_group = true
