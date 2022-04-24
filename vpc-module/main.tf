locals {
  max_subnet_length = max(
    length(var.private_subnets)
  )
  nat_gateway_count = var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.max_subnet_length

  # Use `local.vpc_id` to give a hint to Terraform that subnets should be deleted before secondary CIDR blocks can be free!
  vpc_id = try(aws_vpc_ipv4_cidr_block_association.this[0].vpc_id, aws_vpc.this[0].id, "")

  create_vpc = var.create_vpc
}

################################################################################
# VPC
################################################################################

resource "aws_vpc" "this" {
  count = local.create_vpc ? 1 : 0

  cidr_block                       = var.cidr
  instance_tenancy                 = var.instance_tenancy
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_dns_support               = var.enable_dns_support
  enable_classiclink               = var.enable_classiclink
  enable_classiclink_dns_support   = var.enable_classiclink_dns_support
  assign_generated_ipv6_cidr_block = var.enable_ipv6

  tags = merge(
    { "Name" = var.name },
    var.tags,
    var.vpc_tags
  )
}

resource "aws_vpc_ipv4_cidr_block_association" "this" {
  count = local.create_vpc && length(var.secondary_cidr_blocks) > 0 ? length(var.secondary_cidr_blocks) : 0

  # Do not turn this into `local.vpc_id`
  vpc_id = aws_vpc.this[0].id

  cidr_block = element(var.secondary_cidr_blocks, count.index)
}

resource "aws_default_security_group" "this" {
  count = local.create_vpc && var.manage_default_security_group ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  dynamic "ingress" {
    for_each = var.default_security_group_ingress
    content {
      self             = lookup(ingress.value, "self", null)
      cidr_blocks      = compact(split(",", lookup(ingress.value, "cidr_blocks", "")))
      ipv6_cidr_blocks = compact(split(",", lookup(ingress.value, "ipv6_cidr_blocks", "")))
      prefix_list_ids  = compact(split(",", lookup(ingress.value, "prefix_list_ids", "")))
      security_groups  = compact(split(",", lookup(ingress.value, "security_groups", "")))
      description      = lookup(ingress.value, "description", null)
      from_port        = lookup(ingress.value, "from_port", 0)
      to_port          = lookup(ingress.value, "to_port", 0)
      protocol         = lookup(ingress.value, "protocol", "-1")
    }
  }

  dynamic "egress" {
    for_each = var.default_security_group_egress
    content {
      self             = lookup(egress.value, "self", null)
      cidr_blocks      = compact(split(",", lookup(egress.value, "cidr_blocks", "")))
      ipv6_cidr_blocks = compact(split(",", lookup(egress.value, "ipv6_cidr_blocks", "")))
      prefix_list_ids  = compact(split(",", lookup(egress.value, "prefix_list_ids", "")))
      security_groups  = compact(split(",", lookup(egress.value, "security_groups", "")))
      description      = lookup(egress.value, "description", null)
      from_port        = lookup(egress.value, "from_port", 0)
      to_port          = lookup(egress.value, "to_port", 0)
      protocol         = lookup(egress.value, "protocol", "-1")
    }
  }

  tags = merge(
    { "Name" = coalesce(var.default_security_group_name, var.name, "sg") },
    var.tags,
    var.default_security_group_tags
  )
}

################################################################################
# DHCP Options Set
################################################################################

resource "aws_vpc_dhcp_options" "this" {
  count = local.create_vpc && var.enable_dhcp_options ? 1 : 0

  domain_name          = var.dhcp_options_domain_name
  domain_name_servers  = var.dhcp_options_domain_name_servers
  ntp_servers          = var.dhcp_options_ntp_servers
  netbios_name_servers = var.dhcp_options_netbios_name_servers
  netbios_node_type    = var.dhcp_options_netbios_node_type

  tags = merge(
    { "Name" = coalesce(var.name, "dhcp-option-set") },
    var.tags,
    var.dhcp_options_tags
  )
}

