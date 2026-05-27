# Follow-up Work
- Implement Authentication::Providers::LdapProvider in MVP+ with secure bind/config handling.
- Implement Authentication::Providers::OidcProvider with callback/state/nonce validation.
- Add install-level auth mode management UI/settings (operator-only).
- Add account-linking policies and provisioning strategy for external identities.

- Add repository discovery adapters for GitHub and Bitbucket to match current provider set.
- Add pagination/search for large repository lists.
- Expand provider-specific error mapping for richer inline troubleshooting hints.

- Build pipeline architecture:
	- Keep Runway as build orchestration control plane (build lifecycle, quality gates, logs, audit, artifact metadata).
	- MVP default: out-of-the-box isolated executor using runtime-versioned ephemeral builder images (lint/syntax -> unit tests -> image build).
	- Future feature: delegated executor integration adapters for Jenkins and Argo Workflows while preserving the same Runway build model and UI.
	- Maintain a pluggable execution adapter boundary so internal and delegated executors can coexist without changing app-facing workflow.