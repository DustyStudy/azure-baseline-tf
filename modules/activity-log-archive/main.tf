# Subscription Activity Log -> one immutable, access-restricted storage account
# in a dedicated resource group. The Azure counterpart of an org CloudTrail +
# S3 object-lock archive (AWS) and an aggregated log sink + locked bucket (GCP).

resource "azurerm_resource_group" "audit" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "audit" {
  #checkov:skip=CKV_AZURE_59:public_network_access must stay enabled ("selected networks") - Azure Monitor writes the Activity Log through the trusted-services bypass, which does not work with public access fully disabled. Access is deny-by-default with an IP allow-list.
  #checkov:skip=CKV2_AZURE_33:a private endpoint is not used by Azure Monitor's diagnostic-setting export; readers who need one can add it alongside this module
  #checkov:skip=CKV_AZURE_33:the queue service is not used; the Activity Log is written as blobs
  #checkov:skip=CKV_AZURE_36:false positive - network_rules.bypass includes "AzureServices" below; Checkov fails this check whenever the resource contains dynamic blocks (the optional CMEK identity/key)
  #checkov:skip=CKV2_AZURE_1:CMEK is supported and opt-in via customer_managed_key; Microsoft-managed keys are the default
  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.audit.name
  location            = azurerm_resource_group.audit.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = var.replication_type

  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = var.shared_access_key_enabled
  default_to_oauth_authentication = true

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  # Account-level, version-scoped immutability: every blob written is WORM for
  # retention_days. "Unlocked" can still be changed (use while iterating);
  # "Locked" is permanent.
  immutability_policy {
    allow_protected_append_writes = true
    state                         = var.lock_immutability ? "Locked" : "Unlocked"
    period_since_creation_in_days = var.retention_days
  }

  dynamic "identity" {
    for_each = var.customer_managed_key == null ? [] : [var.customer_managed_key]
    content {
      type         = "UserAssigned"
      identity_ids = [identity.value.user_assigned_identity_id]
    }
  }

  dynamic "customer_managed_key" {
    for_each = var.customer_managed_key == null ? [] : [var.customer_managed_key]
    content {
      key_vault_key_id          = customer_managed_key.value.key_vault_key_id
      user_assigned_identity_id = customer_managed_key.value.user_assigned_identity_id
    }
  }

  # Deny by default. Azure Monitor is a trusted service, so the Activity Log
  # export still lands; only humans/tools reading the archive need an IP rule.
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices", "Logging", "Metrics"]
    ip_rules       = var.allowed_ip_ranges
  }

  tags = var.tags
}

resource "azurerm_storage_management_policy" "audit" {
  storage_account_id = azurerm_storage_account.audit.id

  rule {
    name    = "cool-old-logs"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = var.cool_after_days
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  name               = "activity-log-archive"
  target_resource_id = "/subscriptions/${var.subscription_id}"
  storage_account_id = azurerm_storage_account.audit.id

  dynamic "enabled_log" {
    for_each = toset(var.log_categories)
    content {
      category = enabled_log.value
    }
  }
}

resource "azurerm_management_lock" "audit" {
  count = var.resource_lock ? 1 : 0

  name       = "audit-archive-no-delete"
  scope      = azurerm_resource_group.audit.id
  lock_level = "CanNotDelete"
  notes      = "Audit evidence. Remove the lock deliberately, with a change record, before deleting."
}
