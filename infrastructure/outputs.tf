output "resource_group_name" {
  value = azurerm_resource_group.demo.name
}

output "virtual_network_id" {
  value = azurerm_virtual_network.demo.id
}
