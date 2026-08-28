variable "aws_region" {
  description = "Single AWS Region used by the lab."
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Optional explicit AZ. Null selects the first available AZ."
  type        = string
  default     = null
}

variable "project_name" {
  type    = string
  default = "multi-vpc-lifecycle"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "consumer_vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "service_vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "consumer_secondary_cidrs" {
  description = "Secondary consumer CIDRs for an additive migration."
  type        = set(string)
  default     = []
}

variable "connectivity_mode" {
  description = "peering, transit_gateway, or privatelink."
  type        = string
  default     = "peering"

  validation {
    condition     = contains(["peering", "transit_gateway", "privatelink"], var.connectivity_mode)
    error_message = "connectivity_mode must be peering, transit_gateway, or privatelink."
  }
}

variable "allow_paid_networking" {
  description = "Explicit acknowledgement required for TGW or PrivateLink."
  type        = bool
  default     = false
}

variable "enable_compute" {
  description = "Create private service/probe EC2 instances."
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "Verify account-specific Free Tier eligibility before enabling compute."
  type        = string
  default     = "t3.micro"
}

variable "manage_imported_security_group" {
  description = "Enable only during the import drill."
  type        = bool
  default     = false
}
