# Copilot Instructions for Runway

## Product Context

Runway is a Rails-based Heroku-like application platform for deploying apps to Kubernetes.

The goal is to let developers deploy applications using simple app-centric workflows without needing to understand Kubernetes primitives.

Users should think in terms of:

- Apps
- Environments
- Releases
- Deployments
- Config vars
- Domains
- Logs
- Processes
- Rollbacks

They should not need to think in terms of:

- Pods
- ReplicaSets
- Kubernetes Deployments
- Services
- ConfigMaps
- Secrets
- ExternalSecrets
- VirtualServices
- Gateways
- Namespaces
- ServiceAccounts
- Helm charts
- Argo CD Applications
- Argo Workflows

Kubernetes details are implementation details unless the task is explicitly about internal platform integration.

---

## MVP Scope

The MVP should use the minimum platform stack needed to prove the core deployment loop.

Use:

- Rails for the control plane
- MySQL nonp for the Runway database
- GitLab for source repository integration
- Nexus for image registry
- Vault for secret storage
- External Secrets Operator for syncing runtime secrets
- Istio for routing
- Kubernetes API for deploying to the tenant nonp cluster
- Kubernetes metrics-server for basic runtime status

Do not introduce these into MVP code paths unless the task explicitly says MVP+:

- Argo CD
- Argo Workflows
- Jenkins
- SonarQube
- Redis
- MinIO
- tenant prod deployment
- multi-cluster deployment
- autoscaling
- full add-on marketplace

---

## Product Rules

1. Keep the user experience app-centric.
2. Do not expose Kubernetes YAML in the golden path.
3. Every deployable version must be represented as an immutable Release.
4. Every deployment action must create durable DeploymentEvents.
5. Rollback must create a new Deployment referencing a previous Release.
6. Do not mutate old releases to hide history.
7. Secret values must never be stored in plaintext in MySQL.
8. Secret values must never be displayed after creation.
9. Secret values must never be logged.
10. All external integrations must go through adapter/service classes.
11. Controllers must stay thin.
12. Business workflows belong in service objects.
13. Every feature must include tests for success and failure paths.

---

## Preferred Rails Structure

Use service objects for workflows.

Suggested namespaces:

```text
app/services/applications
app/services/environments
app/services/config_vars
app/services/releases
app/services/deployments
app/services/gitlab
app/services/kubernetes
app/services/vault
app/services/registry