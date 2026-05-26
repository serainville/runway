# Deployment Model

## MVP deployment path

```text
Runway Rails Control Plane
  -> Kubernetes API
  -> Tenant nonp cluster
```

## Generated resources

For each app environment, Runway may generate:

- Namespace
- ServiceAccount
- ExternalSecret
- Deployment
- Service
- Istio VirtualService
- release-command Job

## Release command

For Rails apps, Runway can run:

```bash
bin/rails db:migrate
```

The release command must succeed before the web process rollout proceeds.

## Rollback

Rollback creates a new Deployment that references a previous Release.

Runway does not attempt database rollback.
