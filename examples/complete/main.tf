# Reference composition: subscription/management-group guardrails + immutable
# Activity Log archive + keyless CI. The plan test in tests/ proves the modules'
# inputs and outputs fit together.

terraform {
  required_version = ">= 1.10"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# "public" or "usgovernment" - same convention as azure-lighthouse-tf, so one
# codebase serves both clouds. Auth is OIDC only (ARM_USE_OIDC=true plus
# ARM_CLIENT_ID / ARM_TENANT_ID / ARM_SUBSCRIPTION_ID from the workflow);
# no client secret is read.
provider "azurerm" {
  environment     = var.azure_environment
  subscription_id = var.subscription_id
  features {}

  # Needed because the archive storage account disables Shared Key auth.
  storage_use_azuread = true
}

module "policy_guardrails" {
  source = "../../modules/policy-guardrails"

  scope             = var.policy_scope
  allowed_locations = var.allowed_locations
  enforce           = var.enforce_policies
}

module "activity_log_archive" {
  source = "../../modules/activity-log-archive"

  subscription_id      = var.subscription_id
  resource_group_name  = var.audit_resource_group_name
  location             = var.location
  storage_account_name = var.audit_storage_account_name
  lock_immutability    = var.lock_audit_immutability
}

resource "azurerm_resource_group" "identity" {
  name     = var.identity_resource_group_name
  location = var.location
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  resource_group_name = azurerm_resource_group.identity.name
  location            = var.location

  deployers = {
    infra = {
      repository   = "${var.github_owner}/${var.infra_repo}"
      environments = ["prod"]
      role_assignments = [
        { scope = "/subscriptions/${var.subscription_id}", role = "Contributor" },
      ]
    }
    plan = {
      repository   = "${var.github_owner}/${var.infra_repo}"
      pull_request = true
      role_assignments = [
        { scope = "/subscriptions/${var.subscription_id}", role = "Reader" },
      ]
    }
  }
}
