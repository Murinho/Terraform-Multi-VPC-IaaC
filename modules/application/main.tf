data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
}

resource "aws_lb" "service" {
  name               = substr("${var.name_prefix}-pl", 0, 32)
  internal           = true
  load_balancer_type = "network"
  subnets            = [var.service_subnet_id]

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-privatelink"
  })
}

resource "aws_lb_target_group" "service" {
  name        = substr("${var.name_prefix}-pl", 0, 32)
  port        = 8080
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = var.service_vpc_id

  health_check {
    enabled  = true
    protocol = "TCP"
    port     = "traffic-port"
  }

  tags = var.tags
}

resource "aws_lb_target_group_attachment" "service" {
  target_group_arn = aws_lb_target_group.service.arn
  target_id        = var.service_instance_id
  port             = 8080
}

resource "aws_lb_listener" "service" {
  load_balancer_arn = aws_lb.service.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }
}

resource "aws_vpc_endpoint_service" "service" {
  acceptance_required        = false
  network_load_balancer_arns = [aws_lb.service.arn]
  allowed_principals         = [local.account_root_arn]

  depends_on = [aws_lb_listener.service]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-service"
  })
}

resource "aws_security_group" "endpoint" {
  name        = "${var.name_prefix}-endpoint"
  description = "Interface endpoint for the lifecycle lab"
  vpc_id      = var.consumer_vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-endpoint"
  })
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_http" {
  security_group_id = aws_security_group.endpoint.id
  description       = "Consumers in this VPC can reach the endpoint"
  cidr_ipv4         = var.consumer_vpc_cidr
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "endpoint_all" {
  security_group_id = aws_security_group.endpoint.id
  description       = "Stateful response and service traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_endpoint" "service" {
  vpc_id              = var.consumer_vpc_id
  service_name        = aws_vpc_endpoint_service.service.service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.consumer_subnet_id]
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-service"
  })
}
