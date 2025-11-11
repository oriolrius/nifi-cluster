---
id: task-006
title: Create docker-compose.yml template file
status: To Do
assignee: []
created_date: '2025-11-11 14:59'
labels:
  - docker
  - templates
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create template for docker-compose.yml with parameterized service names, ports, and volumes.

Template should include markers for:
- Service names (@@CLUSTER_NAME@@-nifi01, etc.)
- Port mappings (@@HTTPS_PORT_1@@, @@S2S_PORT_1@@, etc.)
- Volume paths
- Network name (@@CLUSTER_NAME@@-network)
- Environment variables

Support parameterized node count (3 nodes by default).

Reference: Analysis report section 11.4
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Template supports 3-node NiFi + ZooKeeper cluster
- [ ] #2 All service names, ports, volumes parameterized
- [ ] #3 Network isolation configured per cluster
- [ ] #4 Proper depends_on relationships maintained
<!-- AC:END -->
