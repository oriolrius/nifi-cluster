---
id: doc-006
title: create-cluster.sh - Complete Architecture Documentation
type: other
created_date: '2025-11-13 14:07'
updated_date: '2025-11-13 15:07'
---
# create-cluster.sh - Complete Architecture Documentation

## Overview

`create-cluster.sh` is the master orchestration script that automates the complete setup of a NiFi cluster including ZooKeeper ensemble, SSL/TLS certificates, configuration files, and Docker Compose orchestration.

## Script Hierarchy & Dependency Tree

```
create-cluster.sh (Master Orchestrator)
├── Prerequisites Validation
│   ├── Docker installation check
│   ├── Docker Compose availability check
│   └── Required directory structure validation (certs/, conf/)
│
├── lib/cluster-utils.sh (Utility Library - Optional)
│   ├── get_cluster_num() - Extract cluster number from name
│   ├── get_base_port() - Calculate base port from cluster number
│   ├── get_https_port() - Calculate HTTPS port for node
│   ├── get_node_count() - Count nodes in cluster
│   ├── get_cluster_containers() - List running containers
│   ├── cluster_exists() - Check if cluster config exists
│   ├── get_all_clusters() - List available clusters
│   ├── cluster_is_running() - Check cluster running status
│   ├── get_cluster_status() - Get cluster status
│   ├── print_cluster_info() - Display cluster information
│   ├── validate_cluster_name() - Validate naming format
│   ├── get_cluster_url() - Get NiFi API URL
│   └── wait_for_cluster() - Wait for cluster readiness
│
├── Step 1: Validate Prerequisites
│   └── Check for required scripts executability
│
├── Step 2: Initialize Cluster Workspace
│   ├── Create cluster directory structure: clusters/<CLUSTER_NAME>/
│   ├── Create volume directories (data persistence)
│   │   ├── ZooKeeper volumes: data/, datalog/, logs/
│   │   └── NiFi volumes: content_repository/, database_repository/,
│   │                      flowfile_repository/, provenance_repository/,
│   │                      state/, logs/
│   └── Set ownership (UID:GID 1000:1000)
│
├── Step 3: Generate SSL/TLS Certificates
│   │
│   └── certs/generate-certs.sh <NODE_COUNT> <OUTPUT_DIR> <CLUSTER_NAME>
│       ├── Reads: ../.env (for DOMAIN variable)
│       ├── Uses: Shared CA from certs/ca/ (or creates if missing)
│       │   ├── ca-key.pem - Root CA private key
│       │   ├── ca-cert.pem - Root CA certificate
│       │   ├── truststore.jks - Java KeyStore truststore
│       │   └── truststore.p12 - PKCS12 truststore
│       │
│       ├── Generates for each NiFi node (CN=<CLUSTER_NAME>.nifi-<N>):
│       │   ├── server-key.pem - Node private key (2048-bit RSA)
│       │   ├── server.csr - Certificate signing request
│       │   ├── san.cnf - Subject Alternative Names configuration
│       │   │   └── DNS: <CLUSTER_NAME>.nifi-<N>, nifi-<N>, localhost,
│       │   │            <CLUSTER_NAME>.nifi-<N>.<DOMAIN> (if DOMAIN set)
│       │   │   └── IP: 127.0.0.1
│       │   ├── server-cert.pem - Signed certificate
│       │   ├── cert-chain.pem - Certificate + CA chain
│       │   ├── keystore.p12 - PKCS12 keystore
│       │   ├── keystore.jks - Java KeyStore
│       │   ├── truststore.jks - Copy of CA truststore
│       │   └── truststore.p12 - Copy of CA truststore
│       │
│       └── Generates for each ZooKeeper node (CN=<CLUSTER_NAME>.zookeeper-<N>):
│           └── Same certificate structure as NiFi nodes
│
├── Step 4: Generate NiFi Configuration Files
│   │
│   └── conf/generate-cluster-configs.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT> <OUTPUT_DIR> <CERTS_DIR>
│       ├── Reads: ../.env (for DOMAIN variable)
│       ├── Calculates port assignments from CLUSTER_NUM:
│       │   ├── BASE_PORT = 29000 + (CLUSTER_NUM × 1000)
│       │   ├── HTTPS_BASE = BASE_PORT + 443
│       │   ├── S2S_BASE = BASE_PORT + 100
│       │   ├── CLUSTER_PROTOCOL_BASE = BASE_PORT + 82
│       │   └── LOAD_BALANCE_BASE = BASE_PORT + 342
│       │
│       ├── Builds ZooKeeper connect string:
│       │   └── "<CLUSTER_NAME>.zookeeper-1:2181,<CLUSTER_NAME>.zookeeper-2:2181,..."
│       │
│       ├── Builds proxy host string (for web access):
│       │   └── "localhost:30443,localhost:30444,...,<CLUSTER_NAME>.nifi-1:30443,..."
│       │
│       ├── For each node, generates:
│       │   ├── <CLUSTER_NAME>.nifi-<N>/nifi.properties
│       │   │   ├── Core Properties: Flow configuration, repositories
│       │   │   ├── State Management: ZooKeeper configuration
│       │   │   ├── Site-to-Site Configuration:
│       │   │   │   └── nifi.remote.input.host = <CLUSTER_NAME>.nifi-<N>.<DOMAIN>
│       │   │   │       (Uses FQDN if DOMAIN set, for cross-cluster S2S)
│       │   │   ├── Web Properties: HTTPS configuration, proxy hosts
│       │   │   ├── Security Properties: SSL/TLS keystore/truststore paths
│       │   │   ├── Cluster Properties: Node address, protocol ports
│       │   │   ├── Load Balancing: Configuration
│       │   │   └── ZooKeeper: Connect string, timeouts
│       │   │
│       │   ├── <CLUSTER_NAME>.nifi-<N>/state-management.xml
│       │   │   ├── local-provider: WriteAheadLocalStateProvider
│       │   │   └── cluster-provider: ZooKeeperStateProvider
│       │   │
│       │   └── Copies from conf/templates/ (if available):
│       │       ├── authorizers.xml - Authorization policies
│       │       ├── bootstrap.conf - JVM bootstrap configuration
│       │       ├── logback.xml - Logging configuration
│       │       ├── login-identity-providers.xml - Authentication config
│       │       └── zookeeper.properties - ZooKeeper client config
│       │
│       └── Copies certificates from CERTS_DIR to config directories
│
└── Step 5: Generate Docker Compose File
    │
    └── generate-docker-compose.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT> [REMOTE_CLUSTER_NAME] [REMOTE_NODE_COUNT] [HOST_IP]
        ├── Reads: .env (for DOMAIN variable)
        ├── Calculates same port assignments as Step 4
        ├── Builds ZooKeeper servers string for ZOO_SERVERS environment variable
        ├── Generates: docker-compose-<CLUSTER_NAME>.yml
        │
        ├── ZooKeeper Services (for each node):
        │   ├── Image: zookeeper:${ZOOKEEPER_VERSION:-3.9}
        │   ├── Container name: <CLUSTER_NAME>.zookeeper-<N>
        │   ├── Hostname: <CLUSTER_NAME>.zookeeper-<N>
        │   ├── Network: <CLUSTER_NAME>-network (isolated bridge network)
        │   ├── Ports: <ZK_BASE + N - 1>:2181 (mapped to host)
        │   ├── Environment:
        │   │   ├── ZOO_MY_ID: <N>
        │   │   ├── ZOO_SERVERS: "server.1=...:2888:3888;2181 server.2=..."
        │   │   ├── ZOO_4LW_COMMANDS_WHITELIST: "*"
        │   │   ├── ZOO_TICK_TIME: 2000
        │   │   ├── ZOO_INIT_LIMIT: 10
        │   │   ├── ZOO_SYNC_LIMIT: 5
        │   │   └── ZOO_MAX_CLIENT_CNXNS: 60
        │   ├── Volumes (host bind mounts):
        │   │   ├── ./clusters/<CLUSTER_NAME>/volumes/<CLUSTER_NAME>.zookeeper-<N>/data
        │   │   ├── ./clusters/<CLUSTER_NAME>/volumes/<CLUSTER_NAME>.zookeeper-<N>/datalog
        │   │   └── ./clusters/<CLUSTER_NAME>/volumes/<CLUSTER_NAME>.zookeeper-<N>/logs
        │   ├── Extra_hosts (if REMOTE_CLUSTER_NAME provided):
        │   │   └── "<REMOTE_CLUSTER_NAME>.nifi-<M>:<HOST_IP>" for cross-cluster DNS
        │   └── Restart: unless-stopped
        │
        ├── NiFi Services (for each node):
        │   ├── Image: apache/nifi:${NIFI_VERSION:-latest}
        │   ├── Container name: <CLUSTER_NAME>.nifi-<N>
        │   ├── Hostname: <CLUSTER_NAME>.nifi-<N>
        │   ├── Network: <CLUSTER_NAME>-network
        │   ├── Ports (mapped to host):
        │   │   ├── <HTTPS_BASE + N - 1>:<HTTPS_BASE + N - 1> (HTTPS UI)
        │   │   └── <S2S_BASE + N - 1>:<S2S_BASE + N - 1> (Site-to-Site)
        │   ├── Environment:
        │   │   ├── NIFI_CLUSTER_IS_NODE: "true"
        │   │   ├── NIFI_CLUSTER_NODE_PROTOCOL_PORT: 8082
        │   │   ├── NIFI_CLUSTER_NODE_ADDRESS: <CLUSTER_NAME>.nifi-<N>
        │   │   ├── NIFI_ZK_CONNECT_STRING: "<ZK_CONNECT>"
        │   │   ├── NIFI_ELECTION_MAX_WAIT: 1 min
        │   │   ├── NIFI_WEB_HTTPS_PORT: <HTTPS_BASE + N - 1>
        │   │   ├── NIFI_WEB_HTTPS_HOST: <CLUSTER_NAME>.nifi-<N>
        │   │   ├── NIFI_WEB_HTTPS_NETWORK_INTERFACE_DEFAULT: eth0
        │   │   ├── NIFI_WEB_PROXY_HOST: Node-specific proxy host string with FQDN
        │   │   ├── SINGLE_USER_CREDENTIALS_USERNAME: ${NIFI_SINGLE_USER_USERNAME:-admin}
        │   │   ├── SINGLE_USER_CREDENTIALS_PASSWORD: ${NIFI_SINGLE_USER_PASSWORD:-changeme123456}
        │   │   ├── NIFI_STATE_MANAGEMENT_EMBEDDED_ZOOKEEPER_START: "false"
        │   │   ├── NIFI_JVM_HEAP_INIT: ${NIFI_JVM_HEAP_INIT:-2g}
        │   │   └── NIFI_JVM_HEAP_MAX: ${NIFI_JVM_HEAP_MAX:-2g}
        │   ├── Volumes (host bind mounts):
        │   │   ├── ./clusters/<CLUSTER_NAME>/conf/<CLUSTER_NAME>.nifi-<N>:/opt/nifi/nifi-current/conf:rw
        │   │   ├── ./clusters/<CLUSTER_NAME>/volumes/<CLUSTER_NAME>.nifi-<N>/content_repository
        │   │   ├── ./clusters/<CLUSTER_NAME>/volumes/<CLUSTER_NAME>.nifi-<N>/database_repository
        │   │   ├── ./clusters/<CLUSTER_NAME>/volumes/<CLUSTER_NAME>.nifi-<N>/flowfile_repository
        │   │   ├── ./clusters/<CLUSTER_NAME>/volumes/<CLUSTER_NAME>.nifi-<N>/provenance_repository
        │   │   ├── ./clusters/<CLUSTER_NAME>/volumes/<CLUSTER_NAME>.nifi-<N>/state
        │   │   └── ./clusters/<CLUSTER_NAME>/volumes/<CLUSTER_NAME>.nifi-<N>/logs
        │   ├── Depends_on: All ZooKeeper services
        │   ├── Extra_hosts (if REMOTE_CLUSTER_NAME provided):
        │   │   └── "<REMOTE_CLUSTER_NAME>.nifi-<M>:<HOST_IP>" for cross-cluster S2S
        │   └── Restart: unless-stopped
        │
        └── Networks:
            └── <CLUSTER_NAME>-network:
                ├── Driver: bridge
                └── Enable IPv6: false

```

