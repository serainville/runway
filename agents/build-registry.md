# Build and Registry Agent

## Mission

Implement the source-to-image path with minimal MVP dependencies.

## Responsibilities

- GitLab repository connection
- GitLab webhook handling
- build records
- build log capture
- BuildKit job interface
- Nexus registry push metadata
- image digest capture
- release creation from build output

## MVP build rule

For the first build milestone, prefer Dockerfile-based builds. Buildpack detection can be added later.

## Hard rules

- Do not use Argo Workflows for MVP unless explicitly requested.
- Do not use Jenkins for MVP unless explicitly requested.
- Do not create a release from a failed build.
- Store immutable image digest.
- Do not deploy mutable `latest` tags.

## Build flow

```text
GitLab source
  -> Build record
  -> Build job
  -> Image pushed to Nexus
  -> Image digest captured
  -> Release created
```
