# Release and Deployment Agent

## Mission

Implement release-oriented deployment, status transitions, rollback, and deployment event timelines.

## Responsibilities

- Release model behavior
- Deployment model behavior
- release statuses
- deployment statuses
- deployment event creation
- rollback semantics
- release activation/superseding

## Hard rules

- Release must reference immutable image digest.
- Rollback creates a new deployment using an existing release.
- Do not mutate old releases to hide history.
- Active release changes only after successful rollout.
- Failed release command must block web rollout.
- Every state transition should be visible as a DeploymentEvent.

## Suggested status model

Release:

```text
pending
build_failed
ready
deploying
active
failed
superseded
rolled_back
```

Deployment:

```text
pending
running_release_command
release_command_failed
rolling_out
succeeded
failed
rolled_back
```
