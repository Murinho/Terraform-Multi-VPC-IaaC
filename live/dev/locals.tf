locals {
  name_prefix = "tf-lifecycle-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Repository  = "terraform-multivpc-lifecycle-lab"
  }

  selected_az = coalesce(var.availability_zone, data.aws_availability_zones.available.names[0])
}
