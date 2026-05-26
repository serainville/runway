# MVP Scope

## MVP goal

Runway proves that a developer can deploy a Rails-style web app to the tenant nonp Kubernetes cluster without writing Kubernetes YAML.

## Included

- Rails control plane
- MySQL nonp database
- GitLab repository connection
- Dockerfile-based build path
- Nexus image registry
- Vault-backed config vars
- External Secrets Operator runtime secret sync
- Direct Kubernetes API deployment to tenant nonp
- Istio VirtualService route
- app releases
- deployment events
- rollback
- basic logs
- basic error translation

## Deferred

- Argo CD
- Argo Workflows
- Jenkins
- SonarQube
- Redis
- MinIO
- worker processes
- autoscaling
- tenant prod deployments
- multi-cluster deployment
- full add-on marketplace