## Parameters

### Required Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `CLUSTER_NAME` | String | Descriptive cluster identifier | `cluster01`, `cluster02` |
| `CLUSTER_NUM` | Integer ≥ 0 | Numeric cluster identifier for port calculation | `1`, `2`, `3` |
| `NODE_COUNT` | Integer ≥ 1 | Number of nodes in cluster (both NiFi and ZooKeeper) | `3`, `5` |

### Port Calculation Formula

```
BASE_PORT = 29000 + (CLUSTER_NUM × 1000)

HTTPS Ports:         BASE_PORT + 443 + (node_index - 1)
ZooKeeper Ports:     BASE_PORT + 181 + (node_index - 1)
Site-to-Site Ports:  BASE_PORT + 100 + (node_index - 1)
Cluster Protocol:    BASE_PORT + 82 (all nodes)
Load Balance:        BASE_PORT + 342 (all nodes)
```

**Examples:**
- `cluster01` (CLUSTER_NUM=1): BASE_PORT=30000, HTTPS: 30443-30445, ZK: 30181-30183
- `cluster02` (CLUSTER_NUM=2): BASE_PORT=31000, HTTPS: 31443-31445, ZK: 31181-31183
- `cluster03` (CLUSTER_NUM=3): BASE_PORT=32000, HTTPS: 32443-32445, ZK: 32181-32183

