# Build Executor Operator Configuration

## Purpose
This document defines the operator-facing configuration contract for build execution in Runway.

Runway remains the build orchestration control plane. Executors perform build work and report normalized phase status and logs back to Runway.

Supported execution targets:

1. Docker host executor (MVP default)
2. Kubernetes pod executor (future, not MVP)
3. Delegated executors (future): Jenkins and Argo Workflows

## Configuration Model
Configuration is split into:

1. Global executor policy
2. Per-executor backend settings
3. Security and secret references

Runway should reject startup or configuration apply when required fields for the selected default executor are missing.

## Global Executor Policy

### Required Fields
1. `build_executor.default`
   - Allowed values: `docker_host`, `kubernetes_pod`, `jenkins`, `argo_workflows`
   - MVP constraint: must be `docker_host`
2. `build_executor.fallback_enabled`
   - Allowed values: `true` or `false`
   - MVP recommendation: `false`

### Optional Fields
1. `build_executor.allow_per_project_override`
   - Allowed values: `true` or `false`
   - MVP recommendation: `false`
2. `build_executor.allowed_executors`
   - List of allowed executors in this installation
   - MVP recommendation: only `docker_host`

## Docker Host Executor (MVP)

### Required Fields
1. `build_executor.docker_host.endpoint`
   - Example: `unix:///var/run/docker.sock` or `tcp://docker-build.local:2376`
2. `build_executor.docker_host.connection_mode`
   - Allowed values: `local_socket`, `remote_tcp_tls`

### Required Fields for `remote_tcp_tls`
1. `build_executor.docker_host.tls.client_cert_ref`
2. `build_executor.docker_host.tls.client_key_ref`
3. `build_executor.docker_host.tls.ca_cert_ref`

All `*_ref` values are secret references, not plaintext secrets.

### Recommended Fields
1. `build_executor.docker_host.max_parallel_builds`
2. `build_executor.docker_host.default_timeout_seconds`
3. `build_executor.docker_host.network_policy`
4. `build_executor.docker_host.allowed_builder_images`
5. `build_executor.docker_host.default_builder_image_by_runtime`

### Operational Notes
1. Use runtime-versioned builder images to avoid dependency conflicts.
2. Do not install language toolchains on the Rails server.
3. Enforce immutable artifact tagging and digest capture.

## Kubernetes Pod Executor (Future)

### Required Fields
1. `build_executor.kubernetes_pod.namespace`
2. `build_executor.kubernetes_pod.service_account_ref`
3. `build_executor.kubernetes_pod.image_pull_secret_ref`
4. `build_executor.kubernetes_pod.default_builder_image_by_runtime`

### Recommended Fields
1. `build_executor.kubernetes_pod.max_parallel_builds`
2. `build_executor.kubernetes_pod.node_selector`
3. `build_executor.kubernetes_pod.tolerations`
4. `build_executor.kubernetes_pod.default_cpu_request`
5. `build_executor.kubernetes_pod.default_memory_request`
6. `build_executor.kubernetes_pod.default_timeout_seconds`

### Operational Notes
1. Build pods must be ephemeral and isolated per build.
2. Build logs and status callbacks must use the same normalized format as Docker host executor.
3. This executor is not MVP.

## Delegated Executors (Future)

### Jenkins
Required fields:

1. `build_executor.jenkins.base_url`
2. `build_executor.jenkins.credential_ref`
3. `build_executor.jenkins.job_template`

### Argo Workflows
Required fields:

1. `build_executor.argo_workflows.base_url` or in-cluster endpoint reference
2. `build_executor.argo_workflows.credential_ref`
3. `build_executor.argo_workflows.workflow_template`

### Operational Notes
1. Delegated executors must map external statuses to Runway build statuses.
2. Delegated executors are future scope, not MVP.

## Secrets and Security Contract
1. MySQL stores only metadata and secret references.
2. Secret values are resolved through approved secret backend adapters.
3. Logs must redact tokens, keys, and registry credentials.
4. Executor callbacks must be authenticated and scoped to build ID and project boundary.
5. Every build state mutation must produce an audit event.

## Normalized Callback Contract
Executors must report status using a normalized payload shape.

Detailed request and lifecycle protocol is documented in `docs/BUILD_WORKER_PROTOCOL.md`.
Implementation ticket breakdown is documented in `docs/BUILD_IMPLEMENTATION_TICKETS.md`.

### Required Fields
1. `build_id`
2. `phase`
   - Allowed values: `lint`, `tests`, `image_build`
3. `status`
   - Allowed values: `running`, `succeeded`, `failed`
4. `timestamp`
5. `message`

### Optional Fields
1. `log_chunk`
2. `artifact_reference`
   - Required when final status is success
3. `failure_code`

## Validation Rules
1. Default executor must be in allowed executors list.
2. Required fields for selected default executor must be present.
3. Secret references must be syntactically valid and resolvable.
4. Unsupported executor selection in MVP must fail with actionable operator error.

## MVP Baseline Profile
For MVP installations, use this profile:

1. `build_executor.default: docker_host`
2. `build_executor.allowed_executors: [docker_host]`
3. `build_executor.allow_per_project_override: false`
4. `build_executor.fallback_enabled: false`

## Future Extension Path
1. Add Kubernetes pod executor when Runway deployment target is Kubernetes.
2. Add delegated Jenkins or Argo adapters when organizational policy requires external workflow engines.
3. Keep the same app-facing build lifecycle and status model across all executors.
