# ADR: Build Execution Model for Runway

## Status
Accepted (MVP default + future extension path)

## Date
2026-05-26

## Context
Runway is an app-centric control plane that should provide a reliable out-of-the-box build experience while avoiding runtime dependency conflicts on the Rails server.

If build toolchains are installed directly on the Runway server, the platform will accumulate conflicting runtime versions and become operationally fragile.

Runway must support quality-gated builds:

1. lint or syntax checks
2. unit tests
3. container image creation

Runway should also preserve a future path to delegated execution systems such as Jenkins or Argo Workflows.

## Decision
Runway supports multiple build execution options behind a common execution adapter boundary:

1. MVP default (recommended): internal isolated executor on a Docker host
2. Future feature (not MVP): internal Kubernetes-native executor using scheduled build pods
3. Future feature: delegated executor adapters (Jenkins, Argo Workflows)

### MVP Default: Internal Isolated Executor (Docker Host)
Runway orchestrates builds and executes each build in ephemeral, runtime-versioned builder containers on a configured Docker server (localhost or remote). The Rails app does not host runtime toolchains.

The executor reports phase status and logs back to Runway, and Runway remains the source of truth for build lifecycle and user-facing output.

Per build, Runway executes ordered quality gates:

1. lint or syntax check
2. unit tests
3. container image build and publish

Only successful gate progression produces a deployable artifact reference.

### Future: Internal Kubernetes-Native Executor
When Runway is deployed on Kubernetes, execution may move to scheduled ephemeral build pods instead of Docker host jobs.

This remains an internal Runway executor model (not delegated CI), with the same build domain statuses, quality gates, and UI semantics.

### Future: Delegated Executor Adapters
Runway remains orchestration control plane but delegates execution to external workflow engines through adapters. Build lifecycle, app-facing statuses, and logs remain consistent from Runway UI perspective.

## Rationale
This decision balances product UX, implementation complexity, and operational safety.

1. Out-of-the-box experience: internal isolated executor gives immediate value without requiring external CI platforms.
2. Host safety: toolchains live in builder images, not Rails host.
3. Extensibility: adapter boundary avoids locking into one execution engine.
4. Product consistency: app-facing build model remains stable even when execution backend changes.
5. Deployment fit: Docker host integration provides a fast MVP path, while Kubernetes-native execution is available as a clean post-MVP evolution.

## Consequences

### Positive
1. Predictable build behavior and quality gates for MVP.
2. Reduced runtime/version conflicts on Runway server.
3. Clear migration path to Kubernetes-native execution for Kubernetes installations.
4. Reusable build domain model and UI across both execution options.
5. Clear migration path to delegated execution for organizations with existing Jenkins/Argo standards.

### Trade-offs
1. Additional design effort for adapter contracts and status normalization.
2. Need to maintain executor-specific integrations over time.
3. Operational complexity grows when delegated adapters are introduced.

## Build Domain Contract
The following app-facing pipeline and statuses are executor-agnostic:

Pipeline phases:

1. lint or syntax
2. unit tests
3. image build

Suggested statuses:

1. pending
2. running
3. failed_lint
4. failed_tests
5. failed_image
6. succeeded
7. canceled

A successful build must store an immutable artifact reference (image digest).

## Architecture Boundaries

### Runway Control Plane Responsibilities
1. Authorization and app/project scoping.
2. Build record lifecycle management.
3. Template resolution for runtime/backend.
4. Quality gate policy and phase ordering.
5. Audit events.
6. Build logs and status presentation.
7. Release handoff using immutable artifact references.

### Executor Responsibilities
1. Isolated build environment provisioning.
2. Phase command execution and result capture.
3. Log streaming and final phase results.
4. Artifact build and publish execution.
5. Status and log callbacks to Runway in a normalized format.

## Adapter Strategy
Define a shared interface, for example:

- `Builds::ExecutionAdapters::DockerHostExecutor` (MVP)
- `Builds::ExecutionAdapters::KubernetesPodExecutor` (future, not MVP)
- `Builds::ExecutionAdapters::JenkinsExecutor` (future)
- `Builds::ExecutionAdapters::ArgoWorkflowsExecutor` (future)

All adapters must return normalized phase and status payloads so Runway domain logic remains unchanged.

## Security and Compliance
1. No plaintext secret persistence in MySQL for build credentials.
2. Secret resolution through approved secret backend patterns.
3. Secret redaction in logs, events, and UI.
4. Strict project isolation for build context, logs, and artifacts.
5. Audit events for build requested, started, failed, and succeeded.

## Rollout Plan

### Phase 1 (MVP)
1. Build domain model and status lifecycle.
2. Docker host executor adapter with support for localhost or remote Docker server.
3. Runtime template mapping for lint or syntax, unit tests, image build.
4. UI build trigger and status/log views.

### Phase 2 (Future)
1. Kubernetes-native pod executor adapter for installations running on Kubernetes.
2. Operator configuration for choosing Docker host executor or Kubernetes pod executor.

### Phase 3 (Future)
1. Delegated adapter contract hardening.
2. Jenkins executor adapter.
3. Argo Workflows executor adapter.
4. Operator configuration for executor selection and policy.

## Decision Triggers for Delegated Execution
Adopt delegated execution when one or more of the following become true:

1. Organization already operates Jenkins/Argo with strong governance requirements.
2. Build volume or specialization exceeds internal executor operational envelope.
3. Compliance requires centralized workflow controls beyond Runway internal execution.
4. Multi-team policy management is better handled by enterprise CI workflow systems.

## Open Questions
1. Should executor selection be global, project-level, or app-level policy?
2. Should delegated adapters be feature-flagged by install mode?
3. What minimum normalized log and phase schema is required across all adapters?

## Related Document
Operator-facing executor configuration details are defined in `docs/BUILD_EXECUTOR_OPERATOR_CONFIG.md`.
