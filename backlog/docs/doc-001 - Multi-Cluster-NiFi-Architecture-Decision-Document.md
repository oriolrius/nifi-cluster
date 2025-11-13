---
id: doc-001
title: Multi-Cluster NiFi Architecture Decision Document
type: other
created_date: '2025-11-11 15:05'
---
# Decision Document: Multi-Cluster NiFi Architecture

**Status**: Approved
**Date**: 2025-11-11
**Author**: System Architecture Team
**Stakeholders**: DevOps, Data Engineering

---

## Executive Summary

This document outlines the decision to transform our current single NiFi cluster deployment into a **multi-cluster architecture** that supports running multiple independent NiFi clusters on the same host infrastructure. This enables isolation for different environments, projects, or tenants while maintaining operational efficiency through shared PKI and standardized automation.

---

## 1. Current State Analysis

### 1.1 Existing Architecture

We currently operate a **single 3-node NiFi cluster** with the following characteristics:

#### Infrastructure Components
- **NiFi Nodes**: 3 nodes (nifi-1, nifi-2, nifi-3)
- **ZooKeeper Ensemble**: 3 nodes (zookeeper-1, zookeeper-2, zookeeper-3)
- **Deployment Method**: Docker Compose
- **Network**: Single bridge network (`nifi-cluster-network`)
- **Data Persistence**: Host bind mounts (no Docker volumes)

#### Port Allocation
```
Service          Node 1      Node 2      Node 3
--------------------------------------------------------
NiFi HTTPS       30443       30444       30445
Site-to-Site     30100       30101       30102
ZooKeeper        30181       30182       30183
```

#### Security Architecture
- **PKI**: Private Certificate Authority (CA)
  - Location: `certs/ca/`
  - CA Certificate: 10-year validity
  - Node Certificates: Individual per node (CN=nifi-1, CN=nifi-2, CN=nifi-3)
  - Truststores: Shared CA trust across all nodes
- **Authentication**: Single-user authentication (admin/password)
- **Encryption**: TLS/SSL for all cluster communication

#### Directory Structure
```
nifi-cluster/
├── certs/                  # PKI certificates
│   ├── ca/                # Root CA
│   ├── nifi-{1,2,3}/      # Node certificates
│   └── zookeeper-{1,2,3}/ # ZK certificates
├── conf/                   # Node configurations
│   ├── nifi-{1,2,3}/      # Per-node config files
│   └── create-node-properties.sh
├── volumes/                # Persistent data
│   ├── nifi-{1,2,3}/
│   └── zookeeper-{1,2,3}/
├── docker-compose.yml      # Service orchestration
├── .env                    # Environment variables
└── init-volumes.sh         # Volume initialization
```

#### Key Configuration Files

**Per-Node Configuration** (`conf/nifi-X/`):
- `nifi.properties` - Main configuration (170+ properties)
  - Node-specific: `nifi.cluster.node.address=nifi-X`
  - Cluster-wide: `nifi.zookeeper.connect.string`, `nifi.web.proxy.host`
- `state-management.xml` - ZooKeeper state provider config
- `authorizers.xml` - Authorization policies
- `bootstrap.conf` - JVM settings
- `keystore.p12` - Node private key + certificate
- `truststore.p12` - CA truststore

**Cluster Coordination**:
- ZooKeeper root node: `/nifi` (shared state location)
- Cluster protocol port: `8082` (internal, not exposed)
- Load balance port: `6342` (internal, not exposed)

### 1.2 Current Strengths

✅ **Working Production System**
- Stable 3-node HA cluster
- Automatic leader election via ZooKeeper
- Load balancing across nodes
- Shared flow state synchronization

✅ **Strong Security Foundation**
- Private PKI infrastructure
- Mutual TLS authentication between nodes
- Certificate-based node identity
- Encrypted communication

✅ **Operational Maturity**
- Automated certificate generation (`certs/generate-certs.sh`)
- Automated configuration generation (`conf/create-node-properties.sh`)
- Volume initialization script (`init-volumes.sh`)
- Docker Compose orchestration

✅ **Well-Documented**
- Comprehensive README with usage examples
- Configuration management guides
- Troubleshooting documentation

### 1.3 Current Limitations

❌ **Single Cluster Only**
- Cannot run multiple independent clusters
- No isolation between different environments/projects
- All flows share the same cluster resources

