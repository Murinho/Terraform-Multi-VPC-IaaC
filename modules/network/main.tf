locals {
  consumer_subnet_cidr = cidrsubnet(var.consumer_vpc_cidr, 8, 10)
  service_subnet_cidr  = cidrsubnet(var.service_vpc_cidr, 8, 10)

  secondary_subnets = {
    for cidr in var.consumer_secondary_cidrs : cidr => cidrsubnet(cidr, 8, 10)
  }

  # Direct L3 traffic can arrive from consumer ranges. PrivateLink traffic
  # can be observed as a consumer address or an NLB node address depending on
  # target-group/client-IP behavior, so the lab permits both relevant ranges.
  service_ingress_cidrs = distinct(concat(
    [var.consumer_vpc_cidr, var.service_vpc_cidr],
    tolist(var.consumer_secondary_cidrs),
  ))
}

resource "aws_vpc" "consumer" {
  cidr_block           = var.consumer_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-consumer"
    Role = "consumer"
  })
}

resource "aws_vpc" "service" {
  cidr_block           = var.service_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-service"
    Role = "service"
  })
}

resource "aws_vpc_ipv4_cidr_block_association" "consumer_secondary" {
  for_each = var.consumer_secondary_cidrs

  vpc_id     = aws_vpc.consumer.id
  cidr_block = each.value
}

resource "aws_subnet" "consumer" {
  vpc_id                  = aws_vpc.consumer.id
  availability_zone       = var.availability_zone
  cidr_block              = local.consumer_subnet_cidr
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-consumer-private"
    Tier = "private"
  })
}

resource "aws_subnet" "service" {
  vpc_id                  = aws_vpc.service.id
  availability_zone       = var.availability_zone
  cidr_block              = local.service_subnet_cidr
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-service-private"
    Tier = "private"
  })
}

resource "aws_subnet" "consumer_secondary" {
  for_each = local.secondary_subnets

  vpc_id                  = aws_vpc.consumer.id
  availability_zone       = var.availability_zone
  cidr_block              = each.value
  map_public_ip_on_launch = false

  depends_on = [aws_vpc_ipv4_cidr_block_association.consumer_secondary]

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-consumer-secondary-${replace(replace(each.key, ".", "-"), "/", "-")}"
    Tier       = "private"
    Migration  = "additive-cidr"
    SourceCIDR = each.key
  })
}

resource "aws_route_table" "consumer" {
  vpc_id = aws_vpc.consumer.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-consumer"
  })
}

resource "aws_route_table" "service" {
  vpc_id = aws_vpc.service.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-service"
  })
}

resource "aws_route_table" "consumer_secondary" {
  for_each = local.secondary_subnets

  vpc_id = aws_vpc.consumer.id

  tags = merge(var.tags, {
    Name       = "${var.name_prefix}-consumer-secondary-${replace(replace(each.key, ".", "-"), "/", "-")}"
    SourceCIDR = each.key
  })
}

resource "aws_route_table_association" "consumer" {
  subnet_id      = aws_subnet.consumer.id
  route_table_id = aws_route_table.consumer.id
}

resource "aws_route_table_association" "service" {
  subnet_id      = aws_subnet.service.id
  route_table_id = aws_route_table.service.id
}

resource "aws_route_table_association" "consumer_secondary" {
  for_each = local.secondary_subnets

  subnet_id      = aws_subnet.consumer_secondary[each.key].id
  route_table_id = aws_route_table.consumer_secondary[each.key].id
}

# Deliberately authoritative inline rules make an out-of-band extra rule
# visible during the drift drill. See docs/02-drift.md before copying this
# pattern into a shared production module.
resource "aws_security_group" "service" {
  name        = "${var.name_prefix}-service"
  description = "Authoritative service rules for Terraform drift lab"
  vpc_id      = aws_vpc.service.id

  dynamic "ingress" {
    for_each = toset(local.service_ingress_cidrs)

    content {
      description = "HTTP lab traffic from ${ingress.value}"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "All IPv4 egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-service"
  })
}

