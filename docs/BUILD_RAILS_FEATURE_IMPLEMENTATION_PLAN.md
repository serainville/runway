# Rails Feature Implementation

## Implementation Plan

### Feature Slice
Build execution MVP foundation for Runway control plane:

1. Build domain persistence and lifecycle statuses
2. Internal worker protocol endpoints (claim, heartbeat, phase, logs, complete)
3. Build start action from application context
4. Docker host executor integration point (adapter boundary only in this slice)

### Models To Create or Change
1. Create `Build`
   - Associations: belongs_to `Application`, has_many `AuditEvent` (as auditable), optional has_many phase/log records
   - Statuses: `pending`, `running`, `failed_lint`, `failed_tests`, `failed_image`, `succeeded`, `canceled`
   - Core fields: `runtime_key`, `source_ref`, `commit_sha`, `artifact_reference`, `lease_id`, `worker_id`, `retry_count`, `failure_code`, `error_summary`, `started_at`, `finished_at`
2. Create `BuildPhaseEvent`
   - Tracks phase transitions and messages
3. Create `BuildLogChunk`
   - Tracks ordered log chunks per build and phase
4. Change `Application`
   - Add `has_many :builds` association

### Migrations Required
1. Create `builds` table
   - Include not-null fields for state and ownership
   - Add indexes: `(application_id, created_at)`, `(status)`, `(lease_id)`
2. Create `build_phase_events` table
   - Include build foreign key and phase/status fields
3. Create `build_log_chunks` table
   - Include build foreign key, phase, sequence, chunk text
   - Unique index on `(build_id, phase, sequence)` for idempotency

### Controllers and Routes To Create or Change
1. Change `ProjectApplicationsController`
   - Add app-facing `start_build` action
   - Keep thin: delegate to service
2. Create `Internal::Builds::WorkerController`
   - Endpoints under `/internal/builds/worker`:
     - `POST claim`
     - `POST heartbeat`
     - `POST phase`
     - `POST logs`
     - `POST complete`
3. Change routes in `config/routes.rb`
   - Add project application build start route
   - Add internal worker routes namespace

### Service Objects To Create or Change
1. `Applications::StartBuild`
   - Authorize actor
   - Create build record
   - Record audit event
   - Enqueue execution orchestration
2. `Builds::ClaimNextBuild`
   - Claim pending build by capability and assign lease
3. `Builds::HeartbeatLease`
   - Renew lease and return cancel signal
4. `Builds::RecordPhase`
   - Enforce monotonic phase order
5. `Builds::AppendLogChunk`
   - Enforce ordered sequence and redact known sensitive patterns
6. `Builds::Complete`
   - Finalize terminal state and artifact reference checks
7. `Builds::TransitionStatus`
   - Centralized lifecycle validation
8. `Builds::ExecutionAdapters::DockerHostExecutor`
   - Placeholder interface and no-op/test implementation for initial integration

### Policies and Authorization Checks
1. App-facing build start requires project membership for current user.
2. Internal worker endpoints require worker credential authentication and scope validation.
3. Every state mutation checks build ownership scope and valid lease where applicable.

### Tests To Add or Update
#### Models
1. `Build` validations, associations, and status inclusion
2. `BuildPhaseEvent` phase/status validation
3. `BuildLogChunk` sequence uniqueness and bounds

#### Services
1. `Applications::StartBuild`
   - happy path
   - authorization failure
   - validation failure
   - audit event creation
2. `Builds::TransitionStatus`
   - valid transitions
   - invalid transitions
   - idempotency on duplicate terminal updates
3. `Builds::ClaimNextBuild`, `Builds::HeartbeatLease`, `Builds::RecordPhase`, `Builds::AppendLogChunk`, `Builds::Complete`
   - happy and failure paths
   - lease and sequence conflict behavior

#### Controllers/Requests
1. `ProjectApplicationsController` `start_build`
   - authenticated success
   - unauthenticated redirect/failure
   - unauthorized forbidden
2. Internal worker endpoints
   - auth success/failure
   - valid payload path
   - invalid payload and conflict path

#### Security
1. Secret values are redacted in persisted logs and response payloads.
2. No plaintext secret fields written to DB for worker credentials.

### Docs To Update
1. `docs/BUILD_IMPLEMENTATION_TICKETS.md`
   - Mark this as active first slice
2. `docs/BUILD_WORKER_PROTOCOL.md`
   - Add any finalized payload fields from implementation
3. `docs/BUILD_EXECUTOR_OPERATOR_CONFIG.md`
   - Add concrete MVP auth config values for internal worker endpoints

### Risks and Assumptions
1. Assumption: Docker host executor remains MVP default.
2. Risk: lease race conditions can cause duplicate callbacks.
   - Mitigation: strict lease validation and idempotency keys.
3. Risk: log volume and sensitive data leakage.
   - Mitigation: chunk size limits, retention policy, server-side redaction.
4. Risk: status drift between worker and control plane.
   - Mitigation: centralized transition service and protocol-level conflict responses.

## Files Changed
1. `docs/BUILD_RAILS_FEATURE_IMPLEMENTATION_PLAN.md`

## Behavior Added
1. Prepared implementation blueprint for first `/rails-feature` coding slice.

## Tests Added
1. None yet (planning document only).

## Security Notes
1. Plan requires worker endpoint authentication, lease scoping, and log redaction from day one.

## How to Run / Verify
1. Review this plan against:
   - `docs/BUILD_EXECUTION_ADR.md`
   - `docs/BUILD_EXECUTOR_OPERATOR_CONFIG.md`
   - `docs/BUILD_WORKER_PROTOCOL.md`
2. Use as backlog source for coding milestones.

## Follow-up Work
1. After this slice lands, implement Docker host executor runtime loop and end-to-end integration tests.
2. Add UI status timeline and live logs view in the next slice.
