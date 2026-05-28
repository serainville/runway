# Follow-up Work
- Implement Authentication::Providers::LdapProvider in MVP+ with secure bind/config handling.
- Implement Authentication::Providers::OidcProvider with callback/state/nonce validation.
- Add install-level auth mode management UI/settings (operator-only).
- Add account-linking policies and provisioning strategy for external identities.

- Add repository discovery adapters for GitHub and Bitbucket to match current provider set.
- Add pagination/search for large repository lists.
- Expand provider-specific error mapping for richer inline troubleshooting hints.

- Build pipeline architecture:
	- Keep Runway as build orchestration control plane (build lifecycle, quality gates, logs, audit, artifact metadata).
	- MVP default: out-of-the-box isolated executor using runtime-versioned ephemeral builder images (lint/syntax -> unit tests -> image build).
	- Future feature: delegated executor integration adapters for Jenkins and Argo Workflows while preserving the same Runway build model and UI.
	- Maintain a pluggable execution adapter boundary so internal and delegated executors can coexist without changing app-facing workflow.


- Add remaining service tests for heartbeat, phase ordering edge cases, logs, and completion idempotency paths.
- Harden worker auth from shared token to short-lived signed credentials per worker identity.
- Add build timeline and log viewer UI on app page.
- Add retry and reclaim behavior for expired leases and late callbacks.
- Expand build details with pagination/filtering for long logs and large host request histories.
- Add Docker container inspect polling to keep runtime status fresh after initial start event.

## Feature Plan: Build Executor Service

## Summary

Create a standalone Runway Build Executor application (Ruby, non-Rails) that receives build commands from Runway and executes lint, test, and image build steps in isolated runtime environments.

MVP supports:
- Docker host execution using task containers.
- A single runtime-versioned builder image reused across lint, test, and build steps.
- Image build/push via gcrane.

Future-ready support:
- Kubernetes execution backend using a Kubernetes client while preserving the same Runway build model and user experience.

## User Story

As a platform operator, I want Runway builds to execute through a dedicated executor service, so that build workloads are isolated from the control plane and can run consistently on Docker host or Kubernetes.

## Problem

Runway currently mixes control-plane responsibilities with build-host orchestration concerns. This increases coupling, makes runtime portability harder, and limits clear ownership for build execution reliability. A dedicated executor app separates orchestration intent (Runway) from execution mechanics (Docker/Kubernetes), improving maintainability, security boundaries, and operational flexibility.

## In Scope

- Standalone Ruby executor service (no Rails) with HTTP API for build command intake from Runway.
- Authenticated command contract between Runway and executor (signed token or shared secret in MVP, extensible later).
- Execution adapters:
	- Docker adapter: run lint/test/build as task containers on Docker host.
	- Kubernetes adapter: manage task pods/jobs through Kubernetes client.
- MVP build sequence: lint -> test -> build (gcrane image build/push).
- Builder image strategy:
	- Single builder image per runtime/version for all three steps in MVP.
	- Lightweight Dockerfile(s) for supported runtime targets with required tools preinstalled.
- Step-level status and log streaming/callbacks back to Runway.
- Deterministic phase mapping from executor statuses to Runway build phases.
- Basic retry/idempotency guards for duplicate command delivery.

## Out of Scope

- End-user exposure of Docker/Kubernetes primitives in Runway UX.
- Argo CD, Argo Workflows, Jenkins, SonarQube integration in MVP.
- Autoscaling policy automation, multi-cluster scheduling, and tenant prod deployment orchestration.
- Full marketplace of buildpacks/add-ons.
- Advanced distributed queueing stack changes unrelated to executor protocol.

## User-Facing Behavior

- Developers click Build in Runway and continue to see app-centric statuses (Pending, Running, Failed, Succeeded), logs, and failure reasons.
- Developers do not choose Docker vs Kubernetes; platform configuration determines execution backend.
- Build history continues to show commit, release artifact metadata, and detailed step outcomes.
- On failures, users see clear phase-specific messages (lint/test/build) with actionable error details.

## Domain Model Impact

Models to create or change in Runway:

