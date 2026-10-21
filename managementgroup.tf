# The "league": a management group above the subscription.
resource "azurerm_management_group" "fpldemon" {
  name         = "mg-fpldemon"
  display_name = "FPL Demon"
  # Move our subscription into this management group.
  subscription_ids = [data.azurerm_subscription.current.subscription_id]
}

# A league-wide rule: everything in every subscription under this group must be in the UK.
resource "azurerm_management_group_policy_assignment" "uk_only" {
  name                 = "mg-uk-only"
  display_name         = "Allowed locations: UK only (management group)"
  management_group_id  = azurerm_management_group.fpldemon.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  parameters = jsonencode({
    listOfAllowedLocations = { value = ["uksouth", "ukwest"] }
  })
}

# Let the pipeline manage this group and its policies from now on (least privilege: this group only).
resource "azurerm_role_assignment" "pipeline_mg_contributor" {
  scope                = azurerm_management_group.fpldemon.id
  role_definition_name = "Management Group Contributor"
  principal_id         = var.pipeline_object_id
}

resource "azurerm_role_assignment" "pipeline_mg_policy" {
  scope                = azurerm_management_group.fpldemon.id
  role_definition_name = "Resource Policy Contributor"
  principal_id         = var.pipeline_object_id
}
