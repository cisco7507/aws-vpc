variable "cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "10.101.64.0/20"
}

variable "firewall_name" {
  description = "The Name of the firewall to be created"
  type        = string
  default     = "NetworkFirewall"
}

variable "firewall_description" {
  description = "(Optional) A friendly description of the firewall."
  default     = ""
}

