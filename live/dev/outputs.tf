output "connectivity_mode" {
  value = var.connectivity_mode
}

output "paid_networking_enabled" {
  value = var.allow_paid_networking
}

output "compute_enabled" {
  value = var.enable_compute
}

output "selected_availability_zone" {
  value = local.selected_az
}

output "consumer_vpc_id" {
  value = module.core_network.consumer_vpc_id
}

output "service_vpc_id" {
  value = module.core_network.service_vpc_id
}

output "consumer_route_table_id" {
  value = module.core_network.consumer_route_table_id
}

output "service_route_table_id" {
  value = module.core_network.service_route_table_id
}

output "consumer_security_group_id" {
  value = module.core_network.consumer_security_group_id
}

output "service_security_group_id" {
  value = module.core_network.service_security_group_id
}

output "peering_connection_id" {
  value = module.core_network.peering_connection_id
}

output "transit_gateway_id" {
  value = module.core_network.transit_gateway_id
}

output "service_instance_id" {
  value = try(module.service_compute[0].instance_id, null)
}

output "service_instance_private_ip" {
  value = try(module.service_compute[0].private_ip, null)
}

output "consumer_instance_id" {
  value = try(module.consumer_compute[0].instance_id, null)
}

output "interface_endpoint_id" {
  value = try(module.application[0].interface_endpoint_id, null)
}

output "interface_endpoint_dns_name" {
  value = try(module.application[0].interface_endpoint_dns_name, null)
}

output "network_load_balancer_arn" {
  value = try(module.application[0].network_load_balancer_arn, null)
}
