output "network_load_balancer_arn" {
  value = aws_lb.service.arn
}

output "endpoint_service_name" {
  value = aws_vpc_endpoint_service.service.service_name
}

output "interface_endpoint_id" {
  value = aws_vpc_endpoint.service.id
}

output "interface_endpoint_dns_name" {
  value = tolist(aws_vpc_endpoint.service.dns_entry)[0].dns_name
}
