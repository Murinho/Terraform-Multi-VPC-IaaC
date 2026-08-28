variable "name_prefix" {
  type = string
}

variable "service_vpc_id" {
  type = string
}

variable "service_subnet_id" {
  type = string
}

variable "service_instance_id" {
  type = string
}

variable "consumer_vpc_id" {
  type = string
}

variable "consumer_vpc_cidr" {
  type = string
}

variable "consumer_subnet_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
