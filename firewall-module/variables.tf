variable "firewall_name" {
  description = "The Name of the firewall to be created"
  type        = string
}

variable "vpc_id" {
  description = "The VPC Id associated with the firewall"
}

variable "firewall_subnets" {
  description = "Subnets to which the firewall will attach and create its endpoints"
}

variable "firewall_description" {
  description = "(Optional) A friendly description of the firewall."
}