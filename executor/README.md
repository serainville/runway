# Runway Executor

Standalone Ruby (non-Rails) service for build execution.

Purpose:
- Accept build commands.
- Execute build phase through an adapter.
- Publish step and terminal callbacks.

Current maturity:
- Local and non-production scaffold with queue, state transitions, callback signing, and Docker adapter safe mode.

## What works today

- Executor HTTP API:
	- POST /v1/build-commands
	- GET /v1/build-commands/:command_id
	- GET /healthz
	- GET /readyz
- HMAC-signed command ingestion.
- In-memory queue with state transitions: queued -> running -> completed or failed.
- Callback publishing with schema validation and retry/backoff.
- Docker adapter:
	- Safe mode default (no local command execution).
	- Optional local command execution mode for controlled non-production testing.

## Run locally

1. Start Runway server (separate terminal)

```bash
cd /Users/srainville/Projects/Runway
bin/rails server -p 3000
```

2. Configure executor environment

```bash
cd /Users/srainville/Projects/Runway/executor
cp .env.example .env
```

Set required values in .env:
- EXECUTOR_SIGNING_KEY_ID
- EXECUTOR_SIGNING_SECRET
- RUNWAY_CALLBACK_BASE_URL
- EXECUTOR_REGISTRATION_NAME
- EXECUTOR_REGISTRATION_ENDPOINT

Optional Docker execution values:
- EXECUTOR_ENABLE_DOCKER_LOCAL_COMMANDS=false
- EXECUTOR_DOCKER_DEFAULT_TIMEOUT_SECONDS=900
- EXECUTOR_DOCKER_WORKDIR=/tmp/runway-executor
- EXECUTOR_KEEP_WORKSPACE=false

The executor clones the application source into a per-build subdirectory under `EXECUTOR_DOCKER_WORKDIR` before running the build step.
Set `EXECUTOR_KEEP_WORKSPACE=true` to keep the workspace after execution for debugging.

Build output behavior:
- Docker BuildKit stdout/stderr is captured by the executor and sent in `step.updated` callback `logs` entries.
- Runway persists those entries as build log chunks and shows them in the Build details page under Build Logs.

Heartbeat values:
- EXECUTOR_HEARTBEAT_ENABLED=true
- EXECUTOR_HEARTBEAT_INTERVAL_SECONDS=30

3. Start executor API

```bash
cd /Users/srainville/Projects/Runway/executor
bundle install
bundle exec ruby bin/server
```

The executor loads `.env` automatically at startup, so manual `source .env` is no longer required.

On startup, executor logs registration identity for heartbeat mapping:
- `[executor] startup EXECUTOR_REGISTRATION_NAME=...`
- `[executor] startup EXECUTOR_REGISTRATION_ENDPOINT=...`

4. Health check

```bash
curl -sS http://127.0.0.1:4100/healthz
curl -sS http://127.0.0.1:4100/readyz
```

## Submit a signed build command

Create a sample payload file:

```bash
cat > /tmp/build-command.json <<'JSON'
{
	"command_id": "cmd_local_001",
	"build_id": 101,
	"attempt": 1,
	"tenant": { "id": "tenant-nonp", "project_id": 1, "application_id": 1 },
	"source": {
		"provider": "gitlab",
		"repo_url": "https://gitlab.example.com/team/app.git",
		"commit_sha": "abc123def456",
		"ref": "refs/heads/main"
	},
	"runtime": { "name": "ruby", "version": "3.3" },
	"builder": {
		"image": "registry.example.com/runway/executor-builder:ruby-3.3-v1",
		"pull_policy": "IfNotPresent"
	},
	"steps": [
		{ "name": "build", "command": ["echo", "build"], "timeout_seconds": 60 }
	],
	"artifact": { "registry": "nexus", "repository": "apps/team/app", "tag": "sha-abc123" },
	"callback": {
		"url": "http://127.0.0.1:3000/internal/build-executor/callbacks",
		"auth": { "scheme": "hmac", "key_id": "exec-key-1" }
	}
}
JSON
```

Generate signature and submit:

```bash
cd /Users/srainville/Projects/Runway/executor
set -a; source .env; set +a

ts="$(date +%s)"
body="$(cat /tmp/build-command.json)"
sig="$(ruby -ropenssl -e 'ts=ARGV[0]; body=ARGV[1]; secret=ENV.fetch("EXECUTOR_SIGNING_SECRET"); print OpenSSL::HMAC.hexdigest("SHA256", secret, "#{ts}.#{body}")' "$ts" "$body")"

curl -sS -X POST http://127.0.0.1:4100/v1/build-commands \
	-H "Content-Type: application/json" \
	-H "X-Runway-Key-Id: ${EXECUTOR_SIGNING_KEY_ID}" \
	-H "X-Runway-Timestamp: ${ts}" \
	-H "X-Runway-Signature: sha256=${sig}" \
	--data "$body"
```

Check command status:

```bash
curl -sS http://127.0.0.1:4100/v1/build-commands/cmd_local_001
```

## Connect it to Runway server

Use this for local connection settings:
- RUNWAY_CALLBACK_BASE_URL=http://127.0.0.1:3000
- Ensure Runway is reachable from executor host.

Important integration note:
- Current Runway server in this repository exposes worker-protocol endpoints under:
	- /internal/builds/worker/claim
	- /internal/builds/worker/heartbeat
	- /internal/builds/worker/phase
	- /internal/builds/worker/logs
	- /internal/builds/worker/complete
- Runway now also accepts executor command-mode callbacks at:
	- /internal/build-executor/callbacks
- Current executor command mode uses:
	- POST /v1/build-commands and callback publishing to /internal/build-executor/callbacks.

To secure callback ingestion, set these Runway env vars:
1. RUNWAY_EXECUTOR_CALLBACK_SIGNING_KEY_ID
2. RUNWAY_EXECUTOR_CALLBACK_SIGNING_SECRET

Keep executor callback signing aligned with those values:
1. EXECUTOR_CALLBACK_SIGNING_KEY_ID
2. EXECUTOR_CALLBACK_SIGNING_SECRET

Default executor behavior in Runway admin:
1. Register integrations in Admin > Build Integrations.
2. Mark one integration as Default executor.
3. Runway dispatch uses the default integration when it is active and validated.
4. The selected integration is persisted on each build record for traceability.

Executor heartbeat behavior in Runway admin:
1. Register executor entries under Build settings > Executor registrations.
2. Set `EXECUTOR_REGISTRATION_NAME` (or matching endpoint) so heartbeats map to the correct registration.
3. Executor sends periodic signed heartbeats to `/internal/build-executor/heartbeats`.
4. Registration status shows:
	- Online: green circle icon
	- Offline: red circle icon
	- Unknown: warning icon

Remaining full direct wiring step:
1. Add a bridge adapter that translates Runway worker-protocol jobs into executor command submissions and maps callback events back into worker endpoints.

## Local non-production test mode

Default is safe mode (recommended while integrating):
- EXECUTOR_ENABLE_DOCKER_LOCAL_COMMANDS=false

To allow local command execution for step commands:
- EXECUTOR_ENABLE_DOCKER_LOCAL_COMMANDS=true

Use only in controlled non-production environments.

## Related docs

- /Users/srainville/Projects/Runway/docs/executor/contracts/build-command.schema.json
- /Users/srainville/Projects/Runway/docs/executor/contracts/build-callback.schema.json
- /Users/srainville/Projects/Runway/docs/BUILD_EXECUTOR_OPERATOR_CONFIG.md
- /Users/srainville/Projects/Runway/docs/BUILD_WORKER_PROTOCOL.md