resource "aws_vpc_dhcp_options_association" "this" {
  count = local.create_vpc && var.enable_dhcp_options ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

################################################################################
# Internet Gateway
################################################################################

resource "aws_internet_gateway" "this" {
  count = local.create_vpc && var.create_igw && length(var.firewall_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = var.name != "" ? "${var.name}-${var.vpc_tags.Name}-igw" : "${var.vpc_tags.Name}-igw" },
    var.tags,
    var.igw_tags
  )
}

resource "aws_egress_only_internet_gateway" "this" {
  count = local.create_vpc && var.create_egress_only_igw && var.enable_ipv6 && local.max_subnet_length > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = coalesce(var.name, var.vpc_tags.Name != null ? "${var.vpc_tags.Name}-eigw" : "eigw") },
    var.tags,
    var.igw_tags
  )
}

################################################################################
# Default route
################################################################################

resource "aws_default_route_table" "default" {
  count = local.create_vpc && var.manage_default_route_table ? 1 : 0

  default_route_table_id = aws_vpc.this[0].default_route_table_id
  propagating_vgws       = var.default_route_table_propagating_vgws

  dynamic "route" {
    for_each = var.default_route_table_routes
    content {
      # One of the following destinations must be provided
      cidr_block      = route.value.cidr_block
      ipv6_cidr_block = lookup(route.value, "ipv6_cidr_block", null)

      # One of the following targets must be provided
      egress_only_gateway_id    = lookup(route.value, "egress_only_gateway_id", null)
      gateway_id                = lookup(route.value, "gateway_id", null)
      instance_id               = lookup(route.value, "instance_id", null)
      nat_gateway_id            = lookup(route.value, "nat_gateway_id", null)
      network_interface_id      = lookup(route.value, "network_interface_id", null)
      transit_gateway_id        = lookup(route.value, "transit_gateway_id", null)
      vpc_endpoint_id           = lookup(route.value, "vpc_endpoint_id", null)
      vpc_peering_connection_id = lookup(route.value, "vpc_peering_connection_id", null)
    }
  }

  timeouts {
    create = "5m"
    update = "5m"
  }

  tags = merge(
    { "Name" = coalesce(var.name, var.default_route_table_name, "default-route-table") },
    var.tags,
    var.default_route_table_tags
  )
}

################################################################################
# Publiс routes
################################################################################

resource "aws_route_table" "firewall" {
  count = local.create_vpc && length(var.firewall_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = var.name != "" ? "rt-${var.name}-${var.firewall_subnet_suffix}" : "rt-${var.firewall_subnet_suffix}"
    },
    var.tags,
    var.firewall_route_table_tags,
  )
}

resource "aws_route" "firewall_internet_gateway" {
  count = local.create_vpc && var.create_igw && length(var.firewall_subnets) > 0 ? 1 : 0

  route_table_id         = aws_route_table.firewall[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "firewall_internet_gateway_ipv6" {
  count = local.create_vpc && var.create_igw && var.enable_ipv6 && length(var.firewall_subnets) > 0 ? 1 : 0

  route_table_id              = aws_route_table.firewall[0].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this[0].id
}


################################################################################
# Ingress Route associated to the IGW
################################################################################

resource "aws_route_table" "ingress" {
  count  = var.create_igw && local.create_vpc && length(var.protected_subnets) > 0 ? 1 : 0
  vpc_id = local.vpc_id
  tags = merge(
    { "Name" = "rt-igw-ingress" },
    var.tags,
    var.ingress_route_table_tags,
  )
  depends_on = [
    aws_subnet.protected
  ]
}

resource "aws_route" "ingress" {
  count                  = local.create_vpc && var.create_igw && length(var.firewall_subnets) > 0 ? length(var.firewall_subnets) : 0
  route_table_id         = aws_route_table.ingress[0].id
  destination_cidr_block = element(var.protected_subnets, count.index)
  # Force the vpc firewall endpoint's AZ to be associated with the fw subnet in the same/corresponding AZ 
  vpc_endpoint_id = aws_subnet.firewall.*.id[count.index] == var.firewall_endpoint_id_subnet_id_mapping[count.index] ? var.firewall_endpoint_ids[count.index] : element(var.firewall_endpoint_ids, count.index + 1)

}


################################################################################
# Private routes
# There are as many routing tables as the number of NAT gateways
################################################################################

resource "aws_route_table" "private" {
  count = local.create_vpc && local.max_subnet_length > 0 ? local.nat_gateway_count : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "rt-${var.name}-rt-private" : format(
        var.name != "" ? "rt-${var.name}-private-%s" : "rt-private-%s",
        element(var.azs, count.index)
      )
    },
    var.tags,
    var.private_route_table_tags
  )
}