❌ **Hardcoded Configuration**
- Service names hardcoded as `nifi-1`, `nifi-2`, `nifi-3`
- Port ranges fixed to 30000-30999, 30443-30445
- Scripts assume single cluster deployment

❌ **No Multi-Tenancy**
- Cannot separate workloads by team, project, or environment
- All users share the same cluster namespace
- Resource contention between different use cases

❌ **Scaling Complexity**
- Adding new clusters requires manual configuration duplication
- Risk of port conflicts
- No standardized process for cluster provisioning

---

## 2. Business Requirements

### 2.1 Primary Drivers

**R1: Environment Isolation**
- Need to run separate clusters for development, staging, production
- Each environment must be completely isolated (data, network, configuration)
- Prevent accidental cross-environment data flow

**R2: Multi-Tenancy**
- Support multiple teams/projects with dedicated clusters
- Each cluster operates independently
- No resource interference between clusters

**R3: Scalability**
- Rapidly provision new clusters on-demand
- Standardized, repeatable deployment process
- Minimal manual configuration

**R4: Operational Efficiency**
- Maintain single infrastructure host (no need for separate servers)
- Shared operational tools and monitoring
- Unified certificate management

**R5: Security & Compliance**
- Maintain strong security posture
- Certificate-based authentication
- Network isolation between clusters
- Shared PKI for operational simplicity

### 2.2 Non-Functional Requirements

**NFR1: Backward Compatibility**
- Existing cluster must migrate to new structure without data loss
- Minimal downtime during migration

**NFR2: Port Management**
- Clear port allocation strategy
- Avoid conflicts between clusters
- Easy-to-remember port patterns

**NFR3: Automation**
- One-command cluster creation
- Automated certificate generation
- Automated configuration management

**NFR4: Maintainability**
- Template-based configuration
- Version-controlled automation scripts
- Clear documentation

---

## 3. Solution Design

### 3.1 Architecture Overview

**Multi-Cluster Architecture** with shared PKI and isolated runtime:

```
┌─────────────────────────────────────────────────────────────┐
│                    Host Infrastructure                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │              Shared PKI Infrastructure                  │ │
│  │                                                          │ │
│  │  Root Certificate Authority (CA)                        │ │
│  │    • Single CA signs all cluster certificates          │ │
│  │    • Location: shared/certs/ca/                         │ │
│  │    • Shared truststore across all clusters             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌─────────────────────┐      ┌─────────────────────┐      │
│  │   Cluster 01        │      │   Cluster 02        │      │
│  │                     │      │                     │      │
│  │  • cluster01-nifi01 │      │  • cluster02-nifi01 │      │
│  │  • cluster01-nifi02 │      │  • cluster02-nifi02 │      │
│  │  • cluster01-nifi03 │      │  • cluster02-nifi03 │      │
│  │                     │      │                     │      │
│  │  • cluster01-zk01   │      │  • cluster02-zk01   │      │
│  │  • cluster01-zk02   │      │  • cluster02-zk02   │      │
│  │  • cluster01-zk03   │      │  • cluster02-zk03   │      │
│  │                     │      │                     │      │
│  │  Network:           │      │  Network:           │      │
│  │    cluster01-net    │      │    cluster02-net    │      │
│  │                     │      │                     │      │
│  │  ZK Root: /cluster01│      │  ZK Root: /cluster02│      │
│  │                     │      │                     │      │
│  │  Ports: 30000-30999 │      │  Ports: 31000-31999 │      │
│  └─────────────────────┘      └─────────────────────┘      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Key Design Decisions

#### Decision 1: Shared CA Strategy

**Decision**: Use a single Certificate Authority for all clusters

**Rationale**:
- **Operational Simplicity**: One CA to manage instead of multiple
- **Future Flexibility**: Enables cross-cluster communication (Site-to-Site) if needed
- **Trust Model**: All nodes trust certificates from the same root CA
- **Certificate Lifecycle**: Single renewal process for CA
- **Security**: Isolation achieved through network separation, not PKI

**Implementation**:
- Single CA located at `shared/certs/ca/`
- Each node gets unique certificate with CN=clusterXX-nifiYY
- Shared truststore distributed to all nodes
- CA generated once, reused for all clusters

#### Decision 2: Network Isolation Strategy

**Decision**: Separate Docker bridge network per cluster

**Rationale**:
- **Complete Isolation**: Clusters cannot communicate unless explicitly configured
- **Security**: Prevents accidental data leakage between clusters
- **Simplicity**: Docker handles network isolation automatically
- **Naming**: Clear network names (cluster01-network, cluster02-network)

**Implementation**:
- Each cluster defines its own Docker network
- Service names unique per cluster (cluster01-nifi01, cluster02-nifi01)
- DNS resolution scoped to cluster network

#### Decision 3: ZooKeeper Root Node Isolation

**Decision**: Each cluster uses a different ZooKeeper root node

**Rationale**:
- **Data Isolation**: Critical for preventing state conflicts
- **Configuration**: `nifi.zookeeper.root.node=/cluster01` vs `/cluster02`
- **State Management**: Each cluster maintains independent state
- **Flow Storage**: Flows stored in separate ZK namespaces

**Implementation**:
- `nifi.zookeeper.root.node=/cluster01` (in nifi.properties)
- `<property name="Root Node">/cluster01</property>` (in state-management.xml)

#### Decision 4: Port Allocation Strategy

**Decision**: Systematic port ranges with 100-port blocks per cluster

**Formula**:
```bash
CLUSTER_BASE = 29000 + (CLUSTER_NUM × 1000)

