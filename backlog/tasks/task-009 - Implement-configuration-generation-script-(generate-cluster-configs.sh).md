---
id: task-009
title: Implement configuration generation script (generate-cluster-configs.sh)
status: Done
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 16:15'
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
- [x] #1 All node configs generated from templates
- [x] #2 Node-specific values correctly substituted
- [x] #3 Cluster-wide values consistent across nodes
- [x] #4 Certificates copied to correct locations
- [x] #5 Generated configs validated
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented generate-cluster-configs.sh script in conf/ directory. Script features:
- Accepts CLUSTER_NAME, CLUSTER_NUM, NODE_COUNT parameters
- Calculates port assignments: BASE_PORT = 29000 + (CLUSTER_NUM * 1000)
- Generates nifi.properties for each node with correct node-specific values
- Generates state-management.xml with ZooKeeper config
- Copies standard config files (authorizers.xml, bootstrap.conf, etc.)
- Copies certificates from certs/ to conf/ directories
- Includes validation and helpful output
- Tested successfully with test cluster (CLUSTER_NUM=2, 3 nodes)
<!-- SECTION:NOTES:END -->
