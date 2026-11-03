resource "azurerm_resource_group" "demo" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    purpose     = "terraform"
    environment = "learning"
    managed_by  = "terraform"
  }
}

resource "azurerm_virtual_network" "demo" {
  name                = var.virtual_network_name
  location            = azurerm_resource_group.demo.location
  resource_group_name = azurerm_resource_group.demo.name
  address_space       = ["10.40.0.0/16"]

  tags = azurerm_resource_group.demo.tags
}
