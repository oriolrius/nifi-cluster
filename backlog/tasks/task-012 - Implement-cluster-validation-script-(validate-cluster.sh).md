---
id: task-012
title: Implement cluster validation script (validate-cluster.sh)
status: Done
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 16:31'
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
- [x] #1 All validation checks implemented
- [x] #2 Clear pass/fail messages for each check
- [x] #3 Exit code indicates success/failure
- [x] #4 Can run before and after docker compose up
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented validate-cluster.sh comprehensive validation script. Script features:
- Validates all required components in 7 categories:
  1. Directory structure (certs/, conf/, volumes/)
  2. Certificate validation (CA and node certificates using OpenSSL)
  3. Configuration files (nifi.properties, state-management.xml, etc.)
  4. Node addresses (cluster.node.address, remote.input.host)
  5. ZooKeeper configuration (connect strings)
  6. docker-compose.yml (syntax, service count)
  7. Port conflicts (duplicates, availability)
- 30 total validation checks with clear PASS/FAIL messages
- Color-coded output with progress indicators
- Exit code 0 on success, 1 on failure
- Can run before or after docker compose up
- Comprehensive summary showing passed/failed/warnings counts
- Helpful next steps on success
- Tested successfully with current 3-node cluster (all 30 checks passed)
<!-- SECTION:NOTES:END -->
