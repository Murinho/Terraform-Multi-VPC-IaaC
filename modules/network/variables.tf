variable "name_prefix" {
  type = string
}

variable "availability_zone" {
  type = string
}

variable "consumer_vpc_cidr" {
  type = string

  validation {
    condition     = can(cidrsubnet(var.consumer_vpc_cidr, 8, 10))
    error_message = "consumer_vpc_cidr must be large enough to carve a /24-style child subnet."
  }
}

variable "service_vpc_cidr" {
  type = string

  validation {
    condition     = can(cidrsubnet(var.service_vpc_cidr, 8, 10))
    error_message = "service_vpc_cidr must be large enough to carve a /24-style child subnet."
  }
}

variable "consumer_secondary_cidrs" {
  description = "Additive CIDRs used for the replacement-avoidance drill."
  type        = set(string)
  default     = []
}

variable "connectivity_mode" {
  type = string

  validation {
    condition     = contains(["peering", "transit_gateway", "privatelink"], var.connectivity_mode)
    error_message = "connectivity_mode must be peering, transit_gateway, or privatelink."
  }
}

variable "manage_imported_security_group" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
