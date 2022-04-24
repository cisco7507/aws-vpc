<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13.1 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.63 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.63 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_networkfirewall_firewall.this_firewall](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkfirewall_firewall) | resource |
| [aws_networkfirewall_firewall_policy.test](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/networkfirewall_firewall_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_firewall_description"></a> [firewall\_description](#input\_firewall\_description) | (Optional) A friendly description of the firewall. | `any` | n/a | yes |
| <a name="input_firewall_name"></a> [firewall\_name](#input\_firewall\_name) | The Name of the firewall to be created | `string` | n/a | yes |
| <a name="input_firewall_subnets"></a> [firewall\_subnets](#input\_firewall\_subnets) | Subnets to which the firewall will attach and create its endpoints | `any` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The VPC Id associated with the firewall | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_firewall_arn"></a> [firewall\_arn](#output\_firewall\_arn) | The Amazon Resource Name (ARN) that identifies the firewall. |
| <a name="output_firewall_endpoint_id_subnet_id_mapping"></a> [firewall\_endpoint\_id\_subnet\_id\_mapping](#output\_firewall\_endpoint\_id\_subnet\_id\_mapping) | The Subnet\_id where the firewall vpc-endpoint is created. This is used to ensure the firewall vpc\_id used for routing is associated with the route table in the corresponding AZ |
| <a name="output_firewall_endpoint_ids"></a> [firewall\_endpoint\_ids](#output\_firewall\_endpoint\_ids) | The identifier of the firewall endpoint that AWS Network Firewall has instantiated in the subnet. You use this along with "firewall\_endpoint\_id\_subnet\_id\_mapping" to identify the firewall endpoint in the VPC route tables, when you redirect the VPC traffic through the endpoint. |
| <a name="output_firewall_id"></a> [firewall\_id](#output\_firewall\_id) | The Amazon Resource Name (ARN) that identifies the firewall. |
<!-- END_TF_DOCS -->