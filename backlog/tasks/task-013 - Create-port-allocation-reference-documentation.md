---
id: task-013
title: Create port allocation reference documentation
status: Done
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

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Created comprehensive port allocation reference documentation in README.md. Documentation includes:
- Clear explanation of port calculation formula: BASE_PORT = 29000 + (CLUSTER_NUM × 1000)
- Port offsets table showing all service types (HTTPS, ZK, S2S, Cluster Protocol, Load Balance)
- Complete port ranges table for clusters 0-9 showing all port assignments
- Current cluster (Cluster 0) port mapping with access URLs
- Three detailed examples (production, staging, dev clusters)
- Avoiding port conflicts section with 4 strategies
- Edge cases documentation:
  * Large clusters (>10 nodes)
  * Port exhaustion scenarios
  * Conflicts with existing services and solutions
- Integration with validation script
- Clear formulas for calculating ports for each service type
Replaced existing basic port mapping section with comprehensive reference.
<!-- SECTION:NOTES:END -->
