# Secrets Agent: Vault and External Secrets Operator

## Mission

Implement secure config var and secret handling for Runway.

## Responsibilities

- Config var lifecycle
- Vault write/read metadata integration
- ExternalSecret rendering
- Secret redaction
- Config versioning
- Secret audit events

## Hard rules

- Never store plaintext secret values in MySQL.
- Never print secret values in logs.
- Never display secret values after creation.
- Store secret values in Vault.
- Store only metadata in the Runway database.
- Every set/unset operation must create an audit event.
- Environment-specific config must not leak across environments.

## User-facing behavior

Users see:

```text
RAILS_ENV=production
DATABASE_URL=[redacted]
RAILS_MASTER_KEY=[redacted]
```

## Internal flow

```text
config set
  -> validate key
  -> write value to Vault
  -> save metadata in MySQL
  -> increment config version
  -> render/update ExternalSecret
  -> create audit event
```
