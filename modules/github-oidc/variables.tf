variable "resource_group_name" {
  description = "Existing resource group that holds the deployer identities."
  type        = string
}

variable "location" {
  type = string
}

variable "subject_format" {
  description = <<-EOT
    Which `sub` claim format GitHub emits for the repositories below.

    "immutable" (default): repo:<owner>@<owner-id>/<repo>@<repo-id>:<suffix> -
    what GitHub emits for repositories with `use_immutable_subject` (the default
    for recently created repos). It also pins the numeric IDs, so a renamed,
    deleted or re-created repository cannot impersonate a trusted one.

    "classic": repo:<owner>/<repo>:<suffix>.

    Azure matches a federated credential's subject EXACTLY, and a wrong format
    does not error - authentication just never succeeds. Check yours with:
      gh api repos/<owner>/<repo>/actions/oidc/customization/sub
  EOT
  type        = string
  default     = "immutable"

  validation {
    condition     = contains(["immutable", "classic"], var.subject_format)
    error_message = "subject_format must be \"immutable\" or \"classic\"."
  }
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
    repository    = string
    owner_id      = optional(string)
    repository_id = optional(string)
    environments  = optional(list(string), [])
    branches      = optional(list(string), [])
    pull_request  = optional(bool, false)
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
    condition = var.subject_format != "immutable" || alltrue([
      for k, v in var.deployers : v.owner_id != null && v.repository_id != null
    ])
    error_message = "subject_format is \"immutable\", so every deployer needs owner_id and repository_id. Look them up with: gh api repos/<owner>/<repo> -q '.owner.id, .id' (or set subject_format = \"classic\" if the repo's use_immutable_subject is false)."
  }

  validation {
    condition = alltrue([
      for k, v in var.deployers :
      (v.owner_id == null || can(regex("^[0-9]+$", v.owner_id))) && (v.repository_id == null || can(regex("^[0-9]+$", v.repository_id)))
    ])
    error_message = "owner_id and repository_id must be numeric GitHub IDs."
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
