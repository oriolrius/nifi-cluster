---
id: doc-003
title: Git Conventional Commits Standard
type: other
created_date: '2025-11-11 15:44'
---
# Git Conventional Commits Standard

## Overview

This project uses **Conventional Commits** specification for all commit messages. This provides a consistent commit history that is both human and machine-readable, enabling automated changelogs and semantic versioning.

## Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Types

### Primary Types (MUST use these)

- **feat**: A new feature for the user
  - Example: `feat(scripts): add CA generation script`
  - Example: `feat(templates): add nifi.properties template`

- **fix**: A bug fix
  - Example: `fix(docker): correct port mapping for nifi-2`
  - Example: `fix(certs): resolve certificate validation error`

- **docs**: Documentation only changes
  - Example: `docs(readme): update installation instructions`
  - Example: `docs(api): add PLC4X connection string examples`

- **style**: Code style changes (formatting, missing semi-colons, etc.)
  - Example: `style(scripts): format shell scripts with shfmt`

- **refactor**: Code changes that neither fix bugs nor add features
  - Example: `refactor(scripts): simplify certificate generation logic`

- **perf**: Performance improvements
  - Example: `perf(nifi): increase heap size for better throughput`

- **test**: Adding or correcting tests
  - Example: `test(scripts): add validation tests for CA script`

- **build**: Changes to build system or dependencies
  - Example: `build(docker): update NiFi to version 2.0.0`
  - Example: `build(deps): upgrade PLC4X NAR to v0.13.1`

- **ci**: Changes to CI configuration
  - Example: `ci(github): add workflow for automated testing`

- **chore**: Other changes that don't modify src or test files
  - Example: `chore(backlog): update task-004 status to done`
  - Example: `chore(gitignore): exclude cluster volumes`

## Scopes

Common scopes for this project:

- **scripts**: Shell scripts (generate-ca.sh, etc.)
- **templates**: Configuration templates
- **docker**: Docker Compose and container configuration
- **certs**: PKI and certificate management
- **nifi**: NiFi configuration
- **registry**: NiFi Registry configuration
- **gitea**: Gitea configuration
- **zookeeper**: ZooKeeper configuration
- **docs**: Documentation files
- **backlog**: Backlog.md task management
- **cluster**: Multi-cluster infrastructure

## Breaking Changes

If a commit introduces a breaking change, add `BREAKING CHANGE:` in the footer or append `!` after type/scope:

```
feat(api)!: remove deprecated v1 endpoints

BREAKING CHANGE: API v1 endpoints have been removed. All clients must upgrade to v2.
```

## Examples

### Good Commits

```
feat(scripts): add multi-cluster CA generation script

- Generates root Certificate Authority
- Creates JKS and PKCS12 truststores
- Supports custom validity and org details
- Includes comprehensive validation

Closes #42
```

```
fix(docker): correct ZooKeeper connection string

The connection string was missing port 2181 for zookeeper-3,
causing cluster coordination failures.
```

```
docs(readme): add PLC4X integration examples

Added connection string examples for:
- Siemens S7
- Modbus TCP
- OPC-UA
```

```
chore(backlog): complete task-004

- Created nifi.properties template
- All acceptance criteria met
```

### Bad Commits (DO NOT USE)

```
❌ Add multi-cluster infrastructure scripts and directory structure
   (Missing type and scope)

❌ Update task task-004
   (Missing type and not descriptive)

❌ Fix bug
   (Not descriptive, no context)

❌ WIP
   (Never commit WIP, too vague)
```

## Multi-Task Commits

When a commit spans multiple tasks, list them in the body:

```
feat(infrastructure): complete multi-cluster foundation

Task 1: Multi-cluster directory structure
Task 2: Shared CA generation script
Task 3: Cluster certificate generation script

- Added shared/certs/ for Certificate Authority
- Created scripts/generate-ca.sh
- Created scripts/generate-cluster-certs.sh
- Updated .gitignore for private key protection

Completed tasks: task-001, task-002, task-003
```

## Git Hooks

Consider adding a commit-msg hook to enforce format:

```bash
#!/bin/bash
# .git/hooks/commit-msg

commit_msg=$(cat "$1")
pattern="^(feat|fix|docs|style|refactor|perf|test|build|ci|chore)(\(.+\))?: .{1,72}"

if ! echo "$commit_msg" | grep -qE "$pattern"; then
    echo "ERROR: Commit message does not follow Conventional Commits format"
    echo ""
    echo "Format: <type>[optional scope]: <description>"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore"
    echo ""
    echo "Example: feat(scripts): add CA generation script"
    exit 1
fi
```

## Tools

- **commitizen**: Interactive tool for creating commits
- **commitlint**: Lint commit messages
- **standard-version**: Automated versioning and changelog

## AI Assistant Rules

**MANDATORY**: When creating commits, AI assistants MUST:

1. Always use conventional commit format
2. Include appropriate type (feat, fix, docs, etc.)
3. Add scope when applicable
4. Write clear, descriptive commit messages
5. Include body for complex changes
6. Reference task IDs in body (e.g., "Completed tasks: task-001, task-002")
7. Add Claude Code footer

## Template

```
<type>(<scope>): <description in imperative mood>

[Longer description if needed]
[What changed and why]
[Impact of changes]

[Reference tasks or issues]
Completed tasks: task-XXX, task-YYY

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

## References

- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Angular Commit Guidelines](https://github.com/angular/angular/blob/master/CONTRIBUTING.md#commit)
