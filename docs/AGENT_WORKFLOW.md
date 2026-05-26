# Agentic Development Workflow

## Recommended VSCode flow

Use repository-level instructions for always-on project rules and prompt files for repeatable tasks.

Suggested flow for each feature:

1. Run the feature planning prompt.
2. Review or update the generated implementation plan.
3. Run the Rails feature prompt.
4. Run the test prompt.
5. Run the security review prompt.
6. Run the documentation prompt.
7. Open a merge request with a concise summary.

## Feature lifecycle

```text
Feature request
  -> Product scope
  -> Acceptance criteria
  -> Domain/API design
  -> Implementation
  -> Tests
  -> Security review
  -> Documentation
  -> MR review
```

## Agent responsibilities

### Product Architect Agent

Owns scope, user stories, terminology, acceptance criteria, MVP boundaries, and product consistency.

### Rails Control Plane Agent

Owns Rails models, controllers, services, jobs, UI/API endpoints, validations, and status transitions.

### Kubernetes Integration Agent

Owns Kubernetes adapter classes, resource renderers, rollout observation, namespace handling, and generated resource correctness.

### Secrets Agent

Owns Vault integration, config var lifecycle, ExternalSecret rendering, redaction, and secret audit behavior.

### Routing Agent

Owns Istio VirtualService generation, default domains, route validation, and routing status.

### Build and Registry Agent

Owns GitLab source integration, build jobs, Nexus image publishing, image digest capture, and build logs.

### Release and Deployment Agent

Owns release creation, deployment orchestration, deployment events, rollback, and failure status transitions.

### Observability Agent

Owns logs, status views, metrics-server integration, event timelines, and Kubernetes error translation.

### Security Review Agent

Owns authz, team isolation, secret safety, audit logs, privilege boundaries, and MVP threat review.

### Test Agent

Owns automated tests, failure-path coverage, fixtures, factories, and regression coverage.

### Documentation Agent

Owns README, architecture docs, user guides, CLI docs, API docs, and runbooks.
