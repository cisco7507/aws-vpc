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

variable "customer_gateways" {
  description = "Maps of Customer Gateway's attributes (BGP ASN and Gateway's Internet-routable external IP address)"
  default = {
    ON1 = {
      "bgp_asn"     = "21775"
      "ip_address"  = "66.199.183.4"
      "device_name" = "ON1-ASA"
    }
    Office = {
      "bgp_asn"     = "21775"
      "ip_address"  = "199.15.87.4"
      "device_name" = "FTD"

    }
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  default = {
    "Owner"       = "user"
    "Environment" = "dev"
  }
}

variable "vpc_tags" {
  description = "Additional tags for the VPC"
  default = {
    Name = "on1-dr-vpc"
  }

}