resource "aws_security_group" "consumer" {
  name        = "${var.name_prefix}-consumer"
  description = "Consumer workload security group"
  vpc_id      = aws_vpc.consumer.id

  ingress = []

  egress {
    description = "All IPv4 egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-consumer"
  })
}

# ----------------------------- VPC peering -----------------------------

resource "aws_vpc_peering_connection" "this" {
  count = var.connectivity_mode == "peering" ? 1 : 0

  vpc_id      = aws_vpc.consumer.id
  peer_vpc_id = aws_vpc.service.id
  auto_accept = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-consumer-service"
  })
}

resource "aws_route" "consumer_to_service_peering" {
  count = var.connectivity_mode == "peering" ? 1 : 0

  route_table_id            = aws_route_table.consumer.id
  destination_cidr_block    = var.service_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this[0].id
}

resource "aws_route" "service_to_consumer_peering" {
  count = var.connectivity_mode == "peering" ? 1 : 0

  route_table_id            = aws_route_table.service.id
  destination_cidr_block    = var.consumer_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this[0].id
}

resource "aws_route" "consumer_secondary_to_service_peering" {
  for_each = var.connectivity_mode == "peering" ? local.secondary_subnets : {}

  route_table_id            = aws_route_table.consumer_secondary[each.key].id
  destination_cidr_block    = var.service_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this[0].id
}

resource "aws_route" "service_to_consumer_secondary_peering" {
  for_each = var.connectivity_mode == "peering" ? local.secondary_subnets : {}

  route_table_id            = aws_route_table.service.id
  destination_cidr_block    = each.key
  vpc_peering_connection_id = aws_vpc_peering_connection.this[0].id
}

# ----------------------------- Transit Gateway -----------------------------

resource "aws_ec2_transit_gateway" "this" {
  count = var.connectivity_mode == "transit_gateway" ? 1 : 0

  description                     = "${var.name_prefix} lifecycle lab"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"

  tags = merge(var.tags, {
    Name = var.name_prefix
  })
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  count = var.connectivity_mode == "transit_gateway" ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.this[0].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-shared"
  })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "consumer" {
  count = var.connectivity_mode == "transit_gateway" ? 1 : 0

  subnet_ids                                      = [aws_subnet.consumer.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.this[0].id
  vpc_id                                          = aws_vpc.consumer.id
  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-consumer"
  })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "service" {
  count = var.connectivity_mode == "transit_gateway" ? 1 : 0

  subnet_ids                                      = [aws_subnet.service.id]
  transit_gateway_id                              = aws_ec2_transit_gateway.this[0].id
  vpc_id                                          = aws_vpc.service.id
  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-service"
  })
}

resource "aws_ec2_transit_gateway_route_table_association" "consumer" {
  count = var.connectivity_mode == "transit_gateway" ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.consumer[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[0].id
}

resource "aws_ec2_transit_gateway_route_table_association" "service" {
  count = var.connectivity_mode == "transit_gateway" ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.service[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[0].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "consumer" {
  count = var.connectivity_mode == "transit_gateway" ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.consumer[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[0].id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "service" {
  count = var.connectivity_mode == "transit_gateway" ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.service[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[0].id
}

resource "aws_route" "consumer_to_service_tgw" {
  count = var.connectivity_mode == "transit_gateway" ? 1 : 0

  route_table_id         = aws_route_table.consumer.id
  destination_cidr_block = var.service_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.consumer]
}

resource "aws_route" "service_to_consumer_tgw" {
  count = var.connectivity_mode == "transit_gateway" ? 1 : 0

  route_table_id         = aws_route_table.service.id
  destination_cidr_block = var.consumer_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.service]
}

resource "aws_route" "consumer_secondary_to_service_tgw" {
  for_each = var.connectivity_mode == "transit_gateway" ? local.secondary_subnets : {}

  route_table_id         = aws_route_table.consumer_secondary[each.key].id
  destination_cidr_block = var.service_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.consumer]
}

resource "aws_route" "service_to_consumer_secondary_tgw" {
  for_each = var.connectivity_mode == "transit_gateway" ? local.secondary_subnets : {}

  route_table_id         = aws_route_table.service.id
  destination_cidr_block = each.key
  transit_gateway_id     = aws_ec2_transit_gateway.this[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.service]
}
