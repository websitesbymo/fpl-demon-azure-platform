# Private networking. VNet, subnet and NSG are free and always on.
# Private endpoint and DNS are behind a switch to control cost.

variable "enable_private_networking" {
  description = "Deploy the Key Vault private endpoint and private DNS zone"
  type        = bool
  default     = false
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-fpldemon-lab-uks"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_security_group" "endpoints" {
  name                = "nsg-private-endpoints"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "endpoints" {
  subnet_id                 = azurerm_subnet.endpoints.id
  network_security_group_id = azurerm_network_security_group.endpoints.id
}

resource "azurerm_private_dns_zone" "keyvault" {
  count               = var.enable_private_networking ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  count                 = var.enable_private_networking ? 1 : 0
  name                  = "link-vnet-fpldemon"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "keyvault" {
  count               = var.enable_private_networking ? 1 : 0
  name                = "pe-kv-fpldemon"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-kv-fpldemon"
    private_connection_resource_id = azurerm_key_vault.lab.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault[0].id]
  }
}
