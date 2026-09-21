mock_provider "azurerm" {}

variables {
  scope             = "/providers/Microsoft.Management/managementGroups/contoso"
  allowed_locations = ["eastus", "westus2"]
}

run "management_group_assignments" {
  command = plan

  assert {
    condition     = length(azurerm_management_group_policy_assignment.this) == 8 && length(azurerm_subscription_policy_assignment.this) == 0
    error_message = "A management group scope should create the 8 built-in assignments there and none at subscription scope."
  }

  assert {
    condition     = contains(output.assignments, "storage-no-public-blob") && contains(output.assignments, "nic-no-public-ip")
    error_message = "Public blob access and public NICs must be blocked by default."
  }

  assert {
    condition     = azurerm_management_group_policy_assignment.this["allowed-locations"].enforce == true
    error_message = "Enforcement should default to on."
  }

  assert {
    condition     = join(",", jsondecode(azurerm_management_group_policy_assignment.this["allowed-locations"].parameters).listOfAllowedLocations.value) == "eastus,westus2"
    error_message = "allowed_locations must reach the policy parameters."
  }
}

run "subscription_scope" {
  command = plan

  variables {
    scope = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = length(azurerm_subscription_policy_assignment.this) == 8 && length(azurerm_management_group_policy_assignment.this) == 0
    error_message = "A subscription scope should use subscription assignments."
  }
}

run "audit_only_trial_mode" {
  command = plan

  variables {
    enforce = false
  }

  assert {
    condition     = alltrue([for k, v in azurerm_management_group_policy_assignment.this : v.enforce == false])
    error_message = "enforce = false must put every assignment in DoNotEnforce mode."
  }
}

run "additional_policies_are_added" {
  command = plan

  variables {
    additional_policies = {
      tags = {
        definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"
        parameters    = { tagName = "owner" }
      }
    }
  }

  assert {
    condition     = length(azurerm_management_group_policy_assignment.this) == 9
    error_message = "8 built-ins + 1 additional."
  }
}

run "rejects_malformed_scope" {
  command = plan

  variables {
    scope = "contoso"
  }

  expect_failures = [var.scope]
}

run "rejects_empty_locations" {
  command = plan

  variables {
    allowed_locations = []
  }

  expect_failures = [var.allowed_locations]
}

run "rejects_long_additional_key" {
  command = plan

  variables {
    additional_policies = {
      this-name-is-far-too-long-for-an-assignment = { definition_id = "/providers/Microsoft.Authorization/policyDefinitions/x" }
    }
  }

  expect_failures = [var.additional_policies]
}
