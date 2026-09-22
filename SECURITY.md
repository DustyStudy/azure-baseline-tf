# Security

`azure-baseline-tf` is a portfolio/reference project. It is not a supported product and
there is no SLA on fixes, but security reports are welcome.

## Design principles

- **No standing cloud credentials.** CI authenticates to Azure through federated managed identities (GitHub OIDC);
  there is no long-lived key or client secret in this repo or its workflows.
- **Least-privilege CI.** Workflows run with a read-only `GITHUB_TOKEN`
  (`permissions: contents: read`).
- **Pinned third-party actions.** Actions are pinned to a full commit SHA,
  not a mutable tag, and kept current by Dependabot
  (see `.github/dependabot.yml`).
- **Every change is scanned.** Pull requests must pass `terraform fmt`,
  `terraform validate`, the mocked `terraform test` suites, and a Checkov
  static security scan before merge.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting: open the repository's
**Security** tab and choose **Report a vulnerability**. Please do not open a
public issue or pull request that demonstrates the problem.

## Scope

The modules here are examples and starting points. Review the plan and adapt
the defaults to your own environment before applying them to a real
organization or tenant.