################################################################################
# Protected routes
# There are as many routing tables as the number of NAT gateways
################################################################################

resource "aws_route_table" "protected" {
  count = local.create_vpc && local.max_subnet_length > 0 ? local.nat_gateway_count : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "rt-${var.name}-rt-protected" : format(
        var.name != "" ? "rt-${var.name}-protected-%s" : "rt-protected-%s",
        element(var.azs, count.index),
      )
    },
    var.tags,
    var.protected_route_table_tags
  )
}

resource "aws_route" "protected" {
  count                  = local.create_vpc && var.create_igw && length(var.protected_subnets) > 0 ? length(var.protected_subnets) : 0
  route_table_id         = aws_route_table.protected.* [count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # Force the vpc firewall endpoint's AZ to be associated with the fw subnet in the same/corresponding AZ 
  vpc_endpoint_id = aws_subnet.firewall.*.id[count.index] == var.firewall_endpoint_id_subnet_id_mapping[count.index] ? var.firewall_endpoint_ids[count.index] : element(var.firewall_endpoint_ids, count.index + 1)

}

resource "aws_route" "protected_v6" {
  count                       = local.create_vpc && var.create_egress_only_igw == false && var.enable_ipv6 && var.create_igw ? length(var.protected_subnets) : 0
  route_table_id              = aws_route_table.protected[0].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this[0].id
}

################################################################################
# Firewall subnet
################################################################################

resource "aws_subnet" "firewall" {
  count = local.create_vpc && length(var.firewall_subnets) > 0 && (false == var.one_nat_gateway_per_az || length(var.firewall_subnets) >= length(var.azs)) ? length(var.firewall_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = element(concat(var.firewall_subnets, [""]), count.index)
  availability_zone               = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id            = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  map_public_ip_on_launch         = var.map_public_ip_on_launch
  assign_ipv6_address_on_creation = var.firewall_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.firewall_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.firewall_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this[0].ipv6_cidr_block, 8, var.firewall_subnet_ipv6_prefixes[count.index]) : null

  tags = merge(
    {
      "Name" = format(
        "${var.subnets_prefix}-${var.firewall_subnet_suffix}-%s",
        element(var.azs, count.index),
      )
    },
    var.tags,
    var.firewall_subnet_tags
  )
}

################################################################################
# Protected subnet
################################################################################

resource "aws_subnet" "protected" {
  count = local.create_vpc && length(var.protected_subnets) > 0 && (false == var.one_nat_gateway_per_az || length(var.protected_subnets) >= length(var.azs)) ? length(var.protected_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = element(concat(var.protected_subnets, [""]), count.index)
  availability_zone               = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id            = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  map_public_ip_on_launch         = var.map_public_ip_on_launch
  assign_ipv6_address_on_creation = var.protected_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.protected_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.protected_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this[0].ipv6_cidr_block, 8, var.protected_subnet_ipv6_prefixes[count.index]) : null

  tags = merge(
    {
      "Name" = format(
        "${var.subnets_prefix}-${var.protected_subnet_suffix}-%s",
        element(var.azs, count.index),
      )
    },
    var.tags,
    var.protected_subnet_tags
  )
}


################################################################################
# Private subnet
################################################################################

resource "aws_subnet" "private" {
  count = local.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  vpc_id                          = local.vpc_id
  cidr_block                      = var.private_subnets[count.index]
  availability_zone               = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) > 0 ? element(var.azs, count.index) : null
  availability_zone_id            = length(regexall("^[a-z]{2}-", element(var.azs, count.index))) == 0 ? element(var.azs, count.index) : null
  assign_ipv6_address_on_creation = var.private_subnet_assign_ipv6_address_on_creation == null ? var.assign_ipv6_address_on_creation : var.private_subnet_assign_ipv6_address_on_creation

  ipv6_cidr_block = var.enable_ipv6 && length(var.private_subnet_ipv6_prefixes) > 0 ? cidrsubnet(aws_vpc.this[0].ipv6_cidr_block, 8, var.private_subnet_ipv6_prefixes[count.index]) : null

  tags = merge(
    {
      "Name" = format(
        var.private_subnet_suffix != "" ?
        "${var.subnets_prefix}-${element(var.private_subnets_mapping, count.index)}-${var.private_subnet_suffix}-%s" : "${var.subnets_prefix}-${element(var.private_subnets_mapping, count.index)}-%s",
        element(var.azs, count.index),
      )
    },
    var.tags,
    var.private_subnet_tags
  )
}