## Configuration Files & Environment Variables

### .env File (Project Root)

Read by multiple scripts to configure cross-cluster communication:

```bash
# Domain for FQDN resolution (critical for Site-to-Site)
DOMAIN=ymbihq.local

# NiFi Authentication (Single User Mode)
NIFI_SINGLE_USER_USERNAME=admin
NIFI_SINGLE_USER_PASSWORD=changeme123456

# Container Images
NIFI_VERSION=latest
ZOOKEEPER_VERSION=3.9

# JVM Memory
NIFI_JVM_HEAP_INIT=2g
NIFI_JVM_HEAP_MAX=2g
```

**DOMAIN Variable Importance:**
- Used in `generate-certs.sh` to add FQDN to certificate SANs
- Used in `generate-cluster-configs.sh` to set `nifi.remote.input.host`
- Used in `generate-docker-compose.sh` to configure `NIFI_WEB_PROXY_HOST`
- **Critical for cross-cluster Site-to-Site communication**

### Generated Configuration Files

#### Per-Node Configuration (clusters/<CLUSTER_NAME>/conf/<CLUSTER_NAME>.nifi-<N>/)

```
<CLUSTER_NAME>.nifi-<N>/
├── nifi.properties                 # Main NiFi configuration (generated)
├── state-management.xml             # State management with ZooKeeper (generated)
├── keystore.p12                     # Node SSL/TLS keystore (copied)
├── truststore.p12                   # CA truststore (copied)
├── authorizers.xml                  # Authorization policies (template copy)
├── bootstrap.conf                   # JVM bootstrap (template copy)
├── logback.xml                      # Logging configuration (template copy)
├── login-identity-providers.xml     # Authentication providers (template copy)
├── zookeeper.properties             # ZooKeeper client config (template copy)
└── archive/                         # Flow configuration archives
```

