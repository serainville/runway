# Executor MVP Backlog

## Metadata

Scale:
- Estimate is in ideal engineering days.
- Dependencies list backlog IDs that must complete first.

## Tickets

| ID | Title | Owner Role | Estimate | Dependencies | Deliverable |
| --- | --- | --- | ---: | --- | --- |
| E1 | Protocol schemas and signing contract | Product Architect + Backend | 2 | - | Finalized JSON schema files and signature header spec |
| E2 | Non-Rails executor skeleton | Backend | 2 | E1 | Runnable service with health routes and request parsing |
| E3 | Command validation and auth middleware | Security + Backend | 2 | E1, E2 | Schema enforcement and HMAC validation on ingress |
| E4 | Docker adapter step runner | Platform | 4 | E2, E3 | Lint/test/build step execution with timeout handling |
| E5 | gcrane artifact service | Platform | 2 | E4 | Artifact build and push result integration |
| E6 | Callback publisher with retries | Backend | 2 | E2, E3 | step.updated and build.completed delivery with idempotency key |
| E7 | Runway dispatch integration service | Rails | 3 | E1 | Builds::DispatchToExecutor service and metadata persistence |
| E8 | Runway callback ingestion endpoint | Rails | 3 | E1, E6 | Internal callback endpoint with idempotent state transitions |
| E9 | Log and phase persistence hardening | Rails | 2 | E8 | Ordered chunk ingestion and dedupe semantics |
| E10 | BuildIntegration settings extension | Rails | 2 | E7 | Executor endpoint/auth/backend mode config and validation |
| E11 | Security redaction and audit events | Security + Rails | 2 | E7, E8 | Redaction tests and lifecycle audit events |
| E12 | Nonp rollout and observability | Platform + SRE | 3 | E4, E5, E8, E11 | Nonp cutover report, metrics dashboard, and runbook |
| E13 | Kubernetes adapter boundary (gated) | Platform | 4 | E4 | Feature-flagged Kubernetes adapter interface and smoke path |

## Suggested Sprint Grouping

Sprint 1:
- E1, E2, E3, E7

Sprint 2:
- E4, E5, E6, E8

Sprint 3:
- E9, E10, E11, E12

Deferred post-MVP gate:
- E13
