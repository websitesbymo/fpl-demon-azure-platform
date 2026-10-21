# FPL Demon on Azure - platform lab.
# Milestone 1: a cost guardrail, a resource group and a storage account, all in UK South.

terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  storage_use_azuread = true

  features {}
  # Uses the subscription you signed into with `az login`.
}

data "azurerm_subscription" "current" {}

locals {
  location = "uksouth"
  tags = {
    project = "fpl-demon-azure-lab"
    owner   = var.owner
    managed = "terraform"
  }
}

# Guardrail first: email when spend passes 80% of a 5 GBP monthly budget.
resource "azurerm_consumption_budget_subscription" "lab" {
  name            = "fpl-demon-lab-budget"
  subscription_id = data.azurerm_subscription.current.id
  amount          = 5
  time_grain      = "Monthly"

  time_period {
    start_date = "2026-10-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = [var.alert_email]
  }
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-fpldemon-lab-uks"
  location = local.location
  tags     = local.tags
}

# Storage for the FPL data files (the Azure version of the published JSON).
resource "azurerm_storage_account" "data" {
  #checkov:skip=CKV_AZURE_59:Lab has no virtual network; access is Entra ID + RBAC only (shared keys disabled)
  #checkov:skip=CKV2_AZURE_33:Private endpoints need a VNet, planned for a later stage
  #checkov:skip=CKV_AZURE_206:Locally redundant storage is enough for lab data
  #checkov:skip=CKV2_AZURE_1:Microsoft-managed encryption is acceptable for non-sensitive data
  #checkov:skip=CKV_AZURE_33:Queue service not used

  name                            = "stfpldemonlab${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags

  shared_access_key_enabled = false # no master keys: Entra ID + RBAC only

  blob_properties {
    delete_retention_policy {
      days = 7 # recycle bin for deleted files
    }
  }

  sas_policy {
    expiration_period = "01.00:00:00" # share links expire after 1 day
  }

}

# Storage account names must be globally unique.
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# FPL Demon's live release pointer, published to Azure Blob Storage.
resource "azurerm_storage_container" "releases" {
  #checkov:skip=CKV2_AZURE_21:Blob read logging to Log Analytics planned next

  name                  = "fpl-releases"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "current" {
  name                   = "releases/sample.json"
  storage_account_name   = azurerm_storage_account.data.name
  storage_container_name = azurerm_storage_container.releases.name
  type                   = "Block"
  content_type           = "application/json"
  source                 = "${path.module}/data/sample.json"
  content_md5            = filemd5("${path.module}/data/sample.json")
}

output "storage_account" { value = azurerm_storage_account.data.name }
output "release_blob" { value = azurerm_storage_blob.current.name }
