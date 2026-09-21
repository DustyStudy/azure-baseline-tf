mock_provider "azurerm" {}

variables {
  resource_group_name = "rg-identity"
  location            = "eastus"
  deployers = {
    infra = {
      repository    = "acme/infra"
      owner_id      = "1001"
      repository_id = "2002"
      environments  = ["prod"]
      branches      = ["main"]
      role_assignments = [
        { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Contributor" },
        { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Monitoring Reader" },
      ]
    }
    plan = {
      repository    = "acme/infra"
      owner_id      = "1001"
      repository_id = "2002"
      pull_request  = true
      role_assignments = [
        { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Reader" },
      ]
    }
  }
}

run "trust_is_exact_subjects" {
  command = plan

  assert {
    condition     = sort(values(output.subjects)) == sort(["repo:acme@1001/infra@2002:environment:prod", "repo:acme@1001/infra@2002:ref:refs/heads/main", "repo:acme@1001/infra@2002:pull_request"])
    error_message = "Only the listed environment, branch and pull_request subjects may be trusted, in GitHub's immutable-ID format - no wildcards."
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
        repository    = "acme/bad"
        owner_id      = "1001"
        repository_id = "2002"
        environments  = ["prod"]
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
        repository    = "acme/bad"
        owner_id      = "1001"
        repository_id = "2002"
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
        repository    = "acme/bad"
        owner_id      = "1001"
        repository_id = "2002"
        environments  = ["prod"]
        role_assignments = [
          { scope = "everything", role = "Reader" },
        ]
      }
    }
  }

  expect_failures = [var.deployers]
}

# GitHub emits sub as repo:OWNER@OWNER_ID/REPO@REPO_ID:<suffix> when a repo has
# use_immutable_subject (true for recently created repos). Azure matches the
# federated credential's subject EXACTLY, so a classic-format subject would
# silently never authenticate.
run "classic_format_is_available_for_repos_that_emit_it" {
  command = plan

  variables {
    subject_format = "classic"
    deployers = {
      old = {
        repository   = "acme/legacy"
        environments = ["prod"]
        role_assignments = [
          { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Reader" },
        ]
      }
    }
  }

  assert {
    condition     = values(output.subjects) == ["repo:acme/legacy:environment:prod"]
    error_message = "classic format should produce repo:owner/repo:<suffix> and need no IDs."
  }
}

run "immutable_format_requires_the_ids" {
  command = plan

  variables {
    deployers = {
      bad = {
        repository   = "acme/infra"
        environments = ["prod"]
        role_assignments = [
          { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Reader" },
        ]
      }
    }
  }

  expect_failures = [var.deployers]
}

run "rejects_non_numeric_ids" {
  command = plan

  variables {
    deployers = {
      bad = {
        repository    = "acme/infra"
        owner_id      = "acme"
        repository_id = "2002"
        environments  = ["prod"]
        role_assignments = [
          { scope = "/subscriptions/00000000-0000-0000-0000-000000000000", role = "Reader" },
        ]
      }
    }
  }

  expect_failures = [var.deployers]
}

run "rejects_unknown_subject_format" {
  command = plan

  variables {
    subject_format = "wildcard"
  }

  expect_failures = [var.subject_format]
}

