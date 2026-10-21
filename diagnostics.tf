# Audit logging: Key Vault and blob storage activity sent to Log Analytics.

resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "diag-kv-to-law"
  target_resource_id         = azurerm_key_vault.lab.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category_group = "audit"
  }
}

resource "azurerm_monitor_diagnostic_setting" "blob" {
  name                       = "diag-blob-to-law"
  target_resource_id         = "${azurerm_storage_account.data.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }
}
