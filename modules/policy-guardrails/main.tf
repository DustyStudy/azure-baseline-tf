# Preventive guardrails via Azure Policy - the Azure counterpart of SCPs / GCP
# org policies. Every definition below is a BUILT-IN policy; the GUIDs were
# checked against Microsoft's published definitions (github.com/Azure/azure-policy,
# built-in-policies/policyDefinitions), not written from memory.

locals {
  is_management_group = startswith(var.scope, "/providers/Microsoft.Management/managementGroups/")
  effect              = { effect = { value = "Deny" } }

  builtin = {
    "allowed-locations" = {
      display_name  = "Allowed locations"
      definition_id = "e56962a6-4747-49cd-b67b-bf8b01975c4c"
      parameters    = merge(local.effect, { listOfAllowedLocations = { value = var.allowed_locations } })
    }
    "storage-https-only" = {
      display_name  = "Secure transfer to storage accounts should be enabled"
      definition_id = "404c3081-a854-4457-ae30-26a93ef643f9"
      parameters    = local.effect
    }
    "storage-no-public-blob" = {
      display_name  = "Storage account public access should be disallowed"
      definition_id = "4fa4b6c0-31ca-4c0d-b10d-24b96f62a751"
      parameters    = local.effect
    }
    "storage-no-shared-key" = {
      display_name  = "Storage accounts should prevent shared key access"
      definition_id = "8c6a50c6-9ffd-4ae7-986f-5fa6111f9a54"
      parameters    = local.effect
    }
    "sql-no-public-access" = {
      display_name  = "Public network access on Azure SQL Database should be disabled"
      definition_id = "1b8ca024-1d5c-4dec-8995-b1a932b41780"
      parameters    = local.effect
    }
    "keyvault-soft-delete" = {
      display_name  = "Key vaults should have soft delete enabled"
      definition_id = "1e66c121-a66a-4b1f-9b83-0fd99bf0fc2d"
      parameters    = local.effect
    }
    "keyvault-purge-protect" = {
      display_name  = "Key vaults should have deletion protection enabled"
      definition_id = "0b60c0b2-2dc2-4e1c-b5c9-abbed971de53"
      parameters    = local.effect
    }
    # This definition has no effect parameter - it is always Deny. With
    # enforce = false the assignment still reports instead of blocking.
    "nic-no-public-ip" = {
      display_name  = "Network interfaces should not have public IPs"
      definition_id = "83a86a26-fd1f-447c-b59d-e51f44264114"
      parameters    = {}
    }
  }

  policies = merge(
    {
      for k, v in local.builtin : k => {
        display_name  = v.display_name
        definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${v.definition_id}"
        parameters    = v.parameters
      }
    },
    {
      for k, v in var.additional_policies : k => {
        display_name  = k
        definition_id = v.definition_id
        parameters    = { for pk, pv in v.parameters : pk => { value = pv } }
      }
    },
  )
}

resource "azurerm_management_group_policy_assignment" "this" {
  for_each = { for k, v in local.policies : k => v if local.is_management_group }

  name                 = each.key
  display_name         = each.value.display_name
  management_group_id  = var.scope
  policy_definition_id = each.value.definition_id
  parameters           = length(each.value.parameters) == 0 ? null : jsonencode(each.value.parameters)
  enforce              = var.enforce
}

resource "azurerm_subscription_policy_assignment" "this" {
  for_each = { for k, v in local.policies : k => v if !local.is_management_group }

  name                 = each.key
  display_name         = each.value.display_name
  subscription_id      = var.scope
  policy_definition_id = each.value.definition_id
  parameters           = length(each.value.parameters) == 0 ? null : jsonencode(each.value.parameters)
  enforce              = var.enforce
}
