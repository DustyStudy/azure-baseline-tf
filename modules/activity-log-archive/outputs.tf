output "storage_account_id" {
  value = azurerm_storage_account.audit.id
}

output "resource_group_name" {
  value = azurerm_resource_group.audit.name
}

output "immutability_locked" {
  description = "Whether the WORM policy is permanently locked."
  value       = var.lock_immutability
}
