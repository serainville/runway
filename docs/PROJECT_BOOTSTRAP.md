# Project Bootstrap

Milestone 0 establishes the Runway control plane foundation.

## Bootstrap Checklist

- Rails 8.1.3 application initialized
- SQLite configured for local development and test
- MySQL configured for staging and production
- Test framework enabled with Minitest
- Basic public landing page and health endpoint
- CI workflow present with lint and test jobs

## Local Commands

- Install dependencies:

  bundle install

- Prepare local database:

  bin/rails db:prepare

- Run tests:

  bin/rails test

## Environment Database Strategy

- development: SQLite
- test: SQLite
- staging: MySQL
- production: MySQL
