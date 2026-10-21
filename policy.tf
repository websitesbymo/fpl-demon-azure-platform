# governance guardrails with Azure Policy (built-in definitions), assigned to the platform resource group.

# Built-in "Allowed locations": anything created outside the UK is denied.
resource "azurerm_resource_group_policy_assignment" "uk_only" {
  name                 = "allowed-locations-uk"
  display_name         = "Allowed locations: UK only"
  resource_group_id    = azurerm_resource_group.lab.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  parameters = jsonencode({
    listOfAllowedLocations = { value = ["uksouth", "ukwest"] }
  })
}

# Built-in "Require a tag on resources": every taggable resource must carry the project tag.
resource "azurerm_resource_group_policy_assignment" "require_project_tag" {
  name                 = "require-project-tag"
  display_name         = "Require the project tag"
  resource_group_id    = azurerm_resource_group.lab.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"

  parameters = jsonencode({
    tagName = { value = "project" }
  })
}
