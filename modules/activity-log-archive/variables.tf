variable "subscription_id" {
  description = "Subscription whose Activity Log is archived (the diagnostic setting is per subscription)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "resource_group_name" {
  description = "Name of the dedicated resource group created to hold the archive. Keep it separate from workload resource groups so nobody with workload access can touch the evidence."
  type        = string
}

variable "location" {
  type = string
}

variable "storage_account_name" {
  description = "Globally unique storage account name (3-24 lowercase letters/digits)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase letters and digits."
  }
}

variable "replication_type" {
  description = "GRS keeps a second copy in the paired region. Use ZRS/LRS only if residency rules forbid cross-region copies."
  type        = string
  default     = "GRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.replication_type)
    error_message = "replication_type must be one of LRS, ZRS, GRS, GZRS, RAGRS, RAGZRS."
  }
}

variable "retention_days" {
  description = "Immutability period: blobs can't be modified or deleted for this many days after creation."
  type        = number
  default     = 365

  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 146000
    error_message = "retention_days must be between 30 and 146000."
  }
}

variable "lock_immutability" {
  description = <<-EOT
    Permanently lock the immutability policy (WORM). IRREVERSIBLE - once
    locked the retention period can only be lengthened, never shortened or
    removed, and the storage account can't be deleted until every blob has aged
    out. Leave false while iterating; set true for production.
  EOT
  type        = bool
  default     = false
}

variable "log_categories" {
  description = "Activity Log categories to export."
  type        = list(string)
  default     = ["Administrative", "Security", "ServiceHealth", "Alert", "Recommendation", "Policy", "Autoscale", "ResourceHealth"]
}

variable "cool_after_days" {
  description = "Move blobs to the Cool tier after this many days (cost). Blobs are never deleted by lifecycle rules."
  type        = number
  default     = 90
}

variable "allowed_ip_ranges" {
  description = "Public IPs/CIDRs (e.g. a SOC egress range) allowed to read the archive. Azure Monitor writes through the trusted-services bypass, so this is only for readers."
  type        = list(string)
  default     = []
}

variable "shared_access_key_enabled" {
  description = "Allow Shared Key auth. Default false (Azure AD only). When false, set storage_use_azuread = true in the azurerm provider block."
  type        = bool
  default     = false
}

variable "customer_managed_key" {
  description = <<-EOT
    Encrypt the archive with your own Key Vault key (CMEK) instead of
    Microsoft-managed keys. Needs a user-assigned identity that already has
    "Key Vault Crypto Service Encryption User" on the key vault, and a key in a
    vault with purge protection on. null = Microsoft-managed keys.
  EOT
  type = object({
    key_vault_key_id          = string
    user_assigned_identity_id = string
  })
  default = null
}

variable "resource_lock" {
  description = "Add a CanNotDelete management lock on the resource group."
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
