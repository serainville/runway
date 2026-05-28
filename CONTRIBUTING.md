# Contributing to Runway

Thanks for your interest in contributing.

Runway is an app-centric deployment control plane. Please keep changes aligned to product guardrails:

- Keep user workflows app-centric.
- Avoid exposing Kubernetes primitives in golden-path UX.
- Preserve immutable release semantics.
- Preserve durable deployment event history.
- Never store or expose secret values in plaintext.

## Development Setup

```bash
bundle install
bin/rails db:prepare
bin/rails test
```

Run locally:

```bash
bin/dev
```

## Branch and Commit Practices

1. Create a focused branch from the main branch.
2. Keep pull requests small and scoped.
3. Write clear commit messages that explain intent.

## Pull Request Expectations

- Add or update tests for behavior changes.
- Cover both success and failure paths where relevant.
- Keep controllers thin and move workflows into service objects.
- Ensure external integrations remain behind adapter/service classes.
- Update documentation when behavior or architecture changes.

## Definition of Done

A change is ready when:

- User-facing behavior remains app-centric.
- Tests pass locally.
- Security constraints for secrets are respected.
- Related docs are updated.

## Reporting Issues

Use the repository issue templates:

- Bug report
- Feature request

Include reproduction steps, expected behavior, and environment details.
