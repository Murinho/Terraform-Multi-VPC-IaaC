locals {
  service_user_data = templatefile("${path.module}/templates/service.sh.tftpl", {
    name = var.name
  })

  probe_user_data = templatefile("${path.module}/templates/probe.sh.tftpl", {
    target_host = var.probe_target_host
  })

  selected_user_data = var.role == "service" ? local.service_user_data : local.probe_user_data
}

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  associate_public_ip_address = false
  user_data                   = local.selected_user_data
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = var.name
    Role = var.role
  })
}