#### Key nifi.properties Settings

```properties
# Node Identity (cluster-namespaced)
nifi.cluster.node.address=${CLUSTER_NAME}.nifi-${i}

# Site-to-Site (uses FQDN if DOMAIN set for cross-cluster S2S)
nifi.remote.input.host=${CLUSTER_NAME}.nifi-${i}.${DOMAIN}
nifi.remote.input.secure=true
nifi.remote.input.socket.port=${S2S_PORT}
nifi.remote.input.http.enabled=true

# HTTPS Configuration
nifi.web.https.host=0.0.0.0
nifi.web.https.port=${HTTPS_PORT}
nifi.web.proxy.host=${PROXY_HOST_STRING}  # All node URLs

# SSL/TLS Keystores
nifi.security.keystore=/opt/nifi/nifi-current/conf/keystore.p12
nifi.security.keystoreType=PKCS12
nifi.security.keystorePasswd=changeme123456
nifi.security.truststore=/opt/nifi/nifi-current/conf/truststore.p12
nifi.security.truststoreType=PKCS12
nifi.security.truststorePasswd=changeme123456

# Cluster Configuration
nifi.cluster.is.node=true
nifi.cluster.node.protocol.port=${CLUSTER_PROTOCOL_BASE}
nifi.cluster.protocol.is.secure=true

# ZooKeeper
nifi.zookeeper.connect.string=${ZK_CONNECT_STRING}
nifi.zookeeper.root.node=/nifi
```

