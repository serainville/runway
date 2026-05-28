# Executor Bootstrap Spec

## Purpose

Define the initial structure and responsibilities for the standalone Runway executor application.

The executor is implemented in Ruby without Rails and runs as a separate service from Runway control plane.

## Non-goals

- No user-facing UI.
- No deployment workflow ownership.
- No delegated external CI integration in MVP.

## Runtime Support

MVP:
- Docker execution backend.

Gated future support:
- Kubernetes execution backend via adapter boundary.

## Repo Skeleton

The in-repo scaffold is present under executor/ and can be extracted into a standalone repository later.

```text
executor/
  Gemfile
  Rakefile
  README.md
  .env.example
  bin/
    server
    worker
  config/
    app.rb
    routes.rb
  lib/
    executor/
      app.rb
      command_server.rb
      auth/
      builds/
      adapters/
      artifacts/
      callbacks/
      telemetry/
      errors/
  spec/
    smoke_spec.rb
```

## Contracts

Contract schemas live in:
- docs/executor/contracts/build-command.schema.json
- docs/executor/contracts/build-callback.schema.json

## MVP Flow

1. Runway dispatches build command.
2. Executor validates signature and schema.
3. Executor runs ordered steps: lint, test, build.
4. Executor streams progress callbacks.
5. Executor posts terminal callback with artifact reference.

## Security Baseline

- Signed request validation required on ingress and callbacks.
- Command and callback idempotency required.
- Secret values redacted from logs and diagnostics.
- Per-build workspace isolation and cleanup required.

## Operational Baseline

- /healthz and /readyz endpoints.
- Structured logs with command_id and build_id correlation.
- Step timeouts and callback retries.

## Exit Criteria for Bootstrap

- Local server boots and accepts schema-valid command payload.
- Stub worker path emits step.updated and build.completed callbacks.
- Smoke tests pass for auth, validation, and callback serialization.
