module "vpc" {
  source                              = "../vpc-module"
  subnets_prefix                      = "subnet-ec2"
  cidr                                = var.cidr
  azs                                 = local.azs
  firewall_subnets                    = [for i in range(16, 18, 1) : cidrsubnet(var.cidr, 8, i)]
  protected_subnets                   = [for i in range(2, 4, 1) : cidrsubnet(var.cidr, 4, i)]
  private_subnets                     = [for i in range(4, 10, 1) : cidrsubnet(var.cidr, 4, i)]
  enable_ipv6                         = true
  create_egress_only_igw              = false
  private_subnets_mapping             = ["srs", "srs", "services", "services", "db", "db"]
  private_subnet_ipv6_prefixes        = [4, 5, 6, 7, 8, 9]
  protected_subnet_ipv6_prefixes      = [2, 3]
  firewall_subnet_ipv6_prefixes       = [0, 1]
  enable_nat_gateway                  = true
  single_nat_gateway                  = false
  one_nat_gateway_per_az              = true
  firewall_endpoint_ids               = module.firewall.firewall_endpoint_ids
  enable_vpn_gateway                  = true
  propagate_private_route_tables_vgw  = true
  propagate_firewall_route_tables_vgw = true
  customer_gateways                   = var.customer_gateways
  vpc_tags                            = var.vpc_tags
}

module "firewall" {
  source               = "../firewall-module"
  vpc_id               = module.vpc.vpc_id
  firewall_name        = var.firewall_name
  firewall_subnets     = module.vpc.firewall_subnets
  firewall_description = var.firewall_description

}