---
id: task-009
title: Implement configuration generation script (generate-cluster-configs.sh)
status: In Progress
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 16:13'
labels:
  - configuration
  - automation
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create script to generate all configuration files from templates for a cluster.

Script should:
- Accept CLUSTER_NAME, CLUSTER_NUM, NODE_COUNT parameters
- Calculate port assignments using formula: BASE_PORT = 29000 + (CLUSTER_NUM * 1000)
- Generate nifi.properties for each node from template
- Generate state-management.xml for each node from template
- Copy standard config files (authorizers.xml, bootstrap.conf, etc.)
- Copy certificates to conf directories

Use sed/envsubst for template substitution.

Reference: Analysis report section 11.3
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All node configs generated from templates
- [ ] #2 Node-specific values correctly substituted
- [ ] #3 Cluster-wide values consistent across nodes
- [ ] #4 Certificates copied to correct locations
- [ ] #5 Generated configs validated
<!-- AC:END -->