## Directory Structure Created

```
clusters/<CLUSTER_NAME>/
├── volumes/                         # Runtime data (bind-mounted)
│   ├── <CLUSTER_NAME>.zookeeper-1/
│   │   ├── data/                   # ZooKeeper data
│   │   ├── datalog/                # ZooKeeper transaction logs
│   │   └── logs/                   # ZooKeeper logs
│   ├── <CLUSTER_NAME>.zookeeper-2/
│   ├── <CLUSTER_NAME>.zookeeper-3/
│   ├── <CLUSTER_NAME>.nifi-1/
│   │   ├── content_repository/     # FlowFile content
│   │   ├── database_repository/    # Internal database
│   │   ├── flowfile_repository/    # FlowFile metadata
│   │   ├── provenance_repository/  # Provenance events
│   │   ├── state/                  # Component state
│   │   └── logs/                   # NiFi logs
│   ├── <CLUSTER_NAME>.nifi-2/
│   └── <CLUSTER_NAME>.nifi-3/
├── conf/                            # Configuration files
│   ├── <CLUSTER_NAME>.nifi-1/      # Node 1 config + certs
│   ├── <CLUSTER_NAME>.nifi-2/      # Node 2 config + certs
│   └── <CLUSTER_NAME>.nifi-3/      # Node 3 config + certs
└── certs/                           # Certificates (source)
    ├── ca/                          # Certificate Authority
    │   ├── ca-key.pem              # CA private key (shared across all clusters)
    │   ├── ca-cert.pem             # CA certificate
    │   ├── truststore.jks          # Java KeyStore truststore
    │   └── truststore.p12          # PKCS12 truststore
    ├── <CLUSTER_NAME>.nifi-1/      # Node 1 certificates
    │   ├── server-key.pem          # Private key
    │   ├── server-cert.pem         # Certificate
    │   ├── cert-chain.pem          # Certificate chain
    │   ├── keystore.p12            # PKCS12 keystore
    │   ├── keystore.jks            # Java KeyStore
    │   ├── truststore.p12          # PKCS12 truststore
    │   └── truststore.jks          # Java KeyStore truststore
    ├── <CLUSTER_NAME>.nifi-2/
    ├── <CLUSTER_NAME>.nifi-3/
    ├── <CLUSTER_NAME>.zookeeper-1/  # ZooKeeper certificates
    ├── <CLUSTER_NAME>.zookeeper-2/
    └── <CLUSTER_NAME>.zookeeper-3/
```

## Execution Flow

### 1. Prerequisites Validation
- Checks Docker and Docker Compose installation
- Validates required directories exist (certs/, conf/)
- Verifies required scripts are executable:
  - `certs/generate-certs.sh`
  - `conf/generate-cluster-configs.sh`
  - `generate-docker-compose.sh`

### 2. Workspace Initialization
- Creates `clusters/<CLUSTER_NAME>/` directory structure
- Creates volume subdirectories for each ZooKeeper node
- Creates volume subdirectories for each NiFi node
- Sets ownership to UID:GID 1000:1000 (standard for containers)

### 3. Certificate Generation
- Calls `certs/generate-certs.sh`
- Checks for shared CA in `certs/ca/` (reuses if exists)
- Creates new CA if none exists (shared across all clusters)
- Generates node-specific certificates for NiFi nodes
- Generates node-specific certificates for ZooKeeper nodes
- Creates both PKCS12 and JKS keystores/truststores
- Includes SANs with FQDN if DOMAIN is set in .env

### 4. Configuration Generation
- Calls `conf/generate-cluster-configs.sh`
- Reads DOMAIN from .env for FQDN configuration
- Calculates all port assignments
- Generates `nifi.properties` for each node with:
  - Unique node address and FQDN-based S2S host
  - Node-specific ports
  - Shared cluster configuration
  - SSL/TLS certificate paths
- Generates `state-management.xml` with ZooKeeper configuration
- Copies template files from `conf/templates/`
- Copies certificates to config directories