- Build (change):
	- add executor job identifier, executor backend, attempt number, started/finished timestamps by phase.
	- store normalized step result summary for lint/test/build.
- BuildPhaseEvent (change):
	- include external step identifier and adapter-specific metadata (normalized for UI).
- BuildLogChunk (change):
	- support source label (executor step) and ordering token for safe incremental streaming.
- BuildHostRequestEvent (change):
	- generalize to BuildExecutionRequestEvent so Docker and Kubernetes adapter diagnostics can be captured consistently.
- BuildIntegration (change):
	- add executor endpoint/auth settings and backend mode (docker|kubernetes).
- Release (change):
	- persist artifact reference produced by gcrane build/push and immutable link to originating build.
- AuditEvent (change):
	- add executor command dispatched, executor callback received, and execution backend selection events.
- DeploymentTarget (no direct MVP behavior change):
	- remains runtime deployment concern; build execution remains separate concern.

## Service Objects Needed

Runway control plane services:

- Builds::DispatchToExecutor
- Builds::HandleExecutorCallback
- Builds::NormalizeStepStatus
- Builds::AppendExecutorLogs
- Builds::MarkExecutorHeartbeat
- Builds::FinalizeFromExecutorResult
- Builds::RecordExecutionRequestEvent

Executor app services (Ruby non-Rails):

- Executor::CommandServer
- Executor::Auth::VerifyRequest
- Executor::Builds::StartRun
- Executor::Builds::RunSequence
- Executor::Builds::RunStep
- Executor::Adapters::Docker::RunStep
- Executor::Adapters::Kubernetes::RunStep
- Executor::Artifacts::BuildWithGcrane
- Executor::Callbacks::PublishStatus
- Executor::Callbacks::PublishLogs

## External Integrations

- GitLab:
	- source checkout metadata is consumed from Runway command payload or pre-fetched artifact refs.
- Nexus:
	- target image registry for built artifacts.
- Kubernetes API:
	- used by Kubernetes adapter to run and monitor build tasks.

MVP note:
- Vault may be used to supply executor credentials securely, but no secret plaintext is persisted in MySQL.

## Security Considerations

- Authorization:
	- only trusted Runway control plane can issue executor commands.
- Team ownership:
	- every executor command includes tenant, project, and application identifiers validated by Runway before dispatch.
- Secret handling:
	- registry credentials and signing secrets retrieved from secure secret backend (Vault) or runtime secret injection.
	- secrets never logged, never echoed in callback payloads, and redacted from persisted diagnostics.
- Audit events:
	- dispatch, callback, cancellation, and terminal result transitions are auditable.
- External credentials:
	- short-lived tokens preferred; rotate static credentials in MVP if short-lived unavailable.
- Tenant isolation:
	- per-build isolated execution context (container/pod namespace scoping, temp workspace cleanup, no cross-build volume reuse by default).

## Failure Modes

- Executor unreachable:
	- build remains pending/running with timeout guard; user sees "Executor unavailable" and retry guidance.
- Auth validation failure:
	- request rejected; user sees "Build dispatch authorization failed"; audit event recorded.
- Docker/Kubernetes adapter startup failure:
	- build fails in "Environment setup" phase with adapter-specific diagnostics.
- Lint failure:
	- build marked failed in lint phase; logs and failing command shown.
- Test failure:
	- build marked failed in test phase; logs and failing command shown.
- gcrane build/push failure:
	- build marked failed in build phase; registry/push error summary shown.
- Callback lost or delayed:
	- Runway heartbeat/timeout reconciliation marks status accurately and avoids indefinite running.
- Duplicate callback delivery:
	- idempotent callback handling prevents duplicate phase transitions.

## Tests Required

Runway tests:

- Happy path:
	- build request dispatches to executor, receives callbacks, transitions to succeeded, and creates release artifact metadata.
- Validation failure:
	- invalid integration config or malformed callback payload is rejected with clear error.
- Authorization failure:
	- unauthorized dispatch/callback rejected and audited.
- External integration failure:
	- executor unreachable, adapter errors, and registry failures mapped to user-visible phase failures.
- Audit/deployment event creation:
	- dispatch/callback/result audit events created reliably.
