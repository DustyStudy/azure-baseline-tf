# azure-baseline-tf

[![CI](https://github.com/DustyStudy/azure-baseline-tf/actions/workflows/ci.yml/badge.svg)](https://github.com/DustyStudy/azure-baseline-tf/actions/workflows/ci.yml)
[![Terraform >= 1.10](https://img.shields.io/badge/terraform-%3E%3D1.10-623CE4?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

An Azure baseline in Terraform: preventive guardrails, a tamper-resistant audit
archive, and keyless CI/CD. It is the Azure counterpart of the AWS repos and
[`gcp-org-baseline-tf`](https://github.com/DustyStudy/gcp-org-baseline-tf), so
the same three ideas exist on every cloud:

| Idea | AWS | GCP | **Azure (this repo)** |
|---|---|---|---|
| Preventive guardrails | SCPs (`aws-orgseed`) | Org policies | [`policy-guardrails`](modules/policy-guardrails) (Azure Policy) |
| Tamper-resistant audit archive | Org CloudTrail (`aws-orgseed`) | Aggregated log sink + locked bucket | [`activity-log-archive`](modules/activity-log-archive) |
| Keyless CI/CD | GitHub OIDC -> IAM role (`aws-platform`) | Workload Identity Federation | [`github-oidc`](modules/github-oidc) |

It complements [`azure-lighthouse-tf`](https://github.com/DustyStudy/azure-lighthouse-tf),
which handles cross-tenant *delegation*; this repo is what you run *inside* a
tenant. Both use the same `azure_environment` convention (`public` /
`usgovernment`) and OIDC-only authentication.

```
modules/
  policy-guardrails/    # 8 built-in Azure Policy assignments at a management group or subscription:
                        # allowed locations, HTTPS-only + no public blobs + no shared keys on storage,
                        # no public SQL, Key Vault soft delete + purge protection, no NIC public IPs
  activity-log-archive/ # subscription Activity Log -> immutable (WORM), deny-by-default storage account
                        # in a dedicated, delete-locked resource group; optional customer-managed key
  github-oidc/          # user-assigned managed identities + federated credentials for GitHub Actions
examples/complete/      # the three composed together (plan-tested with unknown cross-module values)
```

## Design decisions

- **Policy IDs are verified, not remembered.** Every built-in definition GUID
  in `policy-guardrails` was checked against Microsoft's published definitions
  ([Azure/azure-policy](https://github.com/Azure/azure-policy)) - the effect
  parameters and display names too. (One ID recalled from memory turned out to
  be wrong; checking is why it isn't in here.)
- **Report first, then enforce.** `enforce = false` assigns every policy in
  `DoNotEnforce` mode: compliance is evaluated and reported, nothing is
  blocked. Review the compliance report, then set `enforce = true`. Deny
  policies at a management group can break existing pipelines.
- **The audit archive is immutable, and the lock is opt-in.** Blobs are WORM
  for `retention_days`. `lock_immutability` makes that permanent and is
  **irreversible**, so it defaults to off. The resource group also carries a
  `CanNotDelete` lock, and access is deny-by-default with an IP allow-list.
- **Public network access stays on (as "selected networks") on purpose.**
  Azure Monitor writes the Activity Log through the *trusted-services bypass*,
  which doesn't work when public access is fully disabled. Fully private
  access would need a private endpoint that Azure Monitor doesn't use.
- **No client secrets.** Deployers are user-assigned managed identities with
  federated credentials - no Entra directory permissions needed to create
  them, unlike app registrations. Trust is by exact GitHub subject
  (`environment:<name>`, `ref:refs/heads/<branch>`, `pull_request`), never a
  wildcard, and `Owner` / `User Access Administrator` /
  `Role Based Access Control Administrator` are rejected by validation.
  Use one deployer for `pull_request` plans (read-only) and another for
  environment-gated applies.

## Scope and honesty

- **A baseline, not a landing zone.** It doesn't create management groups,
  subscriptions, hub networking, ExpressRoute/VPN, or Defender for Cloud
  configuration.
- **One subscription per archive.** The Activity Log diagnostic setting is per
  subscription; use one module instance per subscription. Guardrails, by
  contrast, can be assigned once at a management group.
- **Azure Government.** Set `azure_environment = "usgovernment"` and supply
  Government regions in `allowed_locations`. The built-in policy IDs are the
  same, but not every built-in is available in every cloud - confirm in your
  tenant before enforcing.
- **Tests use a mocked provider** (`terraform test`), plus schema validation
  against the real `azurerm` provider. They verify the configuration's logic
  and guardrails, **not that Azure accepts it. Nothing here has been applied to
  a real tenant.**
- **Shared Key auth is disabled** on the archive by default, so the azurerm
  provider needs `storage_use_azuread = true` (set in the example).

## Using it

```bash
terraform -chdir=examples/complete init
terraform -chdir=examples/complete plan \
  -var subscription_id=... -var policy_scope=/subscriptions/... \
  -var 'allowed_locations=["eastus","westus2"]' -var location=eastus \
  -var audit_storage_account_name=... -var github_owner=...
```

Trial on a single subscription with `enforce_policies = false` (the example's
default) before assigning at a management group.

## Tests

```bash
for d in modules/* examples/*; do terraform -chdir=$d init -backend=false && terraform -chdir=$d test; done
```
