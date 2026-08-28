data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023_ami" {
  count = var.enable_compute ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "terraform_data" "guardrails" {
  input = {
    mode            = var.connectivity_mode
    paid_opt_in     = var.allow_paid_networking
    compute_enabled = var.enable_compute
  }

  lifecycle {
    precondition {
      condition     = var.connectivity_mode == "peering" || var.allow_paid_networking
      error_message = "Transit Gateway and PrivateLink are billable. Set allow_paid_networking=true only for the short paid drill."
    }

    precondition {
      condition     = var.connectivity_mode != "privatelink" || var.enable_compute
      error_message = "PrivateLink mode needs enable_compute=true so the NLB has a service target and the consumer has a probe."
    }

    precondition {
      condition = alltrue([
        for cidr in var.consumer_secondary_cidrs :
        cidr != var.consumer_vpc_cidr && cidr != var.service_vpc_cidr
      ])
      error_message = "Secondary CIDRs must differ from the two primary VPC CIDRs."
    }
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix                     = local.name_prefix
  availability_zone               = local.selected_az
  consumer_vpc_cidr               = var.consumer_vpc_cidr
  service_vpc_cidr                = var.service_vpc_cidr
  consumer_secondary_cidrs        = var.consumer_secondary_cidrs
  connectivity_mode               = var.connectivity_mode
  manage_imported_security_group  = var.manage_imported_security_group
  tags                            = local.common_tags

  depends_on = [terraform_data.guardrails]
}

module "service_compute" {
  count  = var.enable_compute ? 1 : 0
  source = "../../modules/compute"

  name               = "${local.name_prefix}-service"
  role               = "service"
  ami_id             = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type      = var.instance_type
  subnet_id          = module.network.service_subnet_id
  security_group_ids = [module.network.service_security_group_id]
  tags               = local.common_tags
}

module "application" {
  count  = var.connectivity_mode == "privatelink" && var.enable_compute ? 1 : 0
  source = "../../modules/application"

  name_prefix        = local.name_prefix
  service_vpc_id     = module.network.service_vpc_id
  service_subnet_id  = module.network.service_subnet_id
  service_instance_id = module.service_compute[0].instance_id

  consumer_vpc_id     = module.network.consumer_vpc_id
  consumer_vpc_cidr   = module.network.consumer_vpc_cidr
  consumer_subnet_id  = module.network.consumer_subnet_id
  tags                = local.common_tags
}

locals {
  probe_target_host = var.connectivity_mode == "privatelink" ? try(
    module.application[0].interface_endpoint_dns_name,
    "pending.invalid",
  ) : try(module.service_compute[0].private_ip, "127.0.0.1")
}

module "consumer_compute" {
  count  = var.enable_compute ? 1 : 0
  source = "../../modules/compute"

  name               = "${local.name_prefix}-consumer"
  role               = "probe"
  ami_id             = data.aws_ssm_parameter.al2023_ami[0].value
  instance_type      = var.instance_type
  subnet_id          = module.network.consumer_subnet_id
  security_group_ids = [module.network.consumer_security_group_id]
  probe_target_host  = local.probe_target_host
  tags               = local.common_tags
}