- Secret redaction:
	- logs, request events, and error payload persistence redact secrets.

Executor tests:

- Happy path:
	- Docker adapter executes lint->test->build sequence and sends ordered callbacks.
- Validation failure:
	- invalid command payload rejected.
- Authorization failure:
	- invalid signature/token rejected.
- Integration failure:
	- Docker daemon unavailable, Kubernetes API failure, and gcrane failure handled with structured result.
- Idempotency:
	- duplicate command id does not execute twice.

## Acceptance Criteria

- Runway can dispatch a build command to a standalone Ruby executor service.
- Executor can run lint, test, and gcrane build/push steps and report each step status back to Runway.
- Developers see app-centric status progression and logs in Runway without needing Docker/Kubernetes knowledge.
- Build failures are phase-specific with actionable messages.
- Secrets are never persisted or displayed in plaintext.
- Audit events are created for dispatch and callback lifecycle.
- MVP Docker backend works with a single runtime-versioned builder image reused across all steps.
- Kubernetes backend contract is implemented behind adapter boundary (feature-toggle or configuration gated).
- Lightweight Dockerfile(s) exist for supported runtime targets and include required lint/test/build tooling.

## Implementation Sequence

1. Define protocol
- Specify executor command/callback JSON schemas, signatures, idempotency keys, and status vocabulary.

2. Build standalone executor skeleton
- Create Ruby non-Rails app with HTTP server, auth middleware, structured logging, health endpoint, and command routing.

3. Implement Docker adapter MVP
- Execute lint/test/build as isolated task containers on Docker host.
- Add gcrane artifact build/push support.

4. Add Runway dispatch/callback services
- Implement dispatch service, callback controller/service, status normalization, log ingestion, and idempotency checks.

5. Add domain persistence updates
- Migrate build/execution metadata fields, step diagnostics, artifact refs, and audit events.

6. Create builder image Dockerfile(s)
- Add lightweight runtime-specific Dockerfile(s) with required tools.
- Publish image naming/tagging convention for runtime-versioned builders.

7. Implement Kubernetes adapter boundary
- Add Kubernetes adapter interface and minimal implementation behind configuration flag.

8. Add security hardening
- Enforce request signing, secret redaction, and tenant isolation checks.

9. Complete test matrix
- Add Runway and executor tests for happy path, auth, validation, integration failures, idempotency, and redaction.

10. Roll out incrementally
- Enable in non-production tenant first, observe logs/metrics, then make executor default for MVP build flow.

## API Contract Draft: Runway <-> Executor

### Overview

Runway is the source of truth for build lifecycle state. The executor is the worker plane that performs step execution and emits progress.

Protocol shape for MVP:
- Runway -> Executor: command push (HTTP).
- Executor -> Runway: callback push (HTTP).
- Authentication: signed request headers.
- Idempotency: required on command and callback.

### 1) Dispatch Build Command (Runway -> Executor)

Endpoint:
- POST /v1/build-commands

Headers:
- Content-Type: application/json
- X-Runway-Key-Id: signing key id
- X-Runway-Signature: HMAC-SHA256 over canonical payload
- X-Runway-Timestamp: unix epoch seconds
- X-Runway-Idempotency-Key: unique per command delivery attempt

Request body:

```json
{
	"command_id": "cmd_01HV...",
	"build_id": 1234,
	"attempt": 1,
	"tenant": {
		"id": "tenant-nonp-a",
		"project_id": 456,
		"application_id": 789
	},
	"source": {
		"provider": "gitlab",
		"repo_url": "https://gitlab.example.com/team/app.git",
		"commit_sha": "abc123def456...",
		"ref": "refs/heads/main"
	},
	"runtime": {
		"name": "ruby",
		"version": "3.3"
	},
	"builder": {
		"image": "registry.example.com/runway/executor-builder:ruby-3.3-v1",
		"pull_policy": "IfNotPresent"
	},
	"steps": [
		{
			"name": "lint",
			"command": ["bundle", "exec", "rubocop"],
			"timeout_seconds": 600
		},
		{
			"name": "test",
			"command": ["bin", "rails", "test"],
			"timeout_seconds": 1800
		},
		{
			"name": "build",
			"command": ["gcrane", "cp", "src:image", "dst:image"],
			"timeout_seconds": 1200
		}
	],
	"artifact": {
		"registry": "nexus",
		"repository": "apps/team/app",
		"tag": "sha-abc123def456"
	},
	"callback": {
		"url": "https://runway.example.com/internal/build-executor/callbacks",
		"auth": {
			"scheme": "hmac",
			"key_id": "exec-key-1"
		}
	},
	"metadata": {
		"requested_by": "alice",
		"requested_at": "2026-05-26T15:00:00Z"
	}
}
```