### 5. Docker Compose Generation
- Calls `generate-docker-compose.sh`
- Creates `docker-compose-<CLUSTER_NAME>.yml`
- Defines ZooKeeper ensemble services
- Defines NiFi cluster node services
- Configures isolated bridge network
- Maps ports to host
- Mounts volumes and configuration directories
- Sets environment variables (includes FQDN in proxy hosts if DOMAIN set)
- Optionally adds extra_hosts for cross-cluster communication

## Usage Examples

### Single Cluster (3 nodes)
```bash
./create-cluster.sh cluster01 1 3
```

This creates:
- 3 ZooKeeper nodes: cluster01.zookeeper-{1,2,3}
- 3 NiFi nodes: cluster01.nifi-{1,2,3}
- HTTPS ports: 30443, 30444, 30445
- ZooKeeper ports: 30181, 30182, 30183
- S2S ports: 30100, 30101, 30102
- Network: cluster01-network
- Workspace: clusters/cluster01/

### Second Cluster (3 nodes) for Site-to-Site
```bash
./create-cluster.sh cluster02 2 3
```

This creates:
- 3 ZooKeeper nodes: cluster02.zookeeper-{1,2,3}
- 3 NiFi nodes: cluster02.nifi-{1,2,3}
- HTTPS ports: 31443, 31444, 31445
- ZooKeeper ports: 31181, 31182, 31183
- S2S ports: 31100, 31101, 31102
- Network: cluster02-network (isolated from cluster01)
- Workspace: clusters/cluster02/

### Cross-Cluster Communication

For Site-to-Site between clusters, you need:

1. **DOMAIN set in .env:**
   ```bash
   DOMAIN=ymbihq.local
   ```

2. **DNS resolution or extra_hosts** for FQDNs like:
   - `cluster01.nifi-1.ymbihq.local`
   - `cluster02.nifi-1.ymbihq.local`

3. **Regenerate docker-compose with extra_hosts:**
   ```bash
   # From cluster01, add cluster02 hosts
   ./generate-docker-compose.sh cluster01 1 3 cluster02 3 <CLUSTER02_HOST_IP>
   
   # From cluster02, add cluster01 hosts  
   ./generate-docker-compose.sh cluster02 2 3 cluster01 3 <CLUSTER01_HOST_IP>
   ```

## Security Considerations

### SSL/TLS Certificates
- **Shared CA:** All clusters use the same CA from `certs/ca/`
- **Node Certificates:** Each node has unique certificate with CN=<CLUSTER_NAME>.nifi-<N>
- **Certificate Chain:** Certificates include full chain (node cert + CA cert)
- **SANs:** Certificates include DNS SANs for container hostname, short hostname, FQDN (if DOMAIN set), and localhost
- **Validity:** 10 years (3650 days)
- **Key Size:** 2048-bit RSA

### Default Passwords (MUST CHANGE FOR PRODUCTION)
- **Keystore password:** `changeme123456`
- **Truststore password:** `changeme123456`
- **NiFi admin password:** `changeme123456` (set in .env)
- **Sensitive properties key:** `changeme_sensitive_key_123`

### Network Isolation
- Each cluster has its own isolated bridge network
- Cross-cluster communication requires explicit configuration via extra_hosts
- No automatic network connectivity between clusters

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Port conflicts | Another service using ports | Change CLUSTER_NUM or stop conflicting service |
| Certificate validation fails | DOMAIN mismatch or missing SANs | Ensure DOMAIN in .env matches DNS/extra_hosts |
| Cross-cluster S2S fails | FQDN not resolvable | Check DOMAIN in .env, regenerate configs, verify extra_hosts |
| Permission denied on volumes | Incorrect ownership | Run: `sudo chown -R 1000:1000 clusters/<CLUSTER_NAME>/volumes/` |
| NiFi won't start | Configuration errors | Check logs: `docker compose -f docker-compose-<CLUSTER_NAME>.yml logs <CLUSTER_NAME>-nifi-1` |
| Cluster nodes not connecting | ZooKeeper issues | Verify ZK ensemble: `echo stat | nc localhost <ZK_PORT>` |

### Validation Commands

