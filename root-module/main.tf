provider "aws" {
  region = local.region
}

locals {
  region = "us-west-2"
}

locals {
  azs = ["${local.region}a", "${local.region}b"]
}

################################################################################
# VPC Module
################################################################################

module "vpc" {
  source = "../vpc-module"
  name   = "ec2-subnet"
  cidr   = var.cidr
  azs    = local.azs
  # This is the Firewall Subnet
  firewall_subnets = [for i in range(16, 18, 1) : cidrsubnet(var.cidr, 8, i)]
  protected_subnets = [for i in range(2, 4, 1) : cidrsubnet(var.cidr, 4, i)]
  private_subnets = [for i in range(4, 10, 1) : cidrsubnet(var.cidr, 4, i)]
  enable_ipv6 = true
  create_egress_only_igw = false

  /* Assigns IPv6 private subnet id based on the Amazon provided /56 prefix base 10 integer (0-256). 
  Must be of equal length to the corresponding IPv4 subnet list */

  private_subnet_ipv6_prefixes   = [4, 5, 6, 7, 8, 9]
  protected_subnet_ipv6_prefixes = [2, 3]
  firewall_subnet_ipv6_prefixes  = [0, 1]

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  
  firewall_endpoint_ids  = module.firewall.firewall_endpoint_ids
  
  enable_vpn_gateway = true
  propagate_private_route_tables_vgw = true
  propagate_firewall_route_tables_vgw = true
  customer_gateways = {
    "ON1" = {
      "bgp_asn" = "21775"
      "ip_address" = "66.199.183.4"
      "device_name" = "ON1-ASA" 
    }
  }
  customer_gateway_tags = {
    Name = "ON1-ASA-cgw"
  }

  tags = {
    Owner       = "user"
    Environment = "dev"
  }
  vpc_tags = {
    Name = "on1-dr-vpc"
  }
 
}

module "firewall" {
  source               = "../firewall-module"
  vpc_id               = module.vpc.vpc_id
  firewall_name        = var.firewall_name
  firewall_subnets     = module.vpc.firewall_subnets
  firewall_description = "Test Firewall-1"

}