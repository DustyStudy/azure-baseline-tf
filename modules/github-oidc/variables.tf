variable "resource_group_name" {
  description = "Existing resource group that holds the deployer identities."
  type        = string
}

variable "location" {
  type = string
}

variable "deployers" {
  description = <<-EOT
    One entry per GitHub repository that may deploy, keyed by a short name
    (becomes the identity name <key>-deployer).

    A GitHub token is only accepted when its subject matches one of the
    listed entities, so say exactly which: `environments` (jobs using a GitHub
    Environment - required reviewers apply), `branches`, and/or `pull_request`
    (PR runs). Prefer environments for anything that changes infrastructure and a
    separate read-only deployer for pull_request plans.

    role_assignments grant the identity access; keep them minimal and scoped as
    narrowly as the pipeline allows.
  EOT
  type = map(object({
    repository   = string
    environments = optional(list(string), [])
    branches     = optional(list(string), [])
    pull_request = optional(bool, false)
    role_assignments = list(object({
      scope = string
      role  = string
    }))
  }))

  validation {
    condition     = alltrue([for k, v in var.deployers : can(regex("^[^/]+/[^/]+$", v.repository))])
    error_message = "deployers[*].repository must be in owner/repo form."
  }

  validation {
    condition     = alltrue([for k, v in var.deployers : length(v.environments) + length(v.branches) + (v.pull_request ? 1 : 0) > 0])
    error_message = "Every deployer needs at least one subject (an environment, a branch, or pull_request); with none, nothing could authenticate."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.deployers : [
        for ra in v.role_assignments : !contains(["Owner", "User Access Administrator", "Role Based Access Control Administrator"], ra.role)
      ]
    ]))
    error_message = "Deployers may not hold Owner, User Access Administrator or Role Based Access Control Administrator - they could grant themselves anything. Use the specific roles the pipeline needs."
  }

  validation {
    condition     = alltrue([for k, v in var.deployers : can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,20}$", k))])
    error_message = "Deployer keys become identity names: letters/digits/hyphens, 1-21 chars, starting with a letter or digit."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.deployers : [
        for ra in v.role_assignments : can(regex("^(/subscriptions/|/providers/Microsoft\\.Management/managementGroups/)", ra.scope))
      ]
    ]))
    error_message = "role_assignments[*].scope must be a subscription, resource group, resource or management group ID."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
