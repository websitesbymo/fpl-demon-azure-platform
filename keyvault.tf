resource "azurerm_key_vault" "lab" {
  #checkov:skip=CKV_AZURE_110:Purge protection disabled to allow environment teardown; enable for regulated data
  #checkov:skip=CKV_AZURE_42:Same as above; soft delete is on (7 days)
  #checkov:skip=CKV_AZURE_189:Public access kept for the deployment agent; private endpoint available via enable_private_networking
  #checkov:skip=CKV_AZURE_109:Same as above; access controlled by RBAC
  #checkov:skip=CKV2_AZURE_32:Private endpoint is feature-flagged (network.tf) to control cost

  name                       = "kv-fpldemon-${random_string.suffix.result}"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  tenant_id                  = data.azurerm_subscription.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}

resource "azurerm_role_assignment" "me_kv_officer" {

  scope                = azurerm_key_vault.lab.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.reader_object_id
}

resource "azurerm_role_assignment" "job_kv_reader" {
  scope                = azurerm_key_vault.lab.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.job.principal_id
}