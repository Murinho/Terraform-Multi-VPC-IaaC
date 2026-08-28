output "state_bucket_name" {
  description = "Use this value in backend.hcl files."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  value = aws_s3_bucket.state.arn
}

output "live_state_key" {
  value = "multi-vpc-lifecycle/dev/terraform.tfstate"
}
