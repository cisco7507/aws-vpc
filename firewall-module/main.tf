terraform {
  required_version = ">= 0.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.63"
    }
  }
}
provider "aws" {
  region = "us-west-2"
}

resource "aws_networkfirewall_firewall_policy" "test" {
  name = "example"

  firewall_policy {
    stateless_default_actions          = ["aws:pass"]
    stateless_fragment_default_actions = ["aws:pass"]

  }
}

resource "aws_networkfirewall_firewall" "this_firewall" {
  name                = var.firewall_name
  firewall_policy_arn = aws_networkfirewall_firewall_policy.test.arn
  vpc_id              = var.vpc_id
  description         = var.firewall_description

  dynamic "subnet_mapping" {
    for_each = var.firewall_subnets[*]

    content {
      subnet_id = subnet_mapping.value
    }
  }

}