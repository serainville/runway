# Runway Agent Guide

Runway is a Rails-based control plane for a Heroku-like Kubernetes deployment platform.

The product goal is to let developers deploy applications using app-centric concepts:

- Apps
- Environments
- Releases
- Config vars
- Domains
- Logs
- Processes
- Rollbacks

Kubernetes resources are implementation details.

## Non-negotiable product rules

1. Do not expose Kubernetes primitives in the normal user experience.
2. Users should not need to write Kubernetes YAML for the golden path.
3. The MVP must avoid Argo CD, Argo Workflows, Jenkins, SonarQube, Redis, and MinIO as required deployment-path dependencies.
4. The MVP may integrate with Rails, MySQL nonp, GitLab, Nexus, Vault, External Secrets Operator, Istio, Kubernetes API, and metrics-server.
5. Every deployable version must be represented as an immutable Release.
6. Every deployment action must create durable DeploymentEvents.
7. Every secret must be stored in Vault or a secure secret backend, not plaintext in MySQL.
8. Secret values must be redacted after creation.
9. Kubernetes API access must go through a dedicated adapter/service layer.
10. Every feature must include tests for success and failure paths.

## MVP architecture

```text
Developer
  -> Runway CLI / Web UI
  -> Rails Control Plane
  -> MySQL nonp
  -> GitLab
  -> Nexus Registry
  -> Vault
  -> Tenant nonp Kubernetes Cluster
       -> Namespace
       -> ExternalSecret
       -> Deployment
       -> Service
       -> Istio VirtualService
```

## Agent handoff model

Agents should work in this order for new features:

1. Product Architect Agent clarifies scope and acceptance criteria.
2. Rails Agent implements domain, controller, service, and UI/API changes.
3. Integration Agent implements external adapter changes.
4. Test Agent creates/updates automated tests.
5. Security Agent reviews authentication, authorization, and secret handling.
6. Documentation Agent updates docs and usage examples.

## Definition of done

A feature is complete only when:

- The user-facing behavior is app-centric.
- Models and services are tested.
- Failure paths are tested.
- Audit/deployment events are emitted where relevant.
- Secret values are never logged or displayed.
- External integrations are behind adapters.
- Documentation is updated.
