---
id: task-012
title: Implement cluster validation script (validate-cluster.sh)
status: In Progress
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 16:29'
labels:
  - validation
  - testing
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create post-creation validation script to verify cluster configuration.

Script should validate:
- Directory structure exists
- Certificate chain (openssl verify)
- Configuration files present and correct
- Node addresses match hostnames in nifi.properties
- docker-compose.yml syntax
- Port assignments don't conflict

Reference: Analysis report section 11.6, 13.1
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All validation checks implemented
- [ ] #2 Clear pass/fail messages for each check
- [ ] #3 Exit code indicates success/failure
- [ ] #4 Can run before and after docker compose up
<!-- AC:END -->
