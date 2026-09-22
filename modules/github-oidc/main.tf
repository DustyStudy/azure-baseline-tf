# GitHub Actions -> Azure with no client secrets anywhere: the workflow's OIDC
# token is exchanged for a short-lived Azure token. A user-assigned managed
# identity + federated credentials is used rather than an Entra app
# registration because it needs no directory (Entra) permissions to create.

locals {
  issuer   = "https://token.actions.githubusercontent.com"
  audience = "api://AzureADTokenExchange"

  # The subject prefix GitHub puts in the token, per deployer. Immutable form
  # pins the numeric owner/repo IDs (see var.subject_format).
  subject_prefix = {
    for k, v in var.deployers : k => (
      var.subject_format == "immutable"
      ? "repo:${split("/", v.repository)[0]}@${v.owner_id}/${split("/", v.repository)[1]}@${v.repository_id}"
      : "repo:${v.repository}"
    )
  }

  # One federated credential per (deployer, entity). The subject claim is what
  # GitHub puts in the token; Azure only accepts a token whose subject matches
  # exactly, so there is no wildcard trust.
  federated_credentials = merge(flatten([
    for k, v in var.deployers : [
      { for e in v.environments : "${k}:env:${e}" => { deployer = k, name = "${k}-env-${e}", subject = "${local.subject_prefix[k]}:environment:${e}" } },
      { for b in v.branches : "${k}:branch:${b}" => { deployer = k, name = "${k}-branch-${replace(b, "/", "-")}", subject = "${local.subject_prefix[k]}:ref:refs/heads/${b}" } },
      { for x in(v.pull_request ? ["pr"] : []) : "${k}:pr" => { deployer = k, name = "${k}-pull-request", subject = "${local.subject_prefix[k]}:pull_request" } },
    ]
  ])...)

  role_assignments = merge([
    for k, v in var.deployers : {
      for ra in v.role_assignments : "${k}:${ra.role}:${ra.scope}" => { deployer = k, role = ra.role, scope = ra.scope }
    }
  ]...)
}

resource "azurerm_user_assigned_identity" "deployer" {
  for_each = var.deployers

  name                = "${each.key}-deployer"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github" {
  for_each = local.federated_credentials

  name                      = each.value.name
  user_assigned_identity_id = azurerm_user_assigned_identity.deployer[each.value.deployer].id
  issuer                    = local.issuer
  audience                  = [local.audience]
  subject                   = each.value.subject
}

resource "azurerm_role_assignment" "deployer" {
  for_each = local.role_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.deployer[each.value.deployer].principal_id
  principal_type       = "ServicePrincipal"
}
