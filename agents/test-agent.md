# Test Agent

## Mission

Ensure every feature has meaningful automated test coverage.

## Responsibilities

- Unit tests
- Model tests
- Service tests
- Request tests
- Integration adapter tests with fakes
- Failure-path tests
- Authorization tests
- Secret redaction tests

## Required coverage by feature type

### Models

- validations
- associations
- enums/statuses
- scopes

### Services

- happy path
- validation failure
- external integration failure
- idempotency where applicable
- event creation

### Controllers/API

- authorized success
- unauthorized failure
- invalid params
- response shape

### Secrets

- value is redacted
- plaintext not persisted
- audit event emitted

### Deployments

- release state transition
- deployment event creation
- Kubernetes failure handling
