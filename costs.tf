# Cost guardrails: a budget per resource group, alerts before overspend, and anomaly detection.

variable "lab_monthly_budget" {
  description = "Monthly budget for the platform resource group, in the billing currency."
  type        = number
  default     = 5
}

# A budget just for the platform resource group (one per team or project).
resource "azurerm_consumption_budget_resource_group" "lab" {
  name              = "budget-rg-fpldemon-lab"
  resource_group_id = azurerm_resource_group.lab.id
  amount            = var.lab_monthly_budget
  time_grain        = "Monthly"

  time_period {
    start_date = "2026-10-01T00:00:00Z"
  }

  # Early warning: half the budget actually spent.
  notification {
    enabled        = true
    threshold      = 50
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_emails = [var.alert_email]
  }

  # Most useful: Azure PREDICTS you'll go over by month end.
  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Forecasted"
    contact_emails = [var.alert_email]
  }
}

# Emails you if daily spending suddenly jumps (a forgotten resource or a runaway job).
resource "azurerm_cost_anomaly_alert" "lab" {
  name            = "cost-anomaly-fpldemon"
  display_name    = "FPL Demon cost anomaly"
  subscription_id = data.azurerm_subscription.current.id
  email_subject   = "Unusual Azure spend detected"
  email_addresses = [var.alert_email]
}
