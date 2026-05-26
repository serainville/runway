# Admin Console

Runway provides an admin-only console for platform operations.

## Capabilities

- Manage users and role assignments.
- Reset user passwords as an admin.
- Manage projects and project application metadata.
- Create global repository connection endpoints and auth for app source selection.
- Configure backend deployment targets.

## Backend Setup

Backend setup supports:

- Kubernetes backend targets
- Docker backend targets (scaffolded)

Multiple backend targets can be registered. Environments reference deployment targets to determine where application deployments run.

### Kubernetes Backend Requirements (MVP)

To validate a Kubernetes backend target, admins must provide:

- Kubernetes API endpoint (must be `https://...`)
- Kubernetes service account token
- Kubernetes CA bundle used to trust the API certificate

Runway validates connectivity using:

- `GET /version`
- `GET /api/v1/namespaces?limit=1`

The service account token must allow:

- `get` on non-resource URL `/version`
- `list` on core resource `namespaces`

For now, Runway stores token and CA bundle values in the database for Kubernetes backend configuration.
Vault integration for these values is planned as a future admin-enabled integration.

For MVP, the token must be granted cluster-wide permissions required by Runway to manage all resources in the tenant cluster.

### Kubernetes Token Acquisition Process (MVP)

1. Create a dedicated service account for Runway in the target cluster.
2. Bind the account to a cluster-wide privileged role for MVP operations.
3. Generate a token for that service account according to your cluster version.
4. Paste the token and CA bundle into the backend target configuration form.
5. Use Validate in Admin Backend Setup to confirm API reachability and permissions.

### Kubernetes RBAC Requirements

#### Option A: Minimum permissions to pass Runway validation checks

Use this for initial connectivity validation only.

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

#### Option B: MVP operational permissions for Runway cluster management

Use this for MVP runtime operation where Runway needs cluster-wide management access.

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

### Generate and Verify Token

Generate token:

`kubectl -n rails-integration-system create token rails-cluster-manager --duration=24h`

Verification checks:

- `kubectl auth can-i --as=system:serviceaccount:rails-integration-system:rails-cluster-manager get --raw /version`
- `kubectl auth can-i --as=system:serviceaccount:rails-integration-system:rails-cluster-manager list namespaces`

## Security

- Only users with the `admin` role can access admin console pages.
- For current MVP, Kubernetes backend token and CA bundle are stored in MySQL and should be treated as sensitive operational secrets.
- Vault-backed storage for backend credentials is planned as a future optional integration.
- Admin mutations create audit events.

## Default Admin Password

To set or reset the default admin password via seeds:

- `RUNWAY_DEFAULT_ADMIN_EMAIL` (optional, defaults to `admin@runway.local`)
- `RUNWAY_DEFAULT_ADMIN_NAME` (optional)
- `RUNWAY_DEFAULT_ADMIN_USERNAME` (optional, defaults to `admin`)
- `RUNWAY_DEFAULT_ADMIN_PASSWORD` (optional; random password generated if omitted)

Example:

`RUNWAY_DEFAULT_ADMIN_EMAIL=admin@example.com RUNWAY_DEFAULT_ADMIN_PASSWORD='new-strong-password' bin/rails db:seed`

When seed runs, Runway prints the default admin username and the applied password to console.
If `RUNWAY_DEFAULT_ADMIN_PASSWORD` is omitted, a random password is generated and applied.

## Tenant Experience

Tenant-facing workflows remain app-centric and do not expose infrastructure primitives in normal UX.
