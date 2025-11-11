---
id: task-007
title: Create .env template file for cluster configuration
status: Done
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 16:08'
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
- [x] #1 All required environment variables included
- [x] #2 Clear comments explaining each variable
- [x] #3 Port calculation formulas documented
- [x] #4 Default values provided
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Created comprehensive .env.template in templates/ directory with 37 environment variables organized into 10 sections:

1. CLUSTER IDENTITY (3 vars)
   - CLUSTER_NAME, CLUSTER_NUM, NODE_COUNT

2. VERSION SETTINGS (2 vars)
   - NIFI_VERSION, ZOOKEEPER_VERSION

3. PORT ASSIGNMENTS (10 vars)
   - BASE_PORT (with calculation formula documentation)
   - ZK_PORT_1/2/3 (ZooKeeper client ports)
   - HTTPS_PORT_1/2/3 (NiFi web UI ports)
   - S2S_PORT_1/2/3 (Site-to-Site ports)

4. SERVICE NAMES (6 vars)
   - ZK_NODE_1/2/3, NIFI_NODE_1/2/3

5. DERIVED VALUES (4 vars)
   - ZK_CONNECT_STRING, ZK_ROOT_NODE
   - WEB_PROXY_HOST, NETWORK_NAME

6. PATHS (4 vars)
   - CLUSTER_BASE_PATH, CONF_BASE_PATH
   - VOLUME_BASE_PATH, CERTS_BASE_PATH

7. SECURITY SETTINGS (3 vars)
   - NIFI_SINGLE_USER_USERNAME/PASSWORD
   - NIFI_SENSITIVE_PROPS_KEY

8. PERFORMANCE TUNING (2 vars)
   - NIFI_JVM_HEAP_INIT/MAX

9. ZOOKEEPER SETTINGS (4 vars)
   - ZOO_TICK_TIME, ZOO_INIT_LIMIT
   - ZOO_SYNC_LIMIT, ZOO_MAX_CLIENT_CNXNS

10. CLUSTER COORDINATION (2 vars)
    - NIFI_CLUSTER_NODE_PROTOCOL_PORT
    - NIFI_ELECTION_MAX_WAIT

Documentation Features:
- Clear section headers with separators
- Inline comments explaining each variable
- Port calculation formulas documented
- Security and performance recommendations
- Usage instructions at top of file
- Example values for cluster01 (CLUSTER_NUM=1)

Total: 176 lines, 37 variables, 10 organized sections

Location: templates/.env.template

Port Strategy Update: Changed BASE_PORT from 59000 to 29000 and updated formula from 100-port ranges to 1000-port ranges per cluster. This provides better isolation and more available ports per cluster.

Updated 146 port references across:
- templates/.env.template (all port values)
- templates/nifi.properties.template (example)
- backlog/docs/doc-001 (62 references)
- backlog/decisions/decision-001 (77 references)
- backlog/tasks/task-009, task-015, task-016 (7 references)

New allocation: Cluster 1: 30000-30999, Cluster 2: 31000-31999, etc.
<!-- SECTION:NOTES:END -->
