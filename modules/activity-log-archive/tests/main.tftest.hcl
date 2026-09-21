mock_provider "azurerm" {}

variables {
  subscription_id      = "00000000-0000-0000-0000-000000000000"
  resource_group_name  = "rg-audit-archive"
  location             = "eastus"
  storage_account_name = "acmeauditarchive001"
}

run "archive_is_locked_down_by_default" {
  command = plan

  assert {
    condition     = azurerm_storage_account.audit.allow_nested_items_to_be_public == false && azurerm_storage_account.audit.min_tls_version == "TLS1_2" && azurerm_storage_account.audit.https_traffic_only_enabled == true
    error_message = "Archive must be non-public, HTTPS-only, TLS 1.2+."
  }

  assert {
    condition     = azurerm_storage_account.audit.shared_access_key_enabled == false
    error_message = "Shared Key auth should be off by default."
  }

  assert {
    condition     = azurerm_storage_account.audit.network_rules[0].default_action == "Deny"
    error_message = "Network access must be deny-by-default."
  }

  assert {
    condition     = azurerm_storage_account.audit.immutability_policy[0].period_since_creation_in_days == 365 && azurerm_storage_account.audit.immutability_policy[0].state == "Unlocked"
    error_message = "Retention should default to 365 days, with the irreversible lock opt-in."
  }

  assert {
    condition     = azurerm_storage_account.audit.blob_properties[0].versioning_enabled == true
    error_message = "Versioning must be on (required for version-level immutability)."
  }

  assert {
    condition     = length(azurerm_management_lock.audit) == 1
    error_message = "The resource group should carry a CanNotDelete lock."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.activity_log.target_resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "Diagnostic setting must target the subscription."
  }
}

run "worm_lock_is_opt_in" {
  command = plan

  variables {
    lock_immutability = true
  }

  assert {
    condition     = azurerm_storage_account.audit.immutability_policy[0].state == "Locked"
    error_message = "lock_immutability should lock the policy."
  }
}

run "lock_can_be_omitted" {
  command = plan

  variables {
    resource_lock = false
  }

  assert {
    condition     = length(azurerm_management_lock.audit) == 0
    error_message = "resource_lock = false should skip the management lock."
  }
}

run "rejects_bad_storage_name" {
  command = plan

  variables {
    storage_account_name = "Bad-Name"
  }

  expect_failures = [var.storage_account_name]
}

run "rejects_short_retention" {
  command = plan

  variables {
    retention_days = 7
  }

  expect_failures = [var.retention_days]
}

run "rejects_bad_subscription_id" {
  command = plan

  variables {
    subscription_id = "not-a-guid"
  }

  expect_failures = [var.subscription_id]
}

run "cmk_is_opt_in" {
  command = plan

  variables {
    customer_managed_key = {
      key_vault_key_id          = "https://acme-kv.vault.azure.net/keys/audit/abc123"
      user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/audit-cmk"
    }
  }

  assert {
    condition     = length(azurerm_storage_account.audit.customer_managed_key) == 1 && length(azurerm_storage_account.audit.identity) == 1
    error_message = "A customer-managed key needs both the key block and the user-assigned identity."
  }
}

run "no_cmk_by_default" {
  command = plan

  assert {
    condition     = length(azurerm_storage_account.audit.customer_managed_key) == 0
    error_message = "Microsoft-managed keys should be the default."
  }
}
