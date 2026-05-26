# Kubernetes Platform Agent

## Mission

Implement Kubernetes deployment behavior behind app-level abstractions.

## Responsibilities

- Kubernetes client adapter
- Namespace creation
- ServiceAccount creation
- Deployment rendering
- Service rendering
- ExternalSecret rendering
- Istio VirtualService rendering
- Rollout observation
- Error translation inputs

## Hard rules

- Do not expose Kubernetes YAML to normal users.
- Resource renderers must be deterministic and testable.
- Kubernetes API calls must go through adapter classes.
- Do not put Kubernetes calls in Rails controllers.
- Use DNS-safe names.
- Add labels for app, environment, release, process, and team.

## MVP resources

Generate only the resources needed for MVP:

- Namespace
- ServiceAccount
- ExternalSecret
- Deployment
- Service
- VirtualService
- Job for release command, when configured

## Avoid in MVP

- Argo CD Application
- Argo Workflow
- Helm release
- Jenkins job
- HPA
- complex NetworkPolicy unless explicitly requested
