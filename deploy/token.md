# Runway Kubernetes Credential Guide (Admin)

This guide documents the credential requirements for installing and running Runway against a Kubernetes backend.

## Required Values in Runway Backend Config

- Kubernetes API endpoint (HTTPS)
- Service account token
- CA bundle for the Kubernetes API certificate chain

## Required Permissions

Runway validation currently checks:

- `GET /version`
- `GET /api/v1/namespaces?limit=1`

Minimum RBAC to pass those checks:

- non-resource URL `/version` with verb `get`
- resource `namespaces` with verb `list`

For MVP operations, Runway uses cluster-wide management access (cluster-admin).

## Apply RBAC (Minimal Validation)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rails-cluster-manager
  namespace: rails-integration-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: runway-validation-minimal
rules:
  - nonResourceURLs: ["/version"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: runway-validation-minimal-binding
subjects:
  - kind: ServiceAccount
    name: rails-cluster-manager
    namespace: rails-integration-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: runway-validation-minimal
```

## Apply RBAC (MVP Runway Operation)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rails-cluster-manager
  namespace: rails-integration-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: runway-mvp-cluster-admin
subjects:
  - kind: ServiceAccount
    name: rails-cluster-manager
    namespace: rails-integration-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
```

## Generate Token

```bash
kubectl -n rails-integration-system create token rails-cluster-manager --duration=24h
```

## Verify Permissions

```bash
kubectl auth can-i --as=system:serviceaccount:rails-integration-system:rails-cluster-manager get --raw /version
kubectl auth can-i --as=system:serviceaccount:rails-integration-system:rails-cluster-manager list namespaces
```

## Notes

- For current MVP, Runway stores token and CA bundle in MySQL.
- Future Vault integration can replace database-backed secret storage.