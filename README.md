# Multi-Cluster Apache NiFi Platform

A production-ready multi-cluster Apache NiFi deployment system with shared PKI infrastructure, automated configuration generation, and Docker Compose orchestration. This platform enables running multiple independent NiFi clusters on a single host with complete isolation.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Quick Start](#quick-start)
- [Directory Structure](#directory-structure)
- [Port Allocation](#port-allocation)
- [Scripts Documentation](#scripts-documentation)
- [Configuration Management](#configuration-management)
- [Troubleshooting](#troubleshooting)
- [Migration Guide](#migration-guide)
- [Advanced Usage](#advanced-usage)
- [Resources](#resources)

## Overview

### Key Features

- **Multi-Cluster Support**: Run multiple independent NiFi clusters on one host
- **Complete Isolation**: Each cluster has its own network, volumes, and configuration
- **Shared PKI**: Single Certificate Authority for all clusters (simplifies management)
- **Automated Deployment**: One-command cluster creation with validation
- **Port Management**: Systematic port allocation prevents conflicts
- **High Availability**: 3-node clusters with ZooKeeper coordination (customizable)
- **Production Ready**: Secure by default with TLS/SSL and configurable JVM settings

### Use Cases

- **Environment Isolation**: Separate dev, staging, and production clusters
- **Multi-Tenancy**: Dedicated clusters per team or project
- **Testing**: Rapidly spin up/down test clusters
- **Development**: Local cluster development without cloud costs

## Architecture

### High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                    Host Infrastructure                            │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │          Shared Certificate Authority (CA)                   │ │
│  │  • Single CA signs all cluster certificates                 │ │
│  │  • Location: shared/certs/ca/                                │ │
│  │  • Enables trust between nodes and future inter-cluster     │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  ┌──────────────────────┐  ┌──────────────────────┐             │
│  │ Production (Cluster 0)│  │ Staging (Cluster 1)  │             │
│  │                      │  │                      │             │
│  │ nifi-1, nifi-2, ...  │  │ nifi-1, nifi-2, ...  │             │
│  │ zookeeper-1, 2, 3    │  │ zookeeper-1, 2, 3    │             │
│  │                      │  │                      │             │
│  │ Network: production  │  │ Network: staging     │             │
│  │ Ports: 29443-29445   │  │ Ports: 30443-30445   │             │
│  │ Volumes: volumes/    │  │ Volumes: volumes/    │             │
│  └──────────────────────┘  └──────────────────────┘             │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Single Cluster Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    NiFi Cluster                         │
│  ┌─────────┐      ┌─────────┐      ┌─────────┐        │
│  │ NiFi-1  │      │ NiFi-2  │      │ NiFi-3  │        │
│  │ :29443  │      │ :29444  │      │ :29445  │        │
│  └────┬────┘      └────┬────┘      └────┬────┘        │
│       └────────────────┼────────────────┘              │
└────────────────────────┼───────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │     ZooKeeper Ensemble        │
         │  ┌────┐  ┌────┐  ┌────┐      │
         │  │ ZK1│  │ ZK2│  │ ZK3│      │
         │  └────┘  └────┘  └────┘      │
         └───────────────────────────────┘
```

### Security Architecture

- **Private PKI**: Self-signed Certificate Authority for all clusters
- **TLS/SSL**: All cluster communication encrypted
- **Per-Node Certificates**: Unique identity for each node (CN=nifi-1, CN=nifi-2, etc.)
- **Shared Truststore**: All nodes trust the same CA
- **Mutual TLS**: Optional node-to-node authentication
- **Single-User Auth**: Simple admin authentication (production: use LDAP/OIDC)

### Network Isolation

- **Dedicated Networks**: Each cluster has its own Docker bridge network
- **DNS Resolution**: Service names scoped to cluster network
- **No Cross-Cluster Traffic**: Complete network isolation by default
- **Future Flexibility**: Can enable Site-to-Site between clusters if needed

## Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose V2+
- 4GB+ RAM per cluster
- Linux, macOS, or WSL2

### Create Your First Cluster

```bash
# 1. Clone/navigate to the project directory
cd nifi-cluster

# 2. Create a 3-node production cluster (cluster number 0)
./create-cluster.sh production 0 3

# 3. Review and customize environment variables (optional)
vi .env

# 4. Start the cluster
docker compose up -d

# 5. Monitor startup (takes 2-3 minutes)
docker compose logs -f

# 6. Access NiFi UI
open https://localhost:29443/nifi
```

**Default Credentials**: `admin` / `changeme123456`

### Create Additional Clusters

```bash
# Staging cluster (cluster number 1)
./create-cluster.sh staging 1 3

# Development cluster (cluster number 2, only 2 nodes)
./create-cluster.sh dev 2 2
```

Each cluster gets its own port range:
- **Cluster 0**: ports 29443-29445
- **Cluster 1**: ports 30443-30445
- **Cluster 2**: ports 31443-31444

## Directory Structure

```
nifi-cluster/
├── shared/                     # Shared resources across all clusters
│   └── certs/                  # Certificate management
│       └── ca/                 # Shared Certificate Authority
│           ├── ca-key.pem      # CA private key (CRITICAL - backup!)
│           ├── ca-cert.pem     # CA certificate
│           └── truststore.p12  # CA truststore
│
├── certs/                      # Active cluster certificates
│   ├── ca/                     # CA files (used by scripts)
│   ├── nifi-1/                 # Node 1 source certificates
│   │   ├── keystore.p12        # Node private key + cert
│   │   ├── truststore.p12      # CA truststore
│   │   └── server-cert.pem     # Node certificate
│   ├── nifi-2/                 # Node 2 source certificates
│   └── nifi-3/                 # Node 3 source certificates
│
├── conf/                       # Active cluster configuration
│   ├── nifi-1/                 # Node 1 config
│   │   ├── nifi.properties     # Main NiFi configuration
│   │   ├── state-management.xml
│   │   ├── authorizers.xml
│   │   ├── bootstrap.conf
│   │   ├── keystore.p12        # Certificates (copied from certs/)
│   │   └── truststore.p12
│   ├── nifi-2/                 # Node 2 config
│   └── nifi-3/                 # Node 3 config
│
├── volumes/                    # Active cluster runtime data
│   ├── zookeeper-1/
│   │   ├── data/
│   │   ├── datalog/
│   │   └── logs/
│   ├── zookeeper-2/
│   ├── zookeeper-3/
│   ├── nifi-1/
│   │   ├── content_repository/
│   │   ├── database_repository/
│   │   ├── flowfile_repository/
│   │   ├── provenance_repository/
│   │   ├── state/
│   │   └── logs/
│   ├── nifi-2/
│   └── nifi-3/
│
├── templates/                  # Configuration templates
│   ├── nifi.properties.template
│   ├── state-management.xml.template
│   ├── docker-compose.yml.template
│   └── .env.template
│
├── scripts/                    # Automation scripts (if separated)
│
├── create-cluster.sh           # Master cluster creation script
├── validate-cluster.sh         # Cluster validation script
├── generate-docker-compose.sh  # Docker Compose generator
├── docker-compose.yml          # Generated compose file (active cluster)
├── .env                        # Generated environment file (active cluster)
│
└── backlog/                    # Project documentation
    ├── docs/                   # Design documents
    │   ├── doc-001 - Multi-Cluster-NiFi-Architecture-Decision-Document.md
    │   └── doc-002 - Multi-Cluster-NiFi-Directory-Structure.md
    └── tasks/                  # Task tracking
```

### Key Directories Explained

#### `shared/` - Shared Resources
- **Purpose**: Resources shared across ALL clusters
- **Contents**: Certificate Authority (CA) only
- **Backup**: CRITICAL - contains CA private key

#### `certs/` - Active Cluster Certificates
- **Purpose**: Certificates for the currently active cluster
- **Generated**: By `certs/generate-certs.sh`
- **Copied to**: `conf/nifi-X/` for mounting into containers

#### `conf/` - Active Cluster Configuration
- **Purpose**: Configuration files for the currently active cluster
- **Generated**: By `conf/generate-cluster-configs.sh`
- **Mounted**: Into containers as read-write volumes

#### `volumes/` - Active Cluster Data
- **Purpose**: Persistent runtime data for the currently active cluster
- **Contents**: NiFi flows, ZooKeeper state, logs, repositories
- **Backup**: Important for preserving flows and data

#### `templates/` - Configuration Templates
- **Purpose**: Master templates for generating cluster configs
- **Used by**: Generation scripts
- **Customization**: Edit templates to change default configurations

## Port Allocation

### Port Calculation Formula

```bash
BASE_PORT = 29000 + (CLUSTER_NUM × 1000)
```

Each cluster gets a **1000-port range**, allowing room for growth and ensuring complete isolation.

### Port Offsets Within Cluster

| Service | Offset | Formula | Example (Cluster 0) |
|---------|--------|---------|---------------------|
| **HTTPS (NiFi UI)** | +443 to +443+N-1 | `BASE_PORT + 443 + (node - 1)` | 29443, 29444, 29445 |
| **ZooKeeper Client** | +181 to +181+N-1 | `BASE_PORT + 181 + (node - 1)` | 29181, 29182, 29183 |
| **Site-to-Site** | +100 to +100+N-1 | `BASE_PORT + 100 + (node - 1)` | 29100, 29101, 29102 |
| **Cluster Protocol** | +82 | `BASE_PORT + 82` (all nodes) | 29082 |
| **Load Balance** | +342 | `BASE_PORT + 342` (all nodes) | 29342 |

*N = Number of nodes in the cluster*

### Port Ranges by Cluster Number

Reference table for the first 10 clusters (3-node configuration):

| Cluster # | Base Port | HTTPS Range | ZooKeeper Range | Site-to-Site | Cluster Proto | Load Balance |
|-----------|-----------|-------------|-----------------|--------------|---------------|--------------|
| **0** | 29000 | 29443-29445 | 29181-29183 | 29100-29102 | 29082 | 29342 |
| **1** | 30000 | 30443-30445 | 30181-30183 | 30100-30102 | 30082 | 30342 |
| **2** | 31000 | 31443-31445 | 31181-31183 | 31100-31102 | 31082 | 31342 |
| **3** | 32000 | 32443-32445 | 32181-32183 | 32100-32102 | 32082 | 32342 |
| **4** | 33000 | 33443-33445 | 33181-33183 | 33100-33102 | 33082 | 33342 |
| **5** | 34000 | 34443-34445 | 34181-34183 | 34100-34102 | 34082 | 34342 |
| **6** | 35000 | 35443-35445 | 35181-35183 | 35100-35102 | 35082 | 35342 |
| **7** | 36000 | 36443-36445 | 36181-36183 | 36100-36102 | 36082 | 36342 |
| **8** | 37000 | 37443-37445 | 37181-37183 | 37100-37102 | 37082 | 37342 |
| **9** | 38000 | 38443-38445 | 38181-38183 | 38100-38102 | 38082 | 38342 |

### Examples

#### Example 1: Production Cluster (Cluster 0, 3 nodes)
```bash
./create-cluster.sh production 0 3
```
- **HTTPS**: 29443, 29444, 29445 → `https://localhost:29443/nifi`
- **ZooKeeper**: 29181, 29182, 29183
- **Site-to-Site**: 29100, 29101, 29102

#### Example 2: Staging Cluster (Cluster 1, 3 nodes)
```bash
./create-cluster.sh staging 1 3
```
- **HTTPS**: 30443, 30444, 30445 → `https://localhost:30443/nifi`
- **ZooKeeper**: 30181, 30182, 30183
- **Site-to-Site**: 30100, 30101, 30102

#### Example 3: Development Cluster (Cluster 2, 2 nodes)
```bash
./create-cluster.sh dev 2 2
```
- **HTTPS**: 31443, 31444 → `https://localhost:31443/nifi`
- **ZooKeeper**: 31181, 31182
- **Site-to-Site**: 31100, 31101

### Avoiding Port Conflicts

1. **Between Clusters**: Use different CLUSTER_NUM values (0, 1, 2, etc.)
2. **With System Services**: Ports below 29000 are avoided
3. **Validation**: Run `./validate-cluster.sh` before deployment
4. **Check Availability**: Use `lsof -i :PORT` or `ss -tlnH | grep :PORT`

## Scripts Documentation

### `create-cluster.sh` - Master Orchestration Script

**Purpose**: One-command cluster creation with full automation.

**Usage**:
```bash
./create-cluster.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
```

**Parameters**:
- `CLUSTER_NAME`: Descriptive name (e.g., 'production', 'staging', 'dev')
- `CLUSTER_NUM`: Cluster number for port calculation (0, 1, 2, ...)
- `NODE_COUNT`: Number of NiFi nodes (1, 2, 3, ...)

**What it does**:
1. Validates prerequisites (Docker, required directories)
2. Creates volume directories for ZooKeeper and NiFi nodes
3. Generates SSL/TLS certificates via `certs/generate-certs.sh`
4. Generates NiFi configuration files via `conf/generate-cluster-configs.sh`
5. Generates `docker-compose.yml` via `generate-docker-compose.sh`
6. Displays access URLs and next steps

**Examples**:
```bash
# Production cluster (3 nodes, cluster #0)
./create-cluster.sh production 0 3

# Staging cluster (3 nodes, cluster #1)
./create-cluster.sh staging 1 3

# Development cluster (2 nodes, cluster #2)
./create-cluster.sh dev 2 2

# Testing cluster (1 node, cluster #3)
./create-cluster.sh testing 3 1
```

**Output**: Generates all necessary files in the root directory for immediate deployment.

---

### `validate-cluster.sh` - Configuration Validation

**Purpose**: Validates cluster configuration before deployment.

**Usage**:
```bash
./validate-cluster.sh [NODE_COUNT]
```

**Parameters**:
- `NODE_COUNT`: Optional - number of nodes to validate (auto-detected if omitted)

**What it validates**:
1. **Directory Structure**: Verifies all required directories exist
2. **Certificates**: Checks CA and node certificates validity
3. **Configuration Files**: Ensures all config files are present
4. **Node Addresses**: Validates nifi.properties node addresses
5. **ZooKeeper Config**: Verifies ZK connect strings
6. **Docker Compose**: Syntax validation and service count
7. **Port Conflicts**: Checks for duplicate or in-use ports

**Examples**:
```bash
# Auto-detect node count from docker-compose.yml
./validate-cluster.sh

# Explicitly validate 3-node cluster
./validate-cluster.sh 3

# Validate after cluster creation
./create-cluster.sh production 0 3 && ./validate-cluster.sh 3
```

**Exit Codes**:
- `0`: All validations passed
- `1`: One or more validations failed

---

### `generate-docker-compose.sh` - Docker Compose Generator

**Purpose**: Generates `docker-compose.yml` from template.

**Usage**:
```bash
./generate-docker-compose.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
```

**What it generates**:
- ZooKeeper ensemble services (N nodes)
- NiFi cluster services (N nodes)
- Docker networks
- Volume mounts
- Port mappings
- Environment variable references

**Template**: `templates/docker-compose.yml.template`

**Output**: `docker-compose.yml` in project root

---

### `certs/generate-certs.sh` - Certificate Generation

**Purpose**: Generates SSL/TLS certificates for cluster nodes.

**Usage**:
```bash
cd certs
./generate-certs.sh <NODE_COUNT>
```

**What it generates**:
- CA certificate (if doesn't exist) in `certs/ca/`
- Per-node certificates in `certs/nifi-{1..N}/`
- Keystores (PKCS12 format)
- Truststores (shared CA trust)

**Certificate Properties**:
- **CA**: CN=NiFi Cluster Root CA
- **Node Certs**: CN=nifi-1, CN=nifi-2, CN=nifi-3
- **Format**: PKCS12 (.p12)
- **Password**: changeme123456 (change in production!)
- **Validity**: 365 days

**Output**: Certificates copied to `conf/nifi-X/` for container mounting

---

### `conf/generate-cluster-configs.sh` - Configuration Generator

**Purpose**: Generates NiFi configuration files from templates.

**Usage**:
```bash
cd conf
./generate-cluster-configs.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
```

**What it generates** (for each node):
- `nifi.properties` - Main NiFi configuration
- `state-management.xml` - ZooKeeper state provider
- `.env` - Environment variables (if generating in root)
- Copies certificates to `conf/nifi-X/`

**Templates Used**:
- `templates/nifi.properties.template`
- `templates/state-management.xml.template`
- `templates/.env.template`

**Variable Substitution**:
- `{{CLUSTER_NAME}}` → Cluster name
- `{{NODE_NUM}}` → Node number (1, 2, 3, ...)
- `{{NODE_COUNT}}` → Total nodes
- `{{BASE_PORT}}` → Calculated base port
- `{{HTTPS_PORT}}` → Node-specific HTTPS port
- `{{ZK_PORT}}` → Node-specific ZK port
- And more...

**Output**: Generated configs in `conf/nifi-{1..N}/`

---

### Script Execution Flow

```
./create-cluster.sh production 0 3
    │
    ├─> [1] Validate prerequisites
    │      └─> Check Docker, Docker Compose, directories, scripts
    │
    ├─> [2] Initialize volumes
    │      └─> Create volumes/zookeeper-{1..3}/
    │      └─> Create volumes/nifi-{1..3}/
    │
    ├─> [3] Generate certificates
    │      └─> Execute certs/generate-certs.sh 3
    │          └─> Generate CA (if needed)
    │          └─> Generate node certificates
    │          └─> Copy to conf/nifi-X/
    │
    ├─> [4] Generate configurations
    │      └─> Execute conf/generate-cluster-configs.sh production 0 3
    │          └─> Generate nifi.properties (3 files)
    │          └─> Generate state-management.xml (3 files)
    │          └─> Copy certificates to conf/
    │
    ├─> [5] Generate docker-compose.yml
    │      └─> Execute generate-docker-compose.sh production 0 3
    │          └─> Process template with substitutions
    │          └─> Write docker-compose.yml
    │
    └─> [✓] Display success message and next steps
```

## Configuration Management

### Environment Variables (.env)

Generated by `create-cluster.sh`, customizable before starting cluster:

```bash
# Cluster Identity
CLUSTER_NAME=production
CLUSTER_NUM=0
NODE_COUNT=3

# NiFi Version
NIFI_VERSION=latest
ZOOKEEPER_VERSION=3.9

# Authentication
NIFI_SINGLE_USER_USERNAME=admin
NIFI_SINGLE_USER_PASSWORD=changeme123456

# JVM Settings
NIFI_JVM_HEAP_INIT=2g
NIFI_JVM_HEAP_MAX=2g

# Certificates
KEYSTORE_PASSWORD=changeme123456
TRUSTSTORE_PASSWORD=changeme123456
```

**Security Note**: Change default passwords before production deployment!

### NiFi Properties

Key properties customized per cluster:

```properties
# Node Identity
nifi.cluster.node.address=nifi-1
nifi.remote.input.host=nifi-1

# ZooKeeper Connection
nifi.zookeeper.connect.string=zookeeper-1:2181,zookeeper-2:2181,zookeeper-3:2181

# Cluster Coordination
nifi.cluster.is.node=true
nifi.cluster.protocol.is.secure=true

# Ports
nifi.web.https.port=8443
nifi.cluster.protocol.port=8082
nifi.cluster.load.balance.port=6342

# Security
nifi.security.keystore=/opt/nifi/nifi-current/conf/keystore.p12
nifi.security.truststore=/opt/nifi/nifi-current/conf/truststore.p12
```

### Modifying Configuration

**After cluster creation**:

1. Edit `.env` to change environment variables
2. Edit `conf/nifi-X/nifi.properties` to change node-specific settings
3. Restart cluster: `docker compose restart`

**For new clusters**:

1. Edit templates in `templates/`
2. Regenerate cluster configuration
3. Redeploy

## Troubleshooting

### Cluster Won't Start

**Symptoms**: Services fail to start or crash immediately

**Diagnosis**:
```bash
# Check service status
docker compose ps

# View logs
docker compose logs -f nifi-1 nifi-2 nifi-3
docker compose logs -f zookeeper-1 zookeeper-2 zookeeper-3
```

**Common Causes**:

1. **Port conflicts**:
   ```bash
   ./validate-cluster.sh
   lsof -i :29443  # Check specific port
   ```

2. **ZooKeeper not ready**:
   ```bash
   docker compose logs zookeeper-1
   # Wait for "binding to port 0.0.0.0/0.0.0.0:2181"
   ```

3. **Certificate issues**:
   ```bash
   # Verify certificates
   openssl x509 -in certs/nifi-1/server-cert.pem -text -noout

   # Regenerate if needed
   cd certs && ./generate-certs.sh 3
   ```

4. **Insufficient resources**:
   ```bash
   docker stats  # Check CPU/memory usage
   # Reduce JVM heap in .env
   ```

---

### Node Not Joining Cluster

**Symptoms**: Node starts but doesn't appear in cluster UI

**Diagnosis**:
```bash
# Check node logs for clustering errors
docker compose logs -f nifi-1 | grep -i "cluster\|coordinator"

# Check ZooKeeper connectivity
docker compose exec nifi-1 nc -zv zookeeper-1 2181
```

**Solutions**:

1. **Check node address**:
   ```bash
   grep "nifi.cluster.node.address" conf/nifi-1/nifi.properties
   # Should be: nifi.cluster.node.address=nifi-1
   ```

2. **Verify ZK connect string**:
   ```bash
   grep "nifi.zookeeper.connect.string" conf/nifi-1/nifi.properties
   # Should list all ZK nodes
   ```

3. **Check firewall/network**:
   ```bash
   docker compose exec nifi-1 ping nifi-2
   docker compose exec nifi-1 ping zookeeper-1
   ```

4. **Restart problematic node**:
   ```bash
   docker compose restart nifi-1
   ```

---

### Certificate Errors

**Symptoms**: SSL/TLS errors in logs, can't access UI

**Diagnosis**:
```bash
# Verify CA certificate
openssl x509 -in shared/certs/ca/ca-cert.pem -text -noout

# Verify node certificate
openssl x509 -in conf/nifi-1/server-cert.pem -text -noout 2>/dev/null || \
openssl pkcs12 -in conf/nifi-1/keystore.p12 -nokeys -passin pass:changeme123456

# Test certificate chain
openssl verify -CAfile shared/certs/ca/ca-cert.pem certs/nifi-1/server-cert.pem
```

**Solutions**:

1. **Regenerate certificates**:
   ```bash
   cd certs
   ./generate-certs.sh 3
   cd ..
   docker compose restart
   ```

2. **Check certificate password**:
   ```bash
   grep "KEYSTORE_PASSWORD" .env
   grep "nifi.security.keystorePasswd" conf/nifi-1/nifi.properties
   # Must match!
   ```

---

### Port Already in Use

**Symptoms**: "port is already allocated" error

**Diagnosis**:
```bash
# Check what's using the port
lsof -i :29443
ss -tlnp | grep :29443
netstat -tulpn | grep :29443
```

**Solutions**:

1. **Use different cluster number**:
   ```bash
   ./create-cluster.sh production 1 3  # Uses ports 30443+
   ```

2. **Stop conflicting service**:
   ```bash
   docker compose down  # If it's another NiFi cluster
   ```

3. **Change ports manually** (not recommended):
   Edit `docker-compose.yml` port mappings

---

### Performance Issues

**Symptoms**: Slow UI, high CPU/memory usage

**Diagnosis**:
```bash
# Check resource usage
docker stats

# Check JVM heap usage in logs
docker compose logs nifi-1 | grep -i "heap\|memory\|gc"
```

**Solutions**:

1. **Increase JVM heap**:
   ```bash
   # Edit .env
   NIFI_JVM_HEAP_INIT=4g
   NIFI_JVM_HEAP_MAX=4g

   # Restart
   docker compose restart
   ```

2. **Reduce concurrent tasks**:
   In NiFi UI → Processor → Configure → Concurrent Tasks

3. **Clean up old data**:
   ```bash
   # Clean provenance data
   docker compose exec nifi-1 rm -rf /opt/nifi/nifi-current/provenance_repository/*
   ```

---

### Validation Failures

**Symptoms**: `./validate-cluster.sh` reports errors

**Common Issues**:

1. **Missing directories**:
   ```bash
   ./create-cluster.sh production 0 3  # Regenerate
   ```

2. **Wrong node addresses**:
   ```bash
   cd conf
   ./generate-cluster-configs.sh production 0 3
   ```

3. **Docker Compose syntax errors**:
   ```bash
   ./generate-docker-compose.sh production 0 3
   docker compose config  # Validate syntax
   ```

---

### Logs and Debugging

**View all logs**:
```bash
docker compose logs -f
```

**View specific service**:
```bash
docker compose logs -f nifi-1
docker compose logs -f zookeeper-1
```

**Follow last 100 lines**:
```bash
docker compose logs --tail=100 -f nifi-1
```

**Search logs**:
```bash
docker compose logs nifi-1 | grep -i "error\|exception\|fail"
docker compose logs nifi-1 | grep -i "cluster\|coordinator"
```

**Access container shell**:
```bash
docker compose exec nifi-1 /bin/bash
```

**Check NiFi internal logs**:
```bash
docker compose exec nifi-1 tail -f /opt/nifi/nifi-current/logs/nifi-app.log
```

## Migration Guide

### From Single-Cluster to Multi-Cluster

If you have an existing single-cluster setup (from the old README), follow these steps:

#### Step 1: Backup Existing Cluster

```bash
# Stop current cluster
docker compose down

# Backup everything
tar -czf nifi-backup-$(date +%Y%m%d).tar.gz \
    volumes/ conf/ certs/ docker-compose.yml .env
```

#### Step 2: Reorganize Directory Structure

The new multi-cluster system expects:
- Shared CA in `shared/certs/ca/`
- Active cluster files in root (certs/, conf/, volumes/)

Your existing structure should work with minimal changes:

```bash
# Create shared CA directory
mkdir -p shared/certs/ca

# Copy CA files (if you have them in certs/ca/)
cp certs/ca/ca-*.pem shared/certs/ca/ 2>/dev/null || true
cp certs/ca/truststore.* shared/certs/ca/ 2>/dev/null || true

# Your existing certs/, conf/, volumes/ become the "active cluster" (cluster 0)
```

#### Step 3: Generate Configuration for Existing Cluster

```bash
# Regenerate as "production" cluster #0 with existing node count
./create-cluster.sh production 0 3

# This will:
# - Keep your existing volumes/
# - Regenerate certs/ and conf/ with multi-cluster conventions
# - Create new docker-compose.yml
```

#### Step 4: Review and Adjust

```bash
# Review new .env
cat .env

# Compare with old environment variables
# Transfer any custom settings from old .env to new .env

# Validate configuration
./validate-cluster.sh 3
```

#### Step 5: Restart Cluster

```bash
docker compose up -d
```

**Important Notes**:
- Your **NiFi flows are preserved** in `volumes/nifi-X/`
- **ZooKeeper state is preserved** in `volumes/zookeeper-X/`
- **Certificates are regenerated** - old certs no longer work
- **Port numbers may change** - cluster 0 uses ports 29443+ (old setup used 30443+)

### Port Migration

If your old setup used different ports:

**Old Ports** (from old README):
- HTTPS: 30443, 30444, 30445
- ZooKeeper: 30181, 30182, 30183

**New Ports** (cluster 0):
- HTTPS: 29443, 29444, 29445
- ZooKeeper: 29181, 29182, 29183

**To keep old ports**: Use cluster #1 instead:
```bash
./create-cluster.sh production 1 3
# Uses ports 30443-30445 (matches old setup)
```

## Advanced Usage

### Multiple Clusters on One Host

```bash
# Production environment (cluster 0)
./create-cluster.sh production 0 3
docker compose up -d
# Access: https://localhost:29443/nifi

# Staging environment (cluster 1) - requires separate deployment
# Note: You'll need to manage each cluster in its own directory
# or use the clusters/ structure described in doc-002
```

**Current Limitation**: The scripts generate configuration in the root directory, so you can only run one cluster at a time from this location. For true multi-cluster, you would need to:

1. Create separate directories for each cluster
2. Run `create-cluster.sh` in each directory
3. Or extend the system to use the `clusters/` structure from the architecture docs

See `backlog/docs/doc-002 - Multi-Cluster-NiFi-Directory-Structure.md` for the planned multi-directory structure.

### Custom Node Count

```bash
# Single-node cluster (for development/testing)
./create-cluster.sh dev 0 1

# Two-node cluster
./create-cluster.sh staging 1 2

# Five-node cluster (large production)
./create-cluster.sh production-large 2 5
```

### Custom JVM Settings

Edit `.env` before starting:
```bash
# For small cluster (2GB heap)
NIFI_JVM_HEAP_INIT=2g
NIFI_JVM_HEAP_MAX=2g

# For large cluster (8GB heap)
NIFI_JVM_HEAP_INIT=8g
NIFI_JVM_HEAP_MAX=8g
```

### Backup and Recovery

**Backup critical data**:
```bash
# Stop cluster
docker compose down

# Backup everything
tar -czf nifi-cluster-backup-$(date +%Y%m%d).tar.gz \
    shared/ certs/ conf/ volumes/ .env docker-compose.yml

# Or backup just flows and data
tar -czf nifi-data-backup-$(date +%Y%m%d).tar.gz volumes/
```

**Restore from backup**:
```bash
# Stop cluster
docker compose down

# Restore files
tar -xzf nifi-cluster-backup-YYYYMMDD.tar.gz

# Start cluster
docker compose up -d
```

**Backup shared CA** (CRITICAL):
```bash
# Backup CA private key
tar -czf ca-backup-$(date +%Y%m%d).tar.gz shared/certs/ca/
# Store securely offline!
```

### Cluster Management

**View status**:
```bash
docker compose ps
```

**Stop cluster**:
```bash
docker compose down
```

**Stop and remove volumes** (CAUTION - deletes all data):
```bash
docker compose down -v
```

**Restart services**:
```bash
docker compose restart
docker compose restart nifi-1  # Single node
```

**Scale cluster** (add nodes):
```bash
# Regenerate with more nodes
./create-cluster.sh production 0 5  # Now 5 nodes instead of 3
docker compose down
docker compose up -d
```

**Update NiFi version**:
```bash
# Edit .env
NIFI_VERSION=2.0.0

# Restart
docker compose down
docker compose up -d
```

## Resources

### Documentation

- [Apache NiFi Official Docs](https://nifi.apache.org/docs.html)
- [NiFi Administration Guide](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html)
- [NiFi Clustering Guide](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#clustering)
- [ZooKeeper Documentation](https://zookeeper.apache.org/doc/current/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

### Project Documentation

- [`backlog/docs/doc-001`](backlog/docs/doc-001%20-%20Multi-Cluster-NiFi-Architecture-Decision-Document.md) - Architecture Decision Document
- [`backlog/docs/doc-002`](backlog/docs/doc-002%20-%20Multi-Cluster-NiFi-Directory-Structure.md) - Directory Structure Guide
- [`certs/README.md`](certs/README.md) - Certificate Management Guide
- [`conf/README.md`](conf/README.md) - Configuration Management Guide

### Community

- [Apache NiFi Mailing Lists](https://nifi.apache.org/mailing_lists.html)
- [NiFi Slack](https://apachenifi.slack.com/)
- [Stack Overflow - apache-nifi](https://stackoverflow.com/questions/tagged/apache-nifi)

## Security Best Practices

1. **Change Default Passwords**:
   - Edit `.env` before first start
   - Use strong, unique passwords
   - Never commit `.env` to version control

2. **Protect CA Private Key**:
   - Backup `shared/certs/ca/ca-key.pem` securely offline
   - Restrict file permissions: `chmod 600 shared/certs/ca/ca-key.pem`

3. **Use HTTPS Only**:
   - All clusters use HTTPS by default
   - Never expose HTTP ports

4. **Production Authentication**:
   - Replace single-user auth with LDAP or OIDC
   - Configure in `nifi.properties`

5. **Network Security**:
   - Use firewall to restrict access to NiFi ports
   - Consider reverse proxy (Nginx/Traefik) for production

6. **Regular Updates**:
   - Keep NiFi and ZooKeeper versions current
   - Monitor security advisories

7. **Secrets Management**:
   - Use Docker secrets or HashiCorp Vault for production
   - Never commit secrets to Git

## License

This configuration is provided as-is for use with Apache NiFi and Apache ZooKeeper.
- Apache NiFi: [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)
- Apache ZooKeeper: [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)

## Contributing

Contributions welcome! Please:
1. Review architecture docs in `backlog/docs/`
2. Check existing tasks in `backlog/tasks/`
3. Follow the established patterns and conventions
4. Test changes thoroughly with `validate-cluster.sh`

---

**Quick Commands Reference**:

```bash
# Create cluster
./create-cluster.sh production 0 3

# Validate
./validate-cluster.sh

# Start
docker compose up -d

# Logs
docker compose logs -f

# Stop
docker compose down

# Access
open https://localhost:29443/nifi
```

**Default Credentials**: `admin` / `changeme123456`
