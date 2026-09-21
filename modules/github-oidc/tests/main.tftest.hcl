mock_provider "azurerm" {}

variables {
  resource_group_name = "rg-identity"
  location            = "eastus"
  deployers = {
    infra = {
      repository   = "acme/infra"
      environments = ["prod"]
      branches     = ["main"]
      role_assignments = [
        { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Contributor" },
        { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Monitoring Reader" },
      ]
    }
    plan = {
      repository   = "acme/infra"
      pull_request = true
      role_assignments = [
        { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Reader" },
      ]
    }
  }
}

run "trust_is_exact_subjects" {
  command = plan

  assert {
    condition     = sort(values(output.subjects)) == sort(["repo:acme/infra:environment:prod", "repo:acme/infra:ref:refs/heads/main", "repo:acme/infra:pull_request"])
    error_message = "Only the listed environment, branch and pull_request subjects may be trusted - no wildcards."
  }

  assert {
    condition     = alltrue([for k, v in azurerm_federated_identity_credential.github : v.issuer == "https://token.actions.githubusercontent.com"])
    error_message = "Issuer must be GitHub's OIDC issuer."
  }

  assert {
    condition     = length(azurerm_role_assignment.deployer) == 3
    error_message = "One assignment per (deployer, role, scope): 2 + 1."
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.deployer) == 2
    error_message = "One identity per deployer."
  }
}

run "rejects_owner_role" {
  command = plan

  variables {
    deployers = {
      bad = {
        repository   = "acme/bad"
        environments = ["prod"]
        role_assignments = [
          { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Owner" },
        ]
      }
    }
  }

  expect_failures = [var.deployers]
}

run "rejects_deployer_with_no_subject" {
  command = plan

  variables {
    deployers = {
      bad = {
        repository = "acme/bad"
        role_assignments = [
          { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Reader" },
        ]
      }
    }
  }

  expect_failures = [var.deployers]
}

run "rejects_malformed_repository" {
  command = plan

  variables {
    deployers = {
      bad = {
        repository   = "acme"
        environments = ["prod"]
        role_assignments = [
          { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Reader" },
        ]
      }
    }
  }

  expect_failures = [var.deployers]
}

run "rejects_scope_that_is_not_an_azure_id" {
  command = plan

  variables {
    deployers = {
      bad = {
        repository   = "acme/bad"
        environments = ["prod"]
        role_assignments = [
          { scope = "everything", role = "Reader" },
        ]
      }
    }
  }

  expect_failures = [var.deployers]
}
