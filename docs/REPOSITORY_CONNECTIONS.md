# Repository Connections

Runway supports reusable repository connections at two scopes:

- Global repository connections managed by platform admins
- Project repository connections managed by project owners

Repository connections store only the endpoint and authentication needed to reach a source control host. The application record stores the concrete repository URL that Runway clones.

## Global Repository Connections

Admins can create shared repository connections from the admin area. These connections are available to all projects when creating apps.

Required fields:

- Connection name
- Provider
- Repository endpoint URL
- Auth username
- Auth secret
- Optional CA bundle (PEM) for private or self-signed certificate chains

When a global repository connection is created, Runway stores it with a `pending` validation state.
Admins can run endpoint validation from the repository connection screen. If TLS validation fails for a private CA, provide the connection-specific CA bundle and validate again.

## Project Repository Connections

Project owners can create repository connections scoped to their own project. These connections are only available within that project.

Project-scoped repository connections use the same required fields and validation behavior as global connections.

## App Creation

When creating an app, the user provides:

- A repository connection
- A repository source choice:
	- Enter repository URL
	- Select from available repositories

Runway shows a drop-down of available repository connections:

- Global connections labeled `Global: ...`
- Project-local connections labeled `Project: ...`

When a user chooses `Select from available repositories`, Runway loads repository options that the selected connection can access.

When a user enters a repository URL or selects a repository, Runway can verify repository access and shows status inline:

- Green check icon when access is verified
- Warning or error icon with a troubleshooting message when verification fails

If the user does not explicitly choose a connection, Runway derives one from the repository URL only when exactly one available connection has an endpoint that matches the repository URL prefix.

## Security Notes

- Repository auth secrets are not stored in plaintext.
- Runway stores encrypted repository auth for reusable connections.
- Audit events do not include raw auth values.

## Verification Behavior

Runway verifies repository access by checking that:

- The repository endpoint URL is valid
- The repository URL is valid
- The repository URL matches the selected connection endpoint
- The credentials can authenticate to the remote repository

If verification fails, the application is not created.