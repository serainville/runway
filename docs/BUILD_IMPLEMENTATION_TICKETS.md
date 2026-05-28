# Build Implementation Tickets (MVP)

## Purpose
Actionable engineering tickets for implementing Runway build execution MVP using:

1. Docker host executor (MVP)
2. Internal worker protocol
3. App-centric build lifecycle and UI

This ticket plan aligns with:

1. `docs/BUILD_EXECUTION_ADR.md`
2. `docs/BUILD_EXECUTOR_OPERATOR_CONFIG.md`
3. `docs/BUILD_WORKER_PROTOCOL.md`
4. `docs/BUILD_RAILS_FEATURE_IMPLEMENTATION_PLAN.md`

## Delivery Strategy
Execute in three streams that can run partly in parallel:

1. Persistence and state machine
2. Control-plane API and orchestration
3. Worker runtime and executor adapter

Suggested sequencing:

1. Complete Stream A baseline first (schema + status model)
2. Start Stream B and Stream C in parallel
3. Integrate and harden end-to-end

## Stream A: Persistence and State Machine

### A1: Add Build domain persistence
Type: backend model and migration

Scope:
1. Create or extend `Build` model with required fields:
   - application_id
   - status
   - runtime_key
   - source_ref
   - commit_sha
   - artifact_reference
   - lease_id
   - worker_id
   - started_at
   - finished_at
   - retry_count
   - failure_code
   - error_summary
2. Add DB constraints for status presence and valid transitions where practical.
3. Add indexes on `(application_id, created_at)`, `(status)`, `(lease_id)`.

Acceptance:
1. Schema supports all protocol and lifecycle fields.
2. Model validations prevent invalid status values.
3. Migration is reversible and tested.

Tests:
1. Model validations
2. Association tests
3. DB constraint tests

---

### A2: Implement build lifecycle state machine rules
Type: backend service

Scope:
1. Add `Builds::TransitionStatus` service.
2. Enforce allowed transitions:
   - pending -> running
   - running -> failed_lint | failed_tests | failed_image | succeeded | canceled
3. Reject illegal transitions with explicit errors.

Acceptance:
1. Illegal transitions fail deterministically.
2. Transition calls are idempotent for duplicate terminal updates.

Tests:
1. Happy transition path
2. Invalid transition rejection
3. Idempotent duplicate update behavior

---

### A3: Add build phase and log persistence
Type: backend model and service

Scope:
1. Create `BuildPhaseEvent` (or equivalent) with phase, status, timestamp, message.
2. Create `BuildLogChunk` (or equivalent) with sequence and chunk payload.
3. Add size bounds and sequence monotonic checks.

Acceptance:
1. Logs persist by build and phase with ordered replay.
2. Duplicate chunk sequences are ignored safely.

Tests:
1. Ordered chunk persistence
2. Duplicate chunk idempotency
3. Out-of-order sequence rejection

## Stream B: Control-Plane API and Orchestration

### B1: Build start endpoint and orchestration entrypoint
Type: controller plus service

Scope:
1. Add app-facing endpoint to trigger build from application UI.
2. Implement `Applications::StartBuild`:
   - authorization check
   - build record creation
   - enqueue execution job
   - audit event creation

Acceptance:
1. Authorized users can trigger build.
2. Unauthorized users get forbidden response.
3. Audit event `build.requested` is recorded.

Tests:
1. Request success and forbidden paths
2. Build record created with `pending`
3. Audit event emitted

---

### B2: Internal worker claim endpoint
Type: internal API

Scope:
1. Implement `POST /internal/builds/worker/claim`.
2. Select claimable build and assign lease.
3. Return normalized payload per protocol document.

Acceptance:
1. Worker can claim one build at a time by capability match.
2. Lease metadata returned.
3. Empty queue returns poll interval.

Tests:
1. Job assigned response
2. No-job response
3. Capability mismatch behavior

---

### B3: Internal worker heartbeat endpoint
Type: internal API

Scope:
1. Implement `POST /internal/builds/worker/heartbeat`.
2. Renew lease TTL.
3. Return cancellation signal if requested.

Acceptance:
1. Lease renews while build is running.
2. Expired or invalid lease is rejected.

Tests:
1. Valid heartbeat renews lease
2. Invalid lease returns conflict or unauthorized
3. Cancel signal delivery

---

### B4: Internal worker phase endpoint
Type: internal API

Scope:
1. Implement `POST /internal/builds/worker/phase`.
2. Record phase events with monotonic phase progression checks.
3. Map failed phase to build terminal status when appropriate.

Acceptance:
1. Out-of-order phase updates are rejected.
2. Duplicate phase updates are idempotent.

Tests:
1. Monotonic phase enforcement
2. Duplicate phase update behavior
3. Failure mapping to terminal build status

---

### B5: Internal worker logs endpoint
Type: internal API

Scope:
1. Implement `POST /internal/builds/worker/logs`.
2. Persist bounded chunks and redact secret patterns.

Acceptance:
1. Log chunks stream and persist.
2. Known secret patterns are redacted before persistence/display.

Tests:
1. Chunk persistence
2. Sequence ordering enforcement
3. Redaction behavior

---

### B6: Internal worker completion endpoint
Type: internal API

Scope:
1. Implement `POST /internal/builds/worker/complete`.
2. Finalize build status and artifact reference.
3. Record audit events for success or failure.

Acceptance:
1. Success requires artifact reference.
2. Failure requires failure code and message.
3. Completion is idempotent by build and lease.

