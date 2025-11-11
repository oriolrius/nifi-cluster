---
id: task-016
title: Test cluster creation with cluster02 and verify isolation
status: To Do
assignee: []
created_date: '2025-11-11 14:59'
labels:
  - testing
  - isolation
  - e2e
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create second cluster and verify complete isolation from cluster01.

Test steps:
1. Run create-cluster.sh cluster02 2 3
2. Start cluster02
3. Verify cluster01 and cluster02 both running
4. Verify network isolation (no ping between clusters)
5. Verify ZK root node isolation (/cluster01 vs /cluster02)
6. Verify different port ranges (30443-30445 vs 31443-31445)
7. Verify shared CA trust (both can use same truststore)
8. Create flows in both clusters independently

Reference: Analysis report section 13.2, 13.3
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Both clusters running simultaneously
- [ ] #2 No network connectivity between cluster01 and cluster02
- [ ] #3 Different ZK root nodes confirmed
- [ ] #4 Both clusters accessible on correct ports
- [ ] #5 Flows in one cluster don't affect the other
<!-- AC:END -->
