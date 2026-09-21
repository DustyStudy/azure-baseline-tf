output "assignments" {
  description = "Names of the policy assignments created at the scope."
  value       = sort(keys(local.policies))
}

output "enforced" {
  description = "Whether the assignments block non-compliant deployments (true) or only report (false)."
  value       = var.enforce
}
