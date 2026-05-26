# Security Model

## Principles

- Team isolation by default.
- App access is controlled by team membership.
- Secret values are stored in Vault.
- MySQL stores secret metadata only.
- Runtime secrets are synced through External Secrets Operator.
- Kubernetes deployment credentials are scoped to required targets.
- Mutation actions create audit events.

## Secret rules

- Never store plaintext secrets in MySQL.
- Never display secret values after creation.
- Never log secret values.
- Redact sensitive config values in UI/API/CLI.

## MVP boundaries

The MVP deploys only to tenant nonp.

Prod deployment, multi-cluster deployment, and advanced policy gates are MVP+.
