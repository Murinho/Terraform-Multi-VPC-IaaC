variable "aws_region" {
  description = "AWS Region that stores the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "bucket_prefix" {
  description = "Globally unique bucket prefix; account ID and Region are appended."
  type        = string
  default     = "tf-multivpc-lifecycle-state"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,29}$", var.bucket_prefix))
    error_message = "Use 3-30 lowercase letters, digits, or hyphens, starting with a letter or digit."
  }
}

variable "common_tags" {
  description = "Tags placed on bootstrap resources."
  type        = map(string)
  default = {
    Project   = "multi-vpc-lifecycle"
    ManagedBy = "Terraform"
  }
}
