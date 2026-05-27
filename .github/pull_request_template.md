## Summary

Describe the change and why it is needed.

## Related issue

Link the related issue(s), if any.

## What changed

- 

## Validation

- [ ] `bin/rails test`
- [ ] Manual validation completed (describe below)

## Manual test notes

Describe how reviewers can verify behavior.

## Guardrails checklist

- [ ] User-facing behavior remains app-centric
- [ ] Kubernetes implementation details are not exposed in golden path UX
- [ ] External integrations use adapter/service classes
- [ ] Secret handling follows secure rules (no plaintext persistence/display/logging)
- [ ] Tests cover success and failure paths for new/changed behavior
- [ ] Documentation updated where needed