Tests:
1. Success completion path
2. Failure completion path
3. Duplicate completion idempotency

---

### B7: Build cancellation endpoint
Type: app-facing controller plus service

Scope:
1. Add endpoint for user cancellation.
2. Mark cancel request to be consumed by heartbeat flow.

Acceptance:
1. Running builds can be canceled.
2. Worker receives cancellation signal at next heartbeat.

Tests:
1. Cancel request success and forbidden paths
2. Cancel flag reflected in heartbeat response

## Stream C: Worker Runtime and Executor Adapter

### C1: Docker host executor adapter
Type: backend adapter

Scope:
1. Implement `Builds::ExecutionAdapters::DockerHostExecutor`.
2. Consume claim payload and run phases in order:
   - lint
   - tests
   - image_build
3. Send phase, log, heartbeat, and completion callbacks.

Acceptance:
1. Worker executes phases in strict order.
2. Phase and log callbacks conform to protocol.
3. Completion includes immutable artifact reference on success.

Tests:
1. Adapter unit tests with callback mocks
2. Phase-order enforcement tests
3. Failure mapping tests

---

### C2: Worker lease management loop
Type: worker runtime

Scope:
1. Implement heartbeat renewal loop while build is active.
2. Handle lease loss and stop processing safely.
3. Respect cancel_requested signal.

Acceptance:
1. Heartbeat cadence prevents lease expiry under normal conditions.
2. Lease loss terminates worker execution and reports proper failure.

Tests:
1. Lease renewal behavior
2. Lease expiry handling
3. Cancellation handling

---

### C3: Build log streaming client
Type: worker runtime

Scope:
1. Stream stdout and stderr as chunked sequences.
2. Retry transient callback failures with bounded backoff.

Acceptance:
1. Logs are delivered in order.
2. Retries do not duplicate visible logs due to idempotent server behavior.

Tests:
1. Ordered chunk sending
2. Retry behavior
3. Graceful handling of callback errors

## Stream D: UI and Product Behavior

### D1: Build trigger and status UI
Type: frontend plus controller

Scope:
1. Add build trigger action on application page.
2. Add build status badge and timeline view.
3. Show phase-level status and user-readable errors.

Acceptance:
1. User can trigger and view build progress.
2. Terminal status and artifact reference are visible.

Tests:
1. Request/system tests for trigger and rendering
2. Status rendering tests

---

### D2: Build logs viewer
Type: frontend plus backend query API

Scope:
1. Show streamed build logs by phase.
2. Redact sensitive values in display path.

Acceptance:
1. Logs are viewable near-real-time and after completion.
2. Sensitive values are not displayed.

Tests:
1. Request/system tests for log retrieval and rendering
2. Redaction output tests

## Security and Audit Tickets

### S1: Internal endpoint authentication
Type: security backend

Scope:
1. Add worker auth middleware for internal endpoints.
2. Validate signed token, worker identity, and expiry.

Acceptance:
1. Unauthorized callbacks are rejected.
2. Authenticated worker requests succeed.

Tests:
1. Auth success and failure paths
2. Expired token handling

---

### S2: Audit events for build lifecycle
Type: backend service integration

Scope:
1. Emit events for:
   - build.requested
   - build.started
   - build.failed
   - build.succeeded
   - build.canceled

Acceptance:
1. Events are emitted once per lifecycle edge.
2. Event metadata excludes secret values.

Tests:
1. Event emission coverage for each lifecycle edge
2. Secret exclusion tests

## Integration and Hardening

### I1: End-to-end integration test for successful build
Type: integration test

Scope:
1. Simulate worker claim through completion success.
2. Validate status progression and artifact capture.

Acceptance:
1. Full happy path passes with stable statuses.

---

### I2: End-to-end integration test for failures
Type: integration test

Scope:
1. Simulate lint failure, test failure, image failure.
2. Validate terminal status mapping and user-facing messaging.

Acceptance:
1. Each failure maps to expected terminal state.

---

### I3: Idempotency and retry test suite
Type: integration test

Scope:
1. Duplicate phase and completion callbacks.
2. Late callback after lease replacement.

Acceptance:
1. Duplicate and late callbacks do not corrupt build state.

## Suggested Milestones

### Milestone 1: Domain and protocol foundation
Tickets: A1, A2, B2, B3

Deliverable:
1. Claim and lease behavior with persistent build state.

### Milestone 2: Worker reporting and completion
Tickets: A3, B4, B5, B6, C2, C3

Deliverable:
1. End-to-end worker reporting pipeline.

### Milestone 3: Docker host execution MVP
Tickets: B1, C1, D1, D2, S1, S2, I1, I2, I3

Deliverable:
1. User-triggered build with quality gates, logs, terminal statuses, and artifact output.

## Risks and Mitigations
1. Risk: log volume impacts storage and UI latency
   - Mitigation: chunk size limits, retention policy, pagination
2. Risk: lease race conditions
   - Mitigation: strict lease ID checks and idempotency keys
3. Risk: secret leaks in logs
   - Mitigation: server-side redaction before persistence and display
4. Risk: Docker host saturation
   - Mitigation: configurable parallel limits and queue backpressure

## Definition of Done (MVP)
1. Authorized user can trigger build from app UI.
2. Build runs lint, tests, then image build in strict order.
3. Worker callbacks update build status and logs reliably.
4. Successful build stores immutable artifact reference.
5. Failures map to app-facing statuses and messages.
6. Audit events exist for all lifecycle transitions.
7. Security tests confirm no plaintext secret exposure in events/logs.
