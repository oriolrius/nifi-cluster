---
id: task-008
title: Implement volume initialization script (init-cluster-volumes.sh)
status: To Do
assignee: []
created_date: '2025-11-11 14:59'
labels:
  - filesystem
  - initialization
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create script to initialize volume directory structure for a cluster.

Script should:
- Accept CLUSTER_NAME and NODE_COUNT parameters
- Create ZooKeeper directories: data, datalog, logs
- Create NiFi directories: content_repository, database_repository, flowfile_repository, provenance_repository, state, logs
- Set proper permissions (UID:GID 1000:1000)
- Create conf directories for each node

Reference: Analysis report section 6.2, 12.5
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All required directories created per node
- [ ] #2 Permissions set to 1000:1000
- [ ] #3 Script validates inputs before execution
- [ ] #4 Idempotent (safe to run multiple times)
<!-- AC:END -->
