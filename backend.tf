# Remote state in Azure Storage, authenticated with Entra ID.
# Values are supplied at init time (see backend.hcl.example), so no account names live in code.
terraform {
  backend "azurerm" {
    use_azuread_auth = true
  }
}
