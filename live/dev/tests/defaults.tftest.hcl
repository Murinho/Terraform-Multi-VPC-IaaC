mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  mock_data "aws_ssm_parameter" {
    defaults = {
      value = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/mock"
      user_id    = "AIDAMOCK"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }
}

run "safe_defaults" {
  command = plan

  variables {
    connectivity_mode              = "peering"
    allow_paid_networking          = false
    enable_compute                 = false
    consumer_secondary_cidrs       = []
    manage_imported_security_group = false
  }

  assert {
    condition     = output.connectivity_mode == "peering"
    error_message = "The default connection must be VPC peering."
  }

  assert {
    condition     = output.paid_networking_enabled == false
    error_message = "Paid networking must require explicit opt-in."
  }

  assert {
    condition     = output.compute_enabled == false
    error_message = "Compute must be disabled by default."
  }

  assert {
    condition     = length(module.application) == 0
    error_message = "The PrivateLink application module must not exist by default."
  }

  assert {
    condition     = module.network.transit_gateway_id == null
    error_message = "No Transit Gateway should exist in the default plan."
  }
}

run "additive_secondary_cidr" {
  command = plan

  variables {
    connectivity_mode        = "peering"
    allow_paid_networking    = false
    enable_compute           = false
    consumer_secondary_cidrs = ["10.30.0.0/16"]
  }

  assert {
    condition     = module.network.consumer_vpc_cidr == "10.10.0.0/16"
    error_message = "Adding a secondary CIDR must preserve the original primary VPC CIDR."
  }

  assert {
    condition     = length(module.network.consumer_secondary_subnet_ids) == 1
    error_message = "One secondary CIDR should produce one additive subnet."
  }
}

run "paid_mode_requires_explicit_opt_in" {
  command = plan

  variables {
    connectivity_mode     = "transit_gateway"
    allow_paid_networking = false
    enable_compute        = false
  }

  expect_failures = [terraform_data.guardrails]
}
