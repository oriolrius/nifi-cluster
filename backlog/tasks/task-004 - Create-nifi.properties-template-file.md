---
id: task-004
title: Create nifi.properties template file
status: In Progress
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 15:39'
labels:
  - configuration
  - templates
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create template file for nifi.properties with parameterized values.

Template should include markers for:
- @@NODE_NAME@@ - Node-specific hostname
- @@CLUSTER_NAME@@ - Cluster identifier
- @@ZK_CONNECT_STRING@@ - ZooKeeper connection string
- @@WEB_PROXY_HOSTS@@ - Comma-separated proxy hosts
- @@SENSITIVE_PROPS_KEY@@ - Encryption key

Based on existing conf/nifi-1/nifi.properties with critical properties identified in analysis.

Reference: Analysis report section 11.3
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Template includes all 170+ properties from current nifi.properties
- [ ] #2 All node-specific values parameterized with @@MARKERS@@
- [ ] #3 All cluster-specific values parameterized
- [ ] #4 Template validated against original file
<!-- AC:END -->