resource "aws_route" "private_ipv6_egress" {
  count = local.create_vpc && var.create_egress_only_igw && var.enable_ipv6 ? length(var.private_subnets) : 0

  route_table_id              = element(aws_route_table.private[*].id, count.index)
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = element(aws_egress_only_internet_gateway.this[*].id, 0)
}

resource "aws_route" "private_ipv6_igw" {
  count = local.create_vpc && var.create_egress_only_igw == false && var.enable_ipv6 && var.create_igw ? length(var.private_subnets) : 0

  route_table_id              = element(aws_route_table.private[*].id, count.index)
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this[0].id

}


################################################################################
# Default Network ACLs
################################################################################

resource "aws_default_network_acl" "this" {
  count = local.create_vpc && var.manage_default_network_acl ? 1 : 0

  default_network_acl_id = aws_vpc.this[0].default_network_acl_id

  # subnet_ids is using lifecycle ignore_changes, so it is not necessary to list
  # any explicitly. See https://github.com/terraform-aws-modules/terraform-aws-vpc/issues/736.
  subnet_ids = null

  dynamic "ingress" {
    for_each = var.default_network_acl_ingress
    content {
      action          = ingress.value.action
      cidr_block      = lookup(ingress.value, "cidr_block", null)
      from_port       = ingress.value.from_port
      icmp_code       = lookup(ingress.value, "icmp_code", null)
      icmp_type       = lookup(ingress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(ingress.value, "ipv6_cidr_block", null)
      protocol        = ingress.value.protocol
      rule_no         = ingress.value.rule_no
      to_port         = ingress.value.to_port
    }
  }
  dynamic "egress" {
    for_each = var.default_network_acl_egress
    content {
      action          = egress.value.action
      cidr_block      = lookup(egress.value, "cidr_block", null)
      from_port       = egress.value.from_port
      icmp_code       = lookup(egress.value, "icmp_code", null)
      icmp_type       = lookup(egress.value, "icmp_type", null)
      ipv6_cidr_block = lookup(egress.value, "ipv6_cidr_block", null)
      protocol        = egress.value.protocol
      rule_no         = egress.value.rule_no
      to_port         = egress.value.to_port
    }
  }

  tags = merge(
    { "Name" = coalesce(var.default_network_acl_name, var.name) },
    var.tags,
    var.default_network_acl_tags,
  )

  lifecycle {
    ignore_changes = [subnet_ids]
  }
}

################################################################################
# Firewall Network ACLs
################################################################################

resource "aws_network_acl" "firewall" {
  count = local.create_vpc && var.firewall_dedicated_network_acl && length(var.firewall_subnets) > 0 ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = aws_subnet.firewall[*].id

  tags = merge(
    {
      "Name" = var.name != "" ? "${var.name}-acl-${var.firewall_subnet_suffix}" : "acl-${var.firewall_subnet_suffix}"
    },
    var.tags,
    var.firewall_acl_tags
  )
}

resource "aws_network_acl_rule" "firewall_inbound" {
  count = local.create_vpc && var.firewall_dedicated_network_acl && length(var.firewall_subnets) > 0 ? length(var.firewall_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.firewall[0].id

  egress          = false
  rule_number     = var.firewall_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.firewall_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.firewall_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.firewall_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.firewall_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.firewall_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.firewall_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.firewall_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.firewall_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "firewall_outbound" {
  count = local.create_vpc && var.firewall_dedicated_network_acl && length(var.firewall_subnets) > 0 ? length(var.firewall_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.firewall[0].id

  egress          = true
  rule_number     = var.firewall_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.firewall_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.firewall_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.firewall_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.firewall_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.firewall_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.firewall_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.firewall_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.firewall_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

################################################################################
# Private Network ACLs
################################################################################

resource "aws_network_acl" "private" {
  count = local.create_vpc && var.private_dedicated_network_acl && length(var.private_subnets) > 0 ? 1 : 0

  vpc_id     = local.vpc_id
  subnet_ids = aws_subnet.private[*].id

  tags = merge(
    {
      "Name" = var.name != "" ? "${var.name}-acl-${var.private_subnet_suffix}" : "acl-${var.private_subnet_suffix}"
    },
    var.tags,
    var.private_acl_tags
  )
}

resource "aws_network_acl_rule" "private_inbound" {
  count = local.create_vpc && var.private_dedicated_network_acl && length(var.private_subnets) > 0 ? length(var.private_inbound_acl_rules) : 0

  network_acl_id = aws_network_acl.private[0].id

  egress          = false
  rule_number     = var.private_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.private_inbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.private_inbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.private_inbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.private_inbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.private_inbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.private_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.private_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.private_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "private_outbound" {
  count = local.create_vpc && var.private_dedicated_network_acl && length(var.private_subnets) > 0 ? length(var.private_outbound_acl_rules) : 0

  network_acl_id = aws_network_acl.private[0].id

  egress          = true
  rule_number     = var.private_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.private_outbound_acl_rules[count.index]["rule_action"]
  from_port       = lookup(var.private_outbound_acl_rules[count.index], "from_port", null)
  to_port         = lookup(var.private_outbound_acl_rules[count.index], "to_port", null)
  icmp_code       = lookup(var.private_outbound_acl_rules[count.index], "icmp_code", null)
  icmp_type       = lookup(var.private_outbound_acl_rules[count.index], "icmp_type", null)
  protocol        = var.private_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.private_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.private_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

################################################################################
# NAT Gateway
################################################################################

locals {
  nat_gateway_ips = var.reuse_nat_ips ? var.external_nat_ip_ids : try(aws_eip.nat[*].id, [])
}

resource "aws_eip" "nat" {
  count = local.create_vpc && var.enable_nat_gateway && false == var.reuse_nat_ips ? local.nat_gateway_count : 0

  vpc = true

  tags = merge(
    {
      "Name" = format(
        var.name != "" ? "${var.name}-%s" : "eip-%s", element(var.azs, var.single_nat_gateway ? 0 : count.index)
      )
    },
    var.tags,
    var.nat_eip_tags
  )
}

resource "aws_nat_gateway" "this" {
  count = local.create_vpc && var.enable_nat_gateway ? local.nat_gateway_count : 0

  allocation_id = element(
    local.nat_gateway_ips,
    var.single_nat_gateway ? 0 : count.index,
  )
  # Nat gateway has to be created in the "protected" subnet
  subnet_id = element(
    aws_subnet.protected[*].id,
    var.single_nat_gateway ? 0 : count.index,
  )

  tags = merge(
    {
      "Name" = format(
        var.name != "" ? "${var.name}-%s" : "nat-gw-%s", element(var.azs, var.single_nat_gateway ? 0 : count.index),
      )
    },
    var.tags,
    var.nat_gateway_tags
  )

  depends_on = [aws_internet_gateway.this]

}

resource "aws_route" "private_nat_gateway" {
  count = local.create_vpc && var.enable_nat_gateway ? local.nat_gateway_count : 0

  route_table_id         = element(aws_route_table.private[*].id, count.index)
  destination_cidr_block = var.nat_gateway_destination_cidr_block
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)

  timeouts {
    create = "5m"
  }
}


################################################################################
# Route table association
################################################################################

resource "aws_route_table_association" "private" {
  count = local.create_vpc && length(var.private_subnets) > 0 ? length(var.private_subnets) : 0

  subnet_id = element(aws_subnet.private[*].id, count.index)
  route_table_id = element(
    aws_route_table.private[*].id,
    var.single_nat_gateway ? 0 : count.index,
  )
}

resource "aws_route_table_association" "protected" {
  count = local.create_vpc && length(var.protected_subnets) > 0 ? length(var.protected_subnets) : 0

  subnet_id = element(aws_subnet.protected[*].id, count.index)
  route_table_id = element(
    aws_route_table.protected[*].id,
    var.single_nat_gateway ? 0 : count.index,
  )
}

resource "aws_route_table_association" "firewall" {
  count = local.create_vpc && length(var.firewall_subnets) > 0 ? length(var.firewall_subnets) : 0

  subnet_id      = element(aws_subnet.firewall[*].id, count.index)
  route_table_id = aws_route_table.firewall[0].id
}

resource "aws_route_table_association" "ingress" {
  count = local.create_vpc && var.create_igw == true ? 1 : 0
  #count = 1
  gateway_id     = aws_internet_gateway.this[0].id
  route_table_id = aws_route_table.ingress[0].id

}

################################################################################
# Customer Gateways
################################################################################

resource "aws_customer_gateway" "this" {
  for_each = var.customer_gateways

  bgp_asn     = each.value["bgp_asn"]
  ip_address  = each.value["ip_address"]
  device_name = lookup(each.value, "device_name", null)
  type        = "ipsec.1"

  tags = merge(
    {
      Name = var.name != "" ? "cgw-${var.name}-${each.key}" : "cgw-${each.key}"
    },
    var.tags,
    var.customer_gateway_tags
  )
}

################################################################################
# VPN Gateway
################################################################################

resource "aws_vpn_gateway" "this" {
  count = local.create_vpc && var.enable_vpn_gateway ? 1 : 0

  vpc_id            = local.vpc_id
  amazon_side_asn   = var.amazon_side_asn
  availability_zone = var.vpn_gateway_az

  tags = merge(
    {
      "Name" = var.name != "" ? "vpn-gw-${var.name}-${var.vpc_tags.Name}" : "vpn-gw-${var.vpc_tags.Name}"
    },
    var.tags,
    var.vpn_gateway_tags
  )
}

resource "aws_vpn_gateway_attachment" "this" {
  count = var.vpn_gateway_id != "" ? 1 : 0

  vpc_id         = local.vpc_id
  vpn_gateway_id = var.vpn_gateway_id
}

resource "aws_vpn_gateway_route_propagation" "firewall" {
  count = local.create_vpc && var.propagate_firewall_route_tables_vgw && (var.enable_vpn_gateway || var.vpn_gateway_id != "") ? 1 : 0

  route_table_id = element(aws_route_table.firewall[*].id, count.index)
  vpn_gateway_id = element(
    concat(
      aws_vpn_gateway.this[*].id,
      aws_vpn_gateway_attachment.this[*].vpn_gateway_id,
    ),
    count.index
  )
}

resource "aws_vpn_gateway_route_propagation" "private" {
  count = local.create_vpc && var.propagate_private_route_tables_vgw && (var.enable_vpn_gateway || var.vpn_gateway_id != "") ? length(var.private_subnets) : 0

  route_table_id = element(aws_route_table.private[*].id, count.index)
  vpn_gateway_id = element(
    concat(
      aws_vpn_gateway.this[*].id,
      aws_vpn_gateway_attachment.this[*].vpn_gateway_id,
    ),
    count.index
  )
}

################################################################################
# Defaults
################################################################################

resource "aws_default_vpc" "this" {
  count = var.manage_default_vpc ? 1 : 0

  enable_dns_support   = var.default_vpc_enable_dns_support
  enable_dns_hostnames = var.default_vpc_enable_dns_hostnames
  enable_classiclink   = var.default_vpc_enable_classiclink

  tags = merge(
    { "Name" = coalesce(var.default_vpc_name, "default") },
    var.tags,
    var.default_vpc_tags
  )
}
