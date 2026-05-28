# Security Model

## Principles

- Team isolation by default.
- App access is controlled by team membership.
- Secret values are stored in Vault.
- MySQL stores secret metadata only.
- Runtime secrets are synced through External Secrets Operator.
- Kubernetes deployment credentials are scoped to required targets.
- Mutation actions create audit events.

## Project role authorization

- Owner:
	- Full project administration.
	- Manage project members and project-level settings.
	- Initiate builds and deployments.
- Contributor:
	- Read access.
	- Initiate builds and deployments.
- Reviewer:
	- Read-only access.

## Project visibility

- Private project: only assigned members can access.
- Public project: authenticated users can read by default; write actions still require assigned role authorization.

## Secret rules

- Never store plaintext secrets in MySQL.
- Never display secret values after creation.
- Never log secret values.
- Redact sensitive config values in UI/API/CLI.

## MVP boundaries

The MVP deploys only to tenant nonp.

Prod deployment, multi-cluster deployment, and advanced policy gates are MVP+.
