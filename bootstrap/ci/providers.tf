provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "multi-vpc-lifecycle"
      ManagedBy = "Terraform"
      Component = "ci-bootstrap"
    }
  }
}
