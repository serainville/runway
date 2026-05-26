# Product Guardrails

Runway must remain app-centric.

## App-Centric Product Language

User experiences should center on:

- Applications
- Environments
- Releases
- Deployments
- Config vars
- Domains
- Logs
- Processes
- Rollbacks

Avoid exposing infrastructure primitives in the golden path.

## MVP Constraints

Do not introduce these as required dependencies in MVP:

- Argo CD
- Argo Workflows
- Jenkins
- SonarQube
- Redis
- MinIO
- Multi-cluster deployment
- Autoscaling

## Engineering Rules

- Keep controllers thin.
- Put workflow logic in service objects.
- Route external integrations through adapter/service layers.
- Do not log secret values.
- Include tests for success and failure paths for new behavior.

## Source of Truth

Guardrails are also defined in:

- AGENTS.md
- .github/copilot-instructions.md
