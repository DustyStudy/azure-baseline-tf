output "client_ids" {
  description = "deployer key -> identity client ID (AZURE_CLIENT_ID for azure/login)."
  value       = { for k, v in azurerm_user_assigned_identity.deployer : k => v.client_id }
}

output "tenant_ids" {
  description = "deployer key -> tenant ID (AZURE_TENANT_ID for azure/login)."
  value       = { for k, v in azurerm_user_assigned_identity.deployer : k => v.tenant_id }
}

output "subjects" {
  description = "Federated credential subjects trusted, per credential."
  value       = { for k, v in local.federated_credentials : k => v.subject }
}
