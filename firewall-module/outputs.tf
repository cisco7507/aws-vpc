output "firewall_id" {
  description = "The Amazon Resource Name (ARN) that identifies the firewall."
  value       = try(aws_networkfirewall_firewall.this_firewall.id, "")
}

output "firewall_arn" {
  description = "The Amazon Resource Name (ARN) that identifies the firewall."
  value       = try(aws_networkfirewall_firewall.this_firewall.arn, "")

}

output "firewall_endpoint_ids" {
  description = "The identifier of the firewall endpoint that AWS Network Firewall has instantiated in the subnet. You use this along with \"firewall_endpoint_id_subnet_id_mapping\" to identify the firewall endpoint in the VPC route tables, when you redirect the VPC traffic through the endpoint."
  value = try([for i in [for ss in tolist(aws_networkfirewall_firewall.this_firewall.firewall_status[0].sync_states) : ss.attachment[0]] : i][*].endpoint_id, "")
}

output "firewall_endpoint_id_subnet_id_mapping" {
  description = "The Subnet_id where the firewall vpc-endpoint is created. Use this along with firewall_endpoint_ids to ensure the firewall vpc_id used for routing is associated with the route table in the corresponding AZ"
  value       = try([for i in [for ss in tolist(aws_networkfirewall_firewall.this_firewall.firewall_status[0].sync_states) : ss.attachment[0]] : i][*].subnet_id, "")
}


