output "consumer_vpc_id" {
  value = aws_vpc.consumer.id
}

output "service_vpc_id" {
  value = aws_vpc.service.id
}

output "consumer_vpc_cidr" {
  value = var.consumer_vpc_cidr
}

output "service_vpc_cidr" {
  value = var.service_vpc_cidr
}

output "consumer_subnet_id" {
  value = aws_subnet.consumer.id
}

output "service_subnet_id" {
  value = aws_subnet.service.id
}

output "consumer_secondary_subnet_ids" {
  value = { for cidr, subnet in aws_subnet.consumer_secondary : cidr => subnet.id }
}

output "consumer_route_table_id" {
  value = aws_route_table.consumer.id
}

output "service_route_table_id" {
  value = aws_route_table.service.id
}

output "consumer_security_group_id" {
  value = aws_security_group.consumer.id
}

output "service_security_group_id" {
  value = aws_security_group.service.id
}

output "peering_connection_id" {
  value = try(aws_vpc_peering_connection.this[0].id, null)
}

output "transit_gateway_id" {
  value = try(aws_ec2_transit_gateway.this[0].id, null)
}

output "connectivity_mode" {
  value = var.connectivity_mode
}