Success response:

```json
{
	"accepted": true,
	"executor_job_id": "job_01HV...",
	"state": "queued"
}
```

Error response examples:
- 400 malformed payload
- 401 invalid signature
- 409 duplicate command_id already accepted
- 422 unsupported runtime or invalid builder image
- 503 executor temporarily unavailable

### 2) Status and Log Callback (Executor -> Runway)

Endpoint:
- POST /internal/build-executor/callbacks

Headers:
- Content-Type: application/json
- X-Executor-Key-Id
- X-Executor-Signature
- X-Executor-Timestamp
- X-Executor-Idempotency-Key

Callback event body:

```json
{
	"command_id": "cmd_01HV...",
	"executor_job_id": "job_01HV...",
	"build_id": 1234,
	"event_type": "step.updated",
	"event_time": "2026-05-26T15:01:12Z",
	"step": {
		"name": "test",
		"status": "running",
		"attempt": 1,
		"started_at": "2026-05-26T15:01:00Z",
		"finished_at": null,
		"exit_code": null
	},
	"logs": [
		{
			"sequence": 102,
			"stream": "stdout",
			"message": "Running test suite..."
		}
	],
	"diagnostics": {
		"backend": "docker",
		"backend_ref": "container://a1b2c3..."
	}
}
```

Terminal callback event:

```json
{
	"command_id": "cmd_01HV...",
	"executor_job_id": "job_01HV...",
	"build_id": 1234,
	"event_type": "build.completed",
	"event_time": "2026-05-26T15:05:32Z",
	"result": {
		"status": "succeeded",
		"artifact_ref": "nexus/apps/team/app:sha-abc123def456",
		"steps": [
			{ "name": "lint", "status": "succeeded" },
			{ "name": "test", "status": "succeeded" },
			{ "name": "build", "status": "succeeded" }
		]
	}
}
```

### 3) Canonical Status Vocabulary

Step status:
- pending
- running
- succeeded
- failed
- cancelled

Build status mapping:
- any running step => running
- all steps succeeded => succeeded
- any failed step => failed
- explicit cancellation => failed (MVP) with reason cancelled

### 4) Idempotency and Ordering

- command_id must be globally unique per build attempt.
- callback idempotency key is required for each callback delivery.
- log entries use monotonic sequence.
- out-of-order callbacks are accepted but only applied if they advance state or add unseen logs.

### 5) Timeouts and Retries

- Runway dispatch timeout: 10s connect/read.
- Executor callback retries: exponential backoff, max 10 attempts.
- Step timeout behavior: timeout => step failed with timeout reason.

### 6) Minimal Internal Endpoints (Executor)

- GET /healthz
- GET /readyz
- POST /v1/build-commands
- GET /v1/build-commands/:command_id (optional MVP observability endpoint)

## Standalone Executor Repository Scaffold Plan

Target:
- Ruby app (non-Rails), rack-based HTTP API, background worker loop for command execution.

Suggested structure:

```text
runway-executor/
	Gemfile
	Gemfile.lock
	Rakefile
	README.md
	.env.example
	config/
		app.rb
		routes.rb
		logging.rb
		auth.rb
	bin/
		server
		worker
	lib/
		executor/
			command_server.rb
			command_store.rb
			command_validator.rb
			auth/
				verify_signature.rb
				sign_payload.rb
			builds/
				start_run.rb
				run_sequence.rb
				run_step.rb
				step_result.rb
			adapters/
				docker/
					client.rb
					run_step.rb
				kubernetes/
					client.rb
					run_step.rb
			artifacts/
				build_with_gcrane.rb
			callbacks/
				publish_status.rb
				publish_logs.rb
			telemetry/
				logger.rb
				metrics.rb
			errors/
				base_error.rb
				auth_error.rb
				adapter_error.rb
	spec/
		command_server_spec.rb
		auth_signature_spec.rb
		adapters_docker_run_step_spec.rb
		adapters_kubernetes_run_step_spec.rb
		builds_run_sequence_spec.rb
		callbacks_publish_status_spec.rb
```

