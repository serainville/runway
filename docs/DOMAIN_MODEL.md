# Domain Model

## Core concepts

```text
Team
User
Membership
Application
Environment
RepositoryConnection
Build
Release
Deployment
ProcessType
ConfigVar
Domain
DeploymentEvent
AuditEvent
DeploymentTarget
ClusterCredential
```

## Relationships

- Team has many Applications.
- Application has many Environments.
- Application has many Builds.
- Application has many Releases.
- Environment has many ConfigVars.
- Environment has many Deployments.
- Deployment belongs to Release.
- Deployment has many DeploymentEvents.
- Release belongs to Build when created from source.
- Environment belongs to DeploymentTarget.

## Project access model

- User has many ProjectMemberships.
- Project has many ProjectMemberships.
- ProjectMembership role is one of:
	- owner
	- contributor
	- reviewer
- A user can belong to multiple projects.
- A project can be private or public.
- Public projects are read-only by default for authenticated users who are not members.
- Private projects require explicit membership for access.

## Release rules

A Release is immutable and references:

- app
- environment
- image digest
- git SHA
- config version
- creator
- timestamp
- status

## Deployment rules

A Deployment represents an attempt to run a Release in an Environment.

Rollback creates a new Deployment referencing a previous Release.