```bash
# Check cluster status
docker compose -f docker-compose-cluster01.yml ps

# View NiFi logs
docker compose -f docker-compose-cluster01.yml logs -f cluster01-nifi-1

# Check ZooKeeper ensemble
echo stat | nc localhost 30181

# Test NiFi API
curl -k https://localhost:30443/nifi

# Verify certificates
openssl x509 -in clusters/cluster01/certs/cluster01.nifi-1/server-cert.pem -noout -text

# Check Site-to-Site endpoint
curl -k -s --cert clusters/cluster01/certs/cluster01.nifi-1/server-cert.pem \
     --key clusters/cluster01/certs/cluster01.nifi-1/server-key.pem \
     -H "x-nifi-site-to-site-protocol-version: 1" \
     https://cluster01.nifi-1.ymbihq.local:30100/nifi-api/site-to-site/peers | jq .
```

## Post-Creation Steps

1. **Review .env file** and update passwords if needed
2. **Start the cluster:**
   ```bash
   docker compose -f docker-compose-cluster01.yml up -d
   ```
3. **Monitor startup (2-3 minutes):**
   ```bash
   docker compose -f docker-compose-cluster01.yml logs -f
   ```
4. **Access NiFi UI:**
   - Node 1: https://localhost:30443/nifi
   - Node 2: https://localhost:30444/nifi
   - Node 3: https://localhost:30445/nifi
5. **Login with credentials from .env:**
   - Username: admin (default)
   - Password: changeme123456 (default)

## Related Scripts

### Utility Scripts (not called by create-cluster.sh)
- `lib/check-cluster.sh` - Check cluster health and status
- `delete-cluster.sh` - Remove cluster and clean up resources
- `check-nodes.sh` - Check individual node status
- `lib/verify-s2s-port.sh` - Verify Site-to-Site endpoint
- `lib/debug-api.sh` - Debug NiFi API connectivity
- `lib/full-node-status.sh` - Comprehensive node diagnostics

### Management Commands

```bash
# Start cluster
docker compose -f docker-compose-cluster01.yml up -d

# Stop cluster
docker compose -f docker-compose-cluster01.yml down

# View logs
docker compose -f docker-compose-cluster01.yml logs -f

# Check status
docker compose -f docker-compose-cluster01.yml ps

# Restart specific node
docker compose -f docker-compose-cluster01.yml restart cluster01-nifi-1
```

## Files Modified/Created

### Created by Script
- `clusters/<CLUSTER_NAME>/` - Complete cluster workspace
- `docker-compose-<CLUSTER_NAME>.yml` - Docker orchestration file

### Modified (if missing)
- `certs/ca/` - Shared CA (created if doesn't exist)

### Read (Configuration Sources)
- `.env` - Environment variables (DOMAIN, credentials, versions)
- `conf/templates/` - Configuration file templates (optional)

## Performance Considerations

### Memory Requirements
- **ZooKeeper:** ~512MB per node (default Java heap)
- **NiFi:** 2GB per node (configurable via NIFI_JVM_HEAP_INIT/MAX)
- **Minimum System:** 8GB RAM for 3-node cluster (ZK + NiFi)
- **Recommended:** 16GB+ RAM for production

### Disk Space
- **Content Repository:** Grows with data flow volume
- **FlowFile Repository:** ~1GB typical
- **Provenance Repository:** Can grow large (configure retention)
- **Logs:** Rotate regularly
- **Minimum:** 20GB free per cluster
- **Recommended:** 100GB+ for production

### CPU
- **Minimum:** 4 cores for 3-node cluster
- **Recommended:** 8+ cores for production workloads

## Best Practices

1. **Always set DOMAIN in .env** for cross-cluster S2S
2. **Use unique CLUSTER_NUM** to avoid port conflicts
3. **Change default passwords** before production use
4. **Backup certs/ca/** - critical for all clusters
5. **Monitor disk usage** on volume directories
6. **Use load balancer** for UI access in production
7. **Implement TLS everywhere** (already enabled)
8. **Regular backups** of clusters/<CLUSTER_NAME>/ directories
9. **Version control** docker-compose and .env files
10. **Document cluster topology** and dependencies

## References

- [Apache NiFi Documentation](https://nifi.apache.org/docs.html)
- [NiFi Clustering Documentation](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#clustering)
- [NiFi Site-to-Site Protocol](https://nifi.apache.org/docs/nifi-docs/html/user-guide.html#site-to-site)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [ZooKeeper Administrator's Guide](https://zookeeper.apache.org/doc/current/zookeeperAdmin.html)