Runtime configuration keys:
- EXECUTOR_BIND_ADDRESS
- EXECUTOR_PORT
- EXECUTOR_SIGNING_KEY_ID
- EXECUTOR_SIGNING_SECRET
- RUNWAY_CALLBACK_TIMEOUT_SECONDS
- EXECUTOR_BACKEND_MODE (docker|kubernetes)
- DOCKER_HOST
- KUBERNETES_NAMESPACE
- NEXUS_REGISTRY_URL

Core gem set (example):
- rack
- puma
- dry-validation
- faraday
- jwt or custom openssl-based HMAC implementation
- docker-api (for Docker mode) or direct HTTP client
- kubernetes-client (for Kubernetes mode)
- rspec

## Dockerfile Plan for Builder Images

MVP builder image principles:
- one image per runtime+version
- includes tools for lint, test, and image build (gcrane)
- minimal base and smallest practical package set

Naming convention:
- runway/executor-builder:<runtime>-<version>-v<image_rev>

Example runtime targets:
- ruby-3.3
- node-22
- python-3.12

Example Dockerfile pattern:

```Dockerfile
FROM alpine:3.21

RUN apk add --no-cache \
		bash ca-certificates curl git openssh-client \
		ruby ruby-dev build-base \
		nodejs npm \
		python3 py3-pip \
		docker-cli

# Install gcrane binary
RUN curl -fsSL https://github.com/google/go-containerregistry/releases/download/v0.20.3/go-containerregistry_Linux_x86_64.tar.gz \
	| tar -xz -C /usr/local/bin gcrane

WORKDIR /workspace

ENTRYPOINT ["/bin/bash", "-lc"]
```

Security notes:
- pin base image digest in production builds
- pin gcrane checksum verification
- run as non-root where compatible with toolchain

## MVP Ticket List (Agent-Ready)

E1. Protocol and schema
- Define request/callback JSON schema and signed header contract.
- Deliverable: docs and shared validation fixtures.

E2. Executor skeleton app
- Create non-Rails Ruby service with routes, health checks, auth middleware.
- Deliverable: runnable local server and test harness.

E3. Docker adapter step execution
- Implement lint/test/build container execution with timeout handling.
- Deliverable: passing adapter specs and integration smoke test.

E4. gcrane artifact service
- Implement image build/push workflow and artifact ref output.
- Deliverable: structured result payload and failure mapping.

E5. Runway dispatch integration
- Add Builds::DispatchToExecutor and command persistence metadata.
- Deliverable: service tests for accepted/rejected/timeout flows.

E6. Runway callback ingestion
- Add internal callback endpoint and idempotent state transition logic.
- Deliverable: request tests and model transition coverage.

E7. Log ingestion and phase events
- Append ordered log chunks and step events with dedupe semantics.
- Deliverable: ordering/idempotency tests.

E8. Build integration config extension
- Add executor endpoint/auth/backend mode fields and validation UI wiring.
- Deliverable: admin tests and validation messages.

E9. Builder Dockerfiles
- Create runtime builder Dockerfile(s) and publish instructions.
- Deliverable: buildable images with lint/test/gcrane tools.

E10. Security hardening
- Ensure secret redaction, audit events, and auth rotation runbook.
- Deliverable: security tests and operational docs.

E11. Kubernetes adapter (gated)
- Implement adapter boundary and minimal pod execution path behind feature flag.
- Deliverable: contract tests with backend-agnostic Runway behavior.

E12. Nonp rollout and observability
- Enable in nonp tenant, add metrics/alerts, and complete cutover checklist.
- Deliverable: rollout report and known-issues log.