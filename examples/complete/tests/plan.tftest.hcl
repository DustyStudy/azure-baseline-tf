# Plans the whole composition against a mocked provider so cross-module values
# (resource group, identity IDs, principal IDs) are unknown at plan time, as on
# a real first deploy.

mock_provider "azurerm" {}

variables {
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  policy_scope               = "/subscriptions/00000000-0000-0000-0000-000000000000"
  allowed_locations          = ["eastus", "westus2"]
  location                   = "eastus"
  audit_storage_account_name = "acmeauditarchive001"
  github_owner               = "acme"
}

run "first_deploy_plans" {
  command = plan

  assert {
    condition     = length(module.policy_guardrails.assignments) == 8 && module.policy_guardrails.enforced == false
    error_message = "Composition should plan cleanly with the eight default guardrails in report-only mode."
  }

  assert {
    condition     = length(module.github_oidc.subjects) == 2
    error_message = "Expected one prod-environment credential and one pull_request credential."
  }
}
