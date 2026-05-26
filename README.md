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
