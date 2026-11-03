variable "location" {
  description = "Azure region for the demo infrastructure."
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group managed by Terraform this demo."
  type        = string
  default     = "rg-terraform-demo"
}

variable "virtual_network_name" {
  description = "Virtual network managed by Terraform in this demo."
  type        = string
  default     = "vnet-terraform-demo"
}
