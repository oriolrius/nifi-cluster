---
id: task-006
title: Create docker-compose.yml template file
status: Done
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 15:51'
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
- [x] #1 Template supports 3-node NiFi + ZooKeeper cluster
- [x] #2 All service names, ports, volumes parameterized
- [x] #3 Network isolation configured per cluster
- [x] #4 Proper depends_on relationships maintained
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Created docker-compose.yml.template in templates/ directory with 14 parameterized markers:

Service Structure:
- 3 ZooKeeper nodes (@@CLUSTER_NAME@@-zookeeper-1/2/3)
- 3 NiFi nodes (@@CLUSTER_NAME@@-nifi-1/2/3)
- Network isolation per cluster (@@CLUSTER_NAME@@-network)

Parameterized Values:
- @@CLUSTER_NAME@@ - Service names, container names, hostnames, network name
- @@CONF_BASE_PATH@@ - Configuration mount paths
- @@VOLUME_BASE_PATH@@ - Data volume paths
- @@ZK_PORT_1/2/3@@ - ZooKeeper client ports
- @@HTTPS_PORT_1/2/3@@ - NiFi HTTPS UI ports
- @@S2S_PORT_1/2/3@@ - NiFi Site-to-Site ports
- @@ZK_CONNECT_STRING@@ - Full ZooKeeper connection string
- @@WEB_PROXY_HOST@@ - NiFi web proxy configuration

Dependencies and Health Checks:
- Proper depends_on relationships maintained (NiFi depends on all 3 ZK nodes)
- Health checks configured for all NiFi nodes
- Restart policy: unless-stopped

Validated:
- YAML structure valid (6 services, 3 ZK + 3 NiFi nodes)
- All parameters correctly placed
- Network isolation configured

Location: templates/docker-compose.yml.template
<!-- SECTION:NOTES:END -->
