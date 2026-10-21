# Milestone 2: run FPL Demon's Official Core data job on Azure, side by side with Hetzner (shadow mode).
# It writes only to this lab's storage (container "shadow-runs"), never to production.

# Logs from every job run.
resource "azurerm_log_analytics_workspace" "lab" {


  name                = "log-fpldemon-lab-uks"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.tags

}

# Private registry for the job's container image. No admin password: pulls use the managed identity.
resource "azurerm_container_registry" "lab" {
  #checkov:skip=CKV_AZURE_139:Public endpoint needed by Container Apps without a VNet; admin login disabled
  #checkov:skip=CKV_AZURE_163:Image scanning requires Premium tier; Basic chosen for cost
  #checkov:skip=CKV_AZURE_164:Content trust requires Premium tier
  #checkov:skip=CKV_AZURE_165:Geo-replication requires Premium tier; single-region lab
  #checkov:skip=CKV_AZURE_166:Quarantine requires Premium tier
  #checkov:skip=CKV_AZURE_167:Retention policy requires Premium tier
  #checkov:skip=CKV_AZURE_233:Zone redundancy requires Premium tier
  #checkov:skip=CKV_AZURE_237:Dedicated data endpoints require Premium tier

  name                = "crfpldemonlab${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.tags
}

# The job's identity, with only the two permissions it needs (least privilege).
resource "azurerm_user_assigned_identity" "job" {
  name                = "id-fpldemon-core-job"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "job_acr_pull" {
  scope                = azurerm_container_registry.lab.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.job.principal_id
}

resource "azurerm_storage_container" "shadow" {
  #checkov:skip=CKV2_AZURE_21:Blob read logging to Log Analytics planned next

  name                  = "shadow-runs"
  storage_account_id    = azurerm_storage_account.data.id
  container_access_type = "private"
}

# Write access to the shadow container only, not the whole storage account.
resource "azurerm_role_assignment" "job_blob_writer" {
  scope                = "${azurerm_storage_account.data.id}/blobServices/default/containers/${azurerm_storage_container.shadow.name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.job.principal_id
}

resource "azurerm_container_app_environment" "lab" {
  name                       = "cae-fpldemon-lab-uks"
  location                   = azurerm_resource_group.lab.location
  resource_group_name        = azurerm_resource_group.lab.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id
  tags                       = local.tags
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }
}

variable "core_job_image_tag" {
  description = "Tag of the fpldemon-core image in the registry (set after building it)."
  type        = string
  default     = "v1"
}

# Hourly at :15 while shadowing (Hetzner runs at :00 and :30), so FPL never sees doubled traffic.
resource "azurerm_container_app_job" "core" {
  name                  = "job-fpldemon-core"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  workload_profile_name = "Consumption"

  container_app_environment_id = azurerm_container_app_environment.lab.id
  replica_timeout_in_seconds   = 600
  replica_retry_limit          = 1
  tags                         = local.tags

  schedule_trigger_config {
    cron_expression          = "15 * * * *"
    parallelism              = 1
    replica_completion_count = 1
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.job.id]
  }

  registry {
    server   = azurerm_container_registry.lab.login_server
    identity = azurerm_user_assigned_identity.job.id
  }

  template {
    container {
      name   = "core"
      image  = "${azurerm_container_registry.lab.login_server}/fpldemon-core:${var.core_job_image_tag}"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.job.client_id
      }
      env {
        name  = "STORAGE_ACCOUNT"
        value = azurerm_storage_account.data.name
      }
      env {
        name  = "STORAGE_CONTAINER"
        value = azurerm_storage_container.shadow.name
      }
    }
  }

  depends_on = [azurerm_role_assignment.job_acr_pull, azurerm_role_assignment.job_blob_writer]
}

output "container_registry" { value = azurerm_container_registry.lab.login_server }
output "core_job_name" { value = azurerm_container_app_job.core.name }

# Read-only data access for you (a fixed person, not "whoever runs Terraform", so the pipeline does not flip it).
variable "reader_object_id" {
  description = "Entra ID object ID of the person who can read the job outputs."
  type        = string
}

resource "azurerm_role_assignment" "me_blob_reader" {
  scope                = azurerm_storage_account.data.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.reader_object_id
}

# The pipeline identity manages current.json, and with shared keys off it needs an Entra data role.
variable "pipeline_object_id" {
  description = "Object ID of the Azure DevOps service connection identity."
  type        = string
}

resource "azurerm_role_assignment" "pipeline_releases_writer" {
  scope                = "${azurerm_storage_account.data.id}/blobServices/default/containers/${azurerm_storage_container.releases.name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.pipeline_object_id
}
