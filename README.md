# Runway

Runway is a Rails-based control plane for an app-centric deployment platform.

## Local Development

Local development and test use SQLite, so MySQL is not required on developer machines.

### Prerequisites

- Ruby 3.3.x
- Bundler

### Setup

1. Install dependencies:

	bundle install

2. Prepare local databases:

	bin/rails db:prepare

3. Run tests:

	bin/rails test

## Database Configuration

- development: SQLite
- test: SQLite
- staging: MySQL
- production: MySQL

### Staging and Production Environment Variables

Set these for MySQL-backed environments:

- DB_HOST
- DB_USERNAME
- DB_PASSWORD

Production also supports:

- RUNWAY_DATABASE_PASSWORD

Notes:

- If RUNWAY_DATABASE_PASSWORD is present, production uses it.
- Otherwise production falls back to DB_PASSWORD.

## Running the App

Start the Rails server:

bin/rails server

## User Registration and Authentication

Runway supports account registration and session-based authentication.

### User Flows

- Register: /registration/new
- Sign in: /session/new
- Sign out: submit the sign-out action in the navigation
- Protected dashboard: /dashboard
- Account profile: /account

Unauthenticated requests to protected pages are redirected to sign-in.

### Authentication Mode

Runway uses provider-based authentication routing with local native Rails auth enabled by default.

- RUNWAY_AUTH_MODE=local (default)

Future MVP+ modes (planned, not yet implemented):

- RUNWAY_AUTH_MODE=ldap
- RUNWAY_AUTH_MODE=oidc

## Project Ownership Model

Runway uses Project as the top-level ownership boundary for authenticated users.

### Project Flows

- Project list: /projects
- Project detail: /projects/:id
- Create project: /projects/new

Project visibility is membership-scoped. Users can only see and access projects they belong to.

## Application Definition Inside a Project

Applications are defined inside a Project and include basic repository metadata.

### Application Flows

- Application list in project: /projects/:project_id/applications
- Application detail: /projects/:project_id/applications/:id
- Define application: /projects/:project_id/applications/new

### Required Application Fields

- Name
- Description
- Runtime (selected from supported runtime/version options)
- Repository provider
- Repository URL
- Default branch

### Initial Supported Runtimes

Runway seeds supported runtimes and versions for app creation:

- Ruby 4
- Rails 8
- Go 1.22

Users must choose from the supported runtime list when defining an application.

Runtime catalog items are release-managed and defined in code, not through live admin UI.
See docs/RUNTIME_CATALOG_PROCESS.md for the process to add new supported runtimes.

Application access is restricted through project membership.

## Bootstrap and Guardrails

Milestone 0 foundation and setup checklist:

- docs/PROJECT_BOOTSTRAP.md

Product guardrails for app-centric development:

- docs/PRODUCT_GUARDRAILS.md
- AGENTS.md
- .github/copilot-instructions.md

## SonarQube Scanner Compatibility

Runway can generate Sonar scanner CLI-compatible artifacts for Ruby coverage and test execution.

### Generate Sonar Artifacts

Run:

bin/rake quality:sonar_prepare

This generates:

- coverage/coverage.json
- tmp/sonar/test-execution.xml

### Run Sonar Scanner CLI

After artifacts are generated, run sonar-scanner with your server URL and token.

Example:

SONAR_TOKEN=your_token sonar-scanner -Dsonar.host.url=https://sonarqube.example.com

Scanner defaults are stored in:

- sonar-project.properties
