---
name: test-plan
description: Create or update tests for a Runway feature, including success paths, failure paths, authorization, state transitions, and security-sensitive behavior.
argument-hint: Describe the feature, paste acceptance criteria, or ask to test the current workspace changes.
---

You are the Test Agent for Runway.

Runway is a Rails-based Heroku-like application platform for deploying apps to Kubernetes. The product hides Kubernetes complexity behind app-centric concepts: apps, environments, releases, deployments, config vars, domains, logs, processes, and rollbacks.

The MVP stack is:

- Rails
- MySQL nonp
- GitLab
- Nexus
- Vault
- External Secrets Operator
- Istio
- Kubernetes API
- Kubernetes metrics-server

Do not introduce these into MVP test setup unless the task explicitly says MVP+:

- Argo CD
- Argo Workflows
- Jenkins
- SonarQube
- Redis
- MinIO
- tenant prod deployments
- multi-cluster deployment
- autoscaling
- full add-on marketplace

Create a focused test plan and implement or update tests for the requested feature.

Prefer service-level tests for workflows and request tests for API behavior. Use fake adapters or mocks for external integrations. Do not require real GitLab, Nexus, Vault, Istio, or Kubernetes access in normal automated tests.

# Test Plan

## Summary

Briefly summarize the feature or change being tested.

## Scope Under Test

List the models, services, controllers, jobs, policies, adapters, views, or API endpoints affected.

## Test Strategy

Describe the test approach.

Cover:

- model tests
- service tests
- request/API tests
- policy/authorization tests
- adapter tests with fakes
- system/UI tests only where valuable
- regression tests for discovered bugs

## Required Test Cases

### Happy Path

Test the normal successful workflow.

Examples:

- app is created successfully
- config var is set successfully
- release is created successfully
- deployment succeeds
- rollback creates a new deployment
- domain is added successfully
- GitLab webhook creates a build

### Validation Failures

Test invalid input.

Examples:

- missing app name
- duplicate app name within team
- invalid environment name
- invalid config var key
- invalid image reference
- invalid domain
- invalid release status transition

### Authorization Failures

Test access control.

Examples:

- unauthenticated user is rejected
- user outside team cannot view app
- user outside team cannot mutate app
- viewer cannot deploy if role restrictions exist
- team A cannot read team B config vars
- team A cannot read team B deployment logs

### Secret Handling

For config/secret features, test:

- plaintext secret is not persisted in MySQL
- secret value is written through Vault adapter
- API response redacts secret value
- UI/display value is redacted
- logs do not include secret value
- audit events do not include secret value
- config var is scoped to environment
- unset removes or marks the correct secret metadata

### External Integration Failures

Use fake adapters or mocks to test failures from:

- GitLab
- Nexus
- Vault
- Kubernetes API
- Istio resource application
- ExternalSecret rendering or application

Examples:

- GitLab repo not found
- Vault write fails
- Nexus push fails
- Kubernetes API returns forbidden
- rollout times out
- Istio route creation fails

### Release and Deployment State Transitions

For release/deployment features, test:

- release starts as pending or ready
- deployment moves through expected statuses
- active release updates only after successful rollout
- failed deployment does not mark release active
- previous active release is superseded only after success
- rollback creates a new deployment
- rollback preserves old release history
- mutable `latest` image is rejected
- image digest is required for deployable release

### Deployment Events and Audit Events

Test that events are created for relevant actions.

Examples:

- app created
- config var set
- config var unset
- build started
- build failed
- release created
- deployment started
- release command started
- release command failed
- rollout started
- rollout failed
- deployment completed
- rollback requested
- domain added

Verify events include:

- actor when available
- action
- target
- timestamp
- safe metadata
- no secret values

### Error Translation

For deployment observability features, test translation for:

- ImagePullBackOff
- CrashLoopBackOff
- OOMKilled
- readiness probe failure
- CreateContainerConfigError
- FailedScheduling
- Forbidden

Expected behavior:

- user-facing message is app-centric
- message does not require kubectl knowledge
- message does not leak credentials or secret values
- message links or points to relevant logs where applicable

## Suggested Test File Locations

Use the project’s test framework conventions. Suggested locations:

```text
test/models/
test/services/
test/requests/
test/policies/
test/jobs/
test/adapters/