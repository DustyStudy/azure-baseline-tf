variable "scope" {
  description = "Where the policies are assigned: a management group (/providers/Microsoft.Management/managementGroups/<id>) or a subscription (/subscriptions/<guid>). Assignments inherit downward, so a management group is the strongest place and a single subscription is the usual place to trial."
  type        = string

  validation {
    condition = (
      can(regex("^/providers/Microsoft\\.Management/managementGroups/[A-Za-z0-9._()-]+$", var.scope)) ||
      can(regex("^/subscriptions/[0-9a-fA-F-]{36}$", var.scope))
    )
    error_message = "scope must be a management group ID (/providers/Microsoft.Management/managementGroups/<id>) or a subscription ID (/subscriptions/<guid>)."
  }
}

variable "allowed_locations" {
  description = "Azure regions resources may be created in (data residency), e.g. [\"eastus\", \"westus2\"]. No default on purpose: valid regions differ between Azure Public and Azure Government, and a wrong default would either block everything or allow anything."
  type        = list(string)

  validation {
    condition     = length(var.allowed_locations) > 0
    error_message = "An empty allowed list would forbid creating any resource."
  }
}

variable "enforce" {
  description = "true = non-compliant deployments are blocked (Deny). false = assignments are created in DoNotEnforce mode: compliance is evaluated and reported but nothing is blocked. Start false on a real environment, review the compliance report, then flip to true."
  type        = bool
  default     = true
}

variable "additional_policies" {
  description = "Extra policy assignments, keyed by a short name (<= 20 chars). definition_id is a full policy or initiative definition ID; parameters is a map of parameter name => value."
  type = map(object({
    definition_id = string
    parameters    = optional(map(any), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.additional_policies : can(regex("^[a-z0-9-]{1,20}$", k))])
    error_message = "additional_policies keys must be lowercase letters/digits/hyphens, 1-20 chars (assignment names are limited to 24 characters at management group scope)."
  }
}