# For cluster01 (CLUSTER_NUM=1):
CLUSTER_BASE = 30100
HTTPS_PORTS  = 30443, 30444, 30445  (base + 43 + node_index)
S2S_PORTS    = 30100, 30101, 30102  (base + node_index)
ZK_PORTS     = 30181, 30182, 30183  (base + 81 + node_index)

# For cluster02 (CLUSTER_NUM=2):
CLUSTER_BASE = 31100
HTTPS_PORTS  = 31443, 31444, 31445
S2S_PORTS    = 31100, 31101, 31102
ZK_PORTS     = 31181, 31182, 31183
```

**Port Map**:
| Cluster | Base  | HTTPS       | S2S         | ZooKeeper   |
|---------|-------|-------------|-------------|-------------|
| 01      | 30100 | 30443-30445 | 30100-30102 | 30181-30183 |
| 02      | 31100 | 31443-31445 | 31100-31102 | 31181-31183 |
| 03      | 32000 | 32443-32445 | 32000-32102 | 32181-32183 |
| 04      | 33000 | 30443-30445 | 33000-33102 | 33181-33183 |

#### Decision 5: Template-Based Configuration

**Decision**: Use templates with marker-based substitution (sed/envsubst)

**Templates Required**:
1. `nifi.properties.tmpl` - Main NiFi configuration
2. `state-management.xml.tmpl` - State provider config
3. `docker-compose.yml.tmpl` - Service orchestration
4. `.env.tmpl` - Environment variables

#### Decision 6: Automation Script Architecture

**Decision**: Modular scripts with single master orchestrator

**Script Hierarchy**:
```
create-cluster.sh (master)
  ├─> init-cluster-volumes.sh
  ├─> generate-cluster-certs.sh
  ├─> generate-cluster-configs.sh
  └─> lib/generate-docker-compose.sh
```

**Usage**:
```bash
./scripts/create-cluster.sh cluster01 1 3
# Arguments: CLUSTER_NAME CLUSTER_NUM NODE_COUNT
```

---

## 4. Implementation Plan

See backlog tasks task-001 through task-017 for detailed implementation steps.

### Phases
1. **Foundation**: Directory structure, shared CA (tasks 1-2)
2. **Templates**: Create all configuration templates (tasks 4-7)
3. **Automation**: Build scripts (tasks 3, 8-12)
4. **Testing**: Validate clusters (tasks 15-16)
5. **Documentation**: Guides and references (tasks 13-14, 17)

---

## 5. Success Metrics

- **Cluster Creation Time**: < 5 minutes
- **Configuration Consistency**: 100% pass validation
- **Isolation**: 0% network traffic between clusters
- **Port Conflicts**: 0%
- **Multi-Cluster Support**: 5+ simultaneous clusters

---

## 6. Next Steps

1. Review and approve this decision document
2. Begin Phase 1 implementation (task-001, task-002)
3. Create templates (Phase 2)
4. Complete automation scripts (Phase 3)
5. Testing and validation (Phase 4)
6. Documentation and migration (Phase 5)

---

**Last Updated**: 2025-11-11
