---
id: task-015
title: Test cluster creation with cluster01
status: To Do
assignee: []
created_date: '2025-11-11 14:59'
labels:
  - testing
  - e2e
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
End-to-end test of cluster creation process for cluster01.

Test steps:
1. Generate shared CA
2. Run create-cluster.sh cluster01 1 3
3. Validate with validate-cluster.sh
4. Start with docker compose up -d
5. Verify all 3 NiFi nodes connect to cluster
6. Verify ZooKeeper ensemble healthy
7. Access web UI on ports 59143-59145
8. Run post-deployment validation (section 13.2)

Reference: Analysis report section 13
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Cluster creation completes without errors
- [ ] #2 All validation checks pass
- [ ] #3 All 3 NiFi nodes show connected in cluster
- [ ] #4 Web UI accessible on all 3 ports
- [ ] #5 Can create and run simple flow
<!-- AC:END -->
