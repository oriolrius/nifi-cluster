---
id: task-007
title: Create .env template file for cluster configuration
status: To Do
assignee: []
created_date: '2025-11-11 14:59'
labels:
  - configuration
  - templates
dependencies: []
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create template .env file with all cluster-specific environment variables.

Should include:
- Cluster identity (CLUSTER_NAME, CLUSTER_NUM, NODE_COUNT)
- Port assignments (BASE_PORT, HTTPS_PORT_*, S2S_PORT_*, ZK_PORT_*)
- Service names (NIFI_NODE_*, ZK_NODE_*)
- Derived values (ZK_CONNECT_STRING, WEB_PROXY_HOSTS, ZK_ROOT_NODE)
- Security settings (credentials, sensitive props key)
- Version specifications

Reference: Analysis report section 12.4
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All required environment variables included
- [ ] #2 Clear comments explaining each variable
- [ ] #3 Port calculation formulas documented
- [ ] #4 Default values provided
<!-- AC:END -->
