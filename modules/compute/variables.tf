variable "name" {
  type = string
}

variable "role" {
  type = string

  validation {
    condition     = contains(["service", "probe"], var.role)
    error_message = "role must be service or probe."
  }
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "probe_target_host" {
  type    = string
  default = "127.0.0.1"
}

variable "tags" {
  type    = map(string)
  default = {}
}
