output "firewall_id" {
    description = "The Amazon Resource Name (ARN) that identifies the firewall."
    value = try(aws_networkfirewall_firewall.this_firewall.id,"")
}

output "firewall_arn" {
    description = "The Amazon Resource Name (ARN) that identifies the firewall."
    value = try(aws_networkfirewall_firewall.this_firewall.arn,"")

}

output "firewall_endpoint_ids" {
    description = "The identifier of the firewall endpoint that AWS Network Firewall has instantiated in the subnet. You use this to identify the firewall endpoint in the VPC route tables, when you redirect the VPC traffic through the endpoint."
    value = try([for ss in tolist(aws_networkfirewall_firewall.this_firewall.firewall_status[0].sync_states) : ss.attachment[0].endpoint_id],"")
}

