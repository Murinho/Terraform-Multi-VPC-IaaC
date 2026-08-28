variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  description = "S3 bucket that contains Terraform state."
  type        = string
}

variable "state_key" {
  description = "Exact live state object key the plan role may read."
  type        = string
  default     = "multi-vpc-lifecycle/dev/terraform.tfstate"
}

variable "github_owner" {
  description = "GitHub user or organization name."
  type        = string
}

variable "github_repository" {
  description = "Repository name without the owner."
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Set false when the AWS account already has GitHub's OIDC provider."
  type        = bool
  default     = true
}

variable "existing_oidc_provider_arn" {
  description = "Required when create_github_oidc_provider is false."
  type        = string
  default     = null
}
