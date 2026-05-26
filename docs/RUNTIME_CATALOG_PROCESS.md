# Runtime Catalog Process

Runway treats runtime support as release-managed product data.

Runtime catalog entries are defined in code in app/services/runtimes/catalog.rb.

## Current Supported Runtimes

- Ruby 4 (`ruby-4`)
- Rails 8 (`rails-8`)
- Go 1.22 (`go-1.22`)

## Process To Add New Runtime Support

1. Add a new catalog item in `Runtimes::Catalog::SUPPORTED` with a stable key.
2. Add or update tests in:
   - `test/services/runtimes/catalog_test.rb`
   - `test/services/runtimes/list_supported_options_test.rb`
   - app creation flow tests that verify runtime selection.
3. Update user-facing docs (README runtime section).
4. Include runtime support notes in the release changelog.
5. Ship via normal Runway release process.

## Important Rules

- Do not add live UI or admin mutation APIs for runtime catalog updates.
- Keep runtime keys stable for backward compatibility.
- Do not expose unsupported runtimes in app creation forms.
