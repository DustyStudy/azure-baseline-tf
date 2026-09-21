variable "azure_environment" {
  description = "\"public\" or \"usgovernment\"."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "usgovernment"], var.azure_environment)
    error_message = "azure_environment must be \"public\" or \"usgovernment\"."
  }
}

variable "subscription_id" {
  type = string
}

variable "policy_scope" {
  description = "Management group or subscription ID the guardrails are assigned to."
  type        = string
}

variable "allowed_locations" {
  description = "Regions resources may be created in. Differs between Public and Government."
  type        = list(string)
}

variable "enforce_policies" {
  description = "false = report only (DoNotEnforce). Start false on a real environment."
  type        = bool
  default     = false
}

variable "location" {
  type = string
}

variable "audit_resource_group_name" {
  type    = string
  default = "rg-audit-archive"
}

variable "audit_storage_account_name" {
  type = string
}

variable "lock_audit_immutability" {
  description = "Irreversibly lock the audit archive's retention policy. Leave false until you are sure of the retention period."
  type        = bool
  default     = false
}

variable "identity_resource_group_name" {
  type    = string
  default = "rg-cicd-identity"
}

variable "github_owner" {
  type = string
}

variable "infra_repo" {
  type    = string
  default = "infra"
}

# GitHub's OIDC subject embeds immutable numeric IDs. Look them up with:
#   gh api repos/<owner>/<repo> -q '.owner.id, .id'
variable "github_owner_id" {
  description = "Numeric GitHub owner ID (see the gh command above)."
  type        = string
}

variable "infra_repo_id" {
  description = "Numeric GitHub repository ID of the infra repo."
  type        = string
}
