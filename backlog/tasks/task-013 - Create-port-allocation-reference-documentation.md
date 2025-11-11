---
id: task-013
title: Create port allocation reference documentation
status: In Progress
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 16:35'
labels:
  - documentation
dependencies: []
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Document the port allocation strategy for multiple clusters.

Should include:
- Port calculation formula
- Table showing port ranges per cluster (cluster01-cluster10)
- Explanation of port offsets (+43 for HTTPS, +81 for ZK)
- Examples for common scenarios
- How to avoid port conflicts

Reference: Analysis report section 7.2, 15.3
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Clear table with port ranges for 10 clusters
- [x] #2 Formula explained with examples
- [x] #3 Edge cases documented
- [x] #4 Added to main README.md
<!-- AC:END -->
