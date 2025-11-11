---
id: decision-001
title: Current NiFi Cluster Architecture (Single Cluster)
type: other
created_date: '2025-11-11 15:10'
---
# Decision Document: Current NiFi Cluster Architecture

**Status**: Production
**Date**: 2025-11-11
**System**: Single 3-Node NiFi Cluster
**Location**: `/home/oriol/miimetiq3/nifi-cluster`

---

## Executive Summary

This document describes the **current production NiFi cluster** that is operational. This is a single 3-node high-availability cluster with ZooKeeper coordination, private PKI security, and Docker Compose deployment.

---

## 1. Current Production System

### 1.1 Architecture Overview

**Deployment Type**: Single HA Cluster
- **NiFi Nodes**: 3 nodes (nifi-1, nifi-2, nifi-3)
- **ZooKeeper Ensemble**: 3 nodes (zookeeper-1, zookeeper-2, zookeeper-3)
- **Deployment Platform**: Docker Compose
- **Network**: Single Docker bridge network (`nifi-cluster-network`)
- **Data Storage**: Host bind mounts (no Docker volumes)

```
┌─────────────────────────────────────────────────┐
│         nifi-cluster-network (Docker)           │
│                                                 │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ nifi-1  │  │ nifi-2  │  │ nifi-3  │        │
│  │ :59443  │  │ :59444  │  │ :59445  │        │
│  └────┬────┘  └────┬────┘  └────┬────┘        │
│       │            │            │              │
│       └────────────┴────────────┘              │
│                    │                           │
│       ┌────────────┴────────────┐              │
│       │                         │              │
│  ┌────▼────┐  ┌─────────┐  ┌──▼──────┐        │
│  │  zk-1   │  │  zk-2   │  │  zk-3   │        │
│  │ :59181  │  │ :59182  │  │ :59183  │        │
│  └─────────┘  └─────────┘  └─────────┘        │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 1.2 Port Configuration

**External Port Mappings**:
```
Service          Node 1    Node 2    Node 3    Protocol
─────────────────────────────────────────────────────────
NiFi Web UI      59443     59444     59445     HTTPS
Site-to-Site     59100     59101     59102     RAW Socket
ZooKeeper        59181     59182     59183     TCP
```

**Internal Ports** (not exposed to host):
```
Port    Service                    Usage
─────────────────────────────────────────────────────
8443    NiFi HTTPS                 Internal container port
8082    NiFi Cluster Protocol      Node-to-node communication
6342    NiFi Load Balance          Flow file load balancing
10000   Site-to-Site Internal      S2S protocol port
2181    ZooKeeper Client           Client connections
2888    ZooKeeper Follower         Ensemble communication
3888    ZooKeeper Leader Election  Leader election
```

### 1.3 Security Architecture

#### Private PKI Infrastructure

**Root Certificate Authority**:
- Location: `certs/ca/`
- Certificate: `ca-cert.pem` (10-year validity)
- Private Key: `ca-key.pem` (2048-bit RSA)
- Truststore: `truststore.jks` and `truststore.p12`
- Subject: `CN=NiFi Cluster Root CA, OU=Certificate Authority, O=NiFi Cluster`

**Node Certificates**:
- Each node has unique certificate
- Common Names: `CN=nifi-1`, `CN=nifi-2`, `CN=nifi-3`
- Subject Alternative Names (SAN):
  - DNS.1 = `nifi-{1,2,3}` (container hostname)
  - DNS.2 = `localhost` (host access)
  - IP.1 = `127.0.0.1` (localhost IP)
- Format: PKCS12 (`.p12` files)
- Location per node: `conf/nifi-X/keystore.p12`, `conf/nifi-X/truststore.p12`

**Security Features**:
- ✅ Mutual TLS authentication between cluster nodes
- ✅ Certificate-based node identity
- ✅ Encrypted cluster communication (port 8082)
- ✅ HTTPS web interface (ports 59443-59445)
- ✅ Single-user authentication (username/password)

#### Authentication

**Method**: Single User Authentication
- Username: `admin` (configurable in `.env`)
- Password: Stored in `.env` file
- Configured via environment variables in docker-compose.yml

#### Web Frontend to Backend Connection

**Critical Configuration**: `nifi.web.proxy.host`

This is the **most important setting** for enabling web UI access to different nodes via different ports. Here's how it works:

**Port Mapping Architecture**:
```
Browser Request:
  https://localhost:59443/nifi
        ↓
  Docker Port Mapping (59443:8443)
        ↓
  Container nifi-1 internal port 8443
        ↓
  NiFi validates request against nifi.web.proxy.host
        ↓
  Serves web UI
```

**How nifi.web.proxy.host Works**:

```properties
nifi.web.proxy.host=localhost:59443,localhost:59444,localhost:59445,nifi-1:8443,nifi-2:8443,nifi-3:8443
```

This property tells NiFi which `Host` headers to accept. When you access:
- `https://localhost:59443/nifi` → Browser sends `Host: localhost:59443`
- `https://localhost:59444/nifi` → Browser sends `Host: localhost:59444`
- `https://localhost:59445/nifi` → Browser sends `Host: localhost:59445`

**Why Both localhost AND container hostnames?**

1. **`localhost:59443`** - For external browser access from the host
   - User types: `https://localhost:59443/nifi`
   - Docker maps: `59443` (host) → `8443` (container)
   - NiFi receives request with `Host: localhost:59443`
   - Validates against proxy host list ✓

2. **`nifi-1:8443`** - For internal cluster communication
   - Cluster coordinator needs to redirect to specific node
   - Internal API calls between nodes
   - Load balancer redirects
   - NiFi receives request with `Host: nifi-1:8443`
   - Validates against proxy host list ✓

**What Happens Without This Configuration?**

If `nifi.web.proxy.host` is not set correctly:
```
Browser → https://localhost:59443/nifi
NiFi receives Host: localhost:59443
NiFi checks: Is "localhost:59443" in my proxy host list?
Result: NO → HTTP 403 Forbidden or redirect loop
```

**Certificate Validation Flow**:

```
1. Browser connects to localhost:59443
   ↓
2. TLS handshake with nifi-1's certificate
   - Certificate CN: nifi-1
   - SAN: DNS.1=nifi-1, DNS.2=localhost, IP.1=127.0.0.1
   ↓
3. Browser validates certificate against SAN
   - Requested: localhost
   - SAN includes: localhost ✓
   - Certificate trusted (self-signed, user accepts)
   ↓
4. Browser sends HTTP request
   - Host: localhost:59443
   ↓
5. NiFi validates Host header
   - Is "localhost:59443" in nifi.web.proxy.host? ✓
   - Proceed to serve request
```

**Docker Port Mapping Details**:

Each node maps different external ports to the same internal port:

| Container | Internal Port | External Port | Access URL |
|-----------|---------------|---------------|------------|
| nifi-1    | 8443          | 59443         | https://localhost:59443/nifi |
| nifi-2    | 8443          | 59444         | https://localhost:59444/nifi |
| nifi-3    | 8443          | 59445         | https://localhost:59445/nifi |

**Why This Matters for Multi-Cluster**:

When creating multiple clusters, each cluster needs:
1. **Unique external ports** (59143-59145 for cluster01, 59243-59245 for cluster02)
2. **Correct proxy host configuration** listing all external ports
3. **Certificates with localhost SAN** to allow host access
4. **Matching container hostnames** in proxy host list

**Example for Multi-Cluster** (future):

Cluster 01:
```properties
nifi.web.proxy.host=localhost:59143,localhost:59144,localhost:59145,cluster01-nifi01:8443,cluster01-nifi02:8443,cluster01-nifi03:8443
```

Cluster 02:
```properties
nifi.web.proxy.host=localhost:59243,localhost:59244,localhost:59245,cluster02-nifi01:8443,cluster02-nifi02:8443,cluster02-nifi03:8443
```

**Troubleshooting Connection Issues**:

| Symptom | Likely Cause | Solution |
|---------|--------------|----------|
| "Invalid Host header" | Proxy host not configured | Add to `nifi.web.proxy.host` |
| Certificate error | SAN doesn't include localhost | Regenerate cert with SAN |
| Redirect loop | Proxy host incomplete | Add all node:port combinations |
| 403 Forbidden | Proxy host mismatch | Verify exact host:port in list |

### 1.4 Directory Structure

```
nifi-cluster/
├── certs/                          # PKI Certificates
│   ├── ca/                         # Root CA (shared)
│   │   ├── ca-key.pem
│   │   ├── ca-cert.pem
│   │   └── truststore.jks
│   ├── nifi-{1,2,3}/               # Node certificates
│   │   ├── keystore.p12
│   │   ├── truststore.p12
│   │   └── server-cert.pem
│   ├── zookeeper-{1,2,3}/          # ZK certificates
│   ├── generate-certs.sh           # Certificate generation script
│   └── README.md
│
├── conf/                           # Node Configurations
│   ├── nifi-1/                     # Node 1 config
│   │   ├── nifi.properties         # Main configuration
│   │   ├── state-management.xml    # ZK state provider
│   │   ├── authorizers.xml         # Authorization
│   │   ├── bootstrap.conf          # JVM settings
│   │   ├── keystore.p12            # Node certificate
│   │   ├── truststore.p12          # CA trust
│   │   └── [other config files]
│   ├── nifi-2/                     # Node 2 config
│   ├── nifi-3/                     # Node 3 config
│   ├── create-node-properties.sh   # Config generation
│   └── README.md
│
├── volumes/                        # Persistent Data
│   ├── nifi-1/
│   │   ├── content_repository/
│   │   ├── database_repository/
│   │   ├── flowfile_repository/
│   │   ├── provenance_repository/
│   │   ├── state/
│   │   └── logs/
│   ├── nifi-2/
│   ├── nifi-3/
│   └── zookeeper-{1,2,3}/
│       ├── data/
│       ├── datalog/
│       └── logs/
│
├── docker-compose.yml              # Service orchestration
├── .env                            # Environment variables
├── init-volumes.sh                 # Volume initialization
├── CLAUDE.md                       # AI assistant instructions
└── README.md                       # Documentation
```

### 1.5 Configuration Details

#### NiFi Properties (Key Settings)

**Node-Specific** (different per node):
```properties
# Node identity
nifi.cluster.node.address=nifi-1                    # nifi-2, nifi-3 for other nodes
nifi.remote.input.host=nifi-1                       # nifi-2, nifi-3 for other nodes
```

**Cluster-Wide** (same across all nodes):
```properties
# Cluster coordination
nifi.cluster.is.node=true
nifi.cluster.protocol.port=8082
nifi.zookeeper.connect.string=zookeeper-1:2181,zookeeper-2:2181,zookeeper-3:2181
nifi.zookeeper.root.node=/nifi

# Web configuration
nifi.web.https.port=8443
nifi.web.proxy.host=localhost:59443,localhost:59444,localhost:59445,nifi-1:8443,nifi-2:8443,nifi-3:8443

# Security
nifi.security.keystore=./conf/keystore.p12
nifi.security.keystoreType=PKCS12
nifi.security.keystorePasswd=changeme123456
nifi.security.truststore=./conf/truststore.p12
nifi.security.truststoreType=PKCS12
nifi.security.truststorePasswd=changeme123456
nifi.sensitive.props.key=changeme_sensitive_key_123

# Performance
nifi.cluster.flow.election.max.wait.time=1 min
```

#### State Management (state-management.xml)

**ZooKeeper Provider**:
```xml
<cluster-provider>
  <id>zk-provider</id>
  <class>org.apache.nifi.controller.state.providers.zookeeper.ZooKeeperStateProvider</class>
  <property name="Connect String">zookeeper-1:2181,zookeeper-2:2181,zookeeper-3:2181</property>
  <property name="Root Node">/nifi</property>
  <property name="Session Timeout">10 seconds</property>
  <property name="Access Control">Open</property>
</cluster-provider>
```

### 1.6 Docker Compose Configuration

**Service Pattern** (example for nifi-1):
```yaml
nifi-1:
  image: apache/nifi:latest
  container_name: nifi-1
  hostname: nifi-1
  networks:
    - nifi-cluster-network
  ports:
    - "59443:8443"    # HTTPS UI
    - "59100:10000"   # Site-to-Site
  environment:
    NIFI_CLUSTER_IS_NODE: "true"
    NIFI_CLUSTER_NODE_ADDRESS: nifi-1
    NIFI_CLUSTER_NODE_PROTOCOL_PORT: 8082
    NIFI_ZK_CONNECT_STRING: zookeeper-1:2181,zookeeper-2:2181,zookeeper-3:2181
    NIFI_WEB_HTTPS_PORT: 8443
    NIFI_WEB_HTTPS_HOST: nifi-1
    NIFI_WEB_PROXY_HOST: localhost:59443,localhost:59444,localhost:59445,nifi-1:8443,nifi-2:8443,nifi-3:8443
    SINGLE_USER_CREDENTIALS_USERNAME: admin
    SINGLE_USER_CREDENTIALS_PASSWORD: changeme123456
    NIFI_JVM_HEAP_INIT: 2g
    NIFI_JVM_HEAP_MAX: 2g
  volumes:
    - ./conf/nifi-1:/opt/nifi/nifi-current/conf:rw
    - ./volumes/nifi-1/content_repository:/opt/nifi/nifi-current/content_repository
    - ./volumes/nifi-1/database_repository:/opt/nifi/nifi-current/database_repository
    - ./volumes/nifi-1/flowfile_repository:/opt/nifi/nifi-current/flowfile_repository
    - ./volumes/nifi-1/provenance_repository:/opt/nifi/nifi-current/provenance_repository
    - ./volumes/nifi-1/state:/opt/nifi/nifi-current/state
    - ./volumes/nifi-1/logs:/opt/nifi/nifi-current/logs
  depends_on:
    - zookeeper-1
    - zookeeper-2
    - zookeeper-3
```

**ZooKeeper Pattern** (example for zookeeper-1):
```yaml
zookeeper-1:
  image: zookeeper:3.9
  container_name: zookeeper-1
  hostname: zookeeper-1
  networks:
    - nifi-cluster-network
  ports:
    - "59181:2181"
  environment:
    ZOO_MY_ID: 1
    ZOO_SERVERS: server.1=zookeeper-1:2888:3888;2181 server.2=zookeeper-2:2888:3888;2181 server.3=zookeeper-3:2888:3888;2181
  volumes:
    - ./volumes/zookeeper-1/data:/data
    - ./volumes/zookeeper-1/datalog:/datalog
    - ./volumes/zookeeper-1/logs:/logs
```

---

## 2. Operational Procedures

### 2.1 Initial Setup

**One-Time Initialization**:
```bash
# 1. Generate certificates
cd certs
./generate-certs.sh
cd ..

# 2. Create volume directories
./init-volumes.sh

# 3. Generate NiFi properties
cd conf
./create-node-properties.sh
cd ..
```

### 2.2 Cluster Lifecycle

**Start Cluster**:
```bash
docker compose up -d
```

**Stop Cluster**:
```bash
docker compose down
```

**View Logs**:
```bash
# All services
docker compose logs -f

# Specific node
docker compose logs -f nifi-1
docker compose logs -f nifi-2
```

**Access Web UI**:
```
https://localhost:59443/nifi   # Node 1
https://localhost:59444/nifi   # Node 2
https://localhost:59445/nifi   # Node 3

Credentials: admin / changeme123456 (from .env)
```

### 2.3 Health Checks

**Verify Cluster Status**:
```bash
# Check all containers running
docker compose ps

# Check NiFi cluster summary (from any node)
curl -k -u admin:changeme123456 https://localhost:59443/nifi-api/flow/cluster/summary
```

**ZooKeeper Health**:
```bash
# Check ZooKeeper status
echo stat | nc localhost 59181
echo stat | nc localhost 59182
echo stat | nc localhost 59183
```

---

## 3. Key Technical Decisions

### Decision 1: 3-Node High Availability

**Why**: 
- Provides fault tolerance (cluster continues with 2 nodes)
- Enables rolling updates without downtime
- ZooKeeper quorum requires odd number (3 minimum for HA)

**Trade-offs**:
- Higher resource usage than single node
- More complex configuration
- Network coordination overhead

### Decision 2: Docker Compose (not Kubernetes)

**Why**:
- Simpler deployment for single-host setup
- Easier configuration management
- Lower operational overhead
- Suitable for development/staging/small production

**Trade-offs**:
- Limited to single host
- Manual scaling
- No built-in service mesh

### Decision 3: Host Bind Mounts (not Docker Volumes)

**Why**:
- Direct access to data from host
- Easier backup/restore
- Simpler troubleshooting
- Clear file ownership (UID 1000)

**Trade-offs**:
- Less portable across Docker hosts
- Requires manual permission management

### Decision 4: Private PKI (not Public CA)

**Why**:
- Full control over certificate lifecycle
- No external dependencies
- No cost for certificates
- Faster issuance

**Trade-offs**:
- CA management responsibility
- Clients must trust custom CA
- Manual certificate renewal process

### Decision 5: Single-User Authentication

**Why**:
- Simple initial setup
- Suitable for development/staging
- Easy to configure
- No external auth provider needed

**Trade-offs**:
- Not suitable for production multi-user
- No fine-grained access control
- Shared credentials

### Decision 6: ZooKeeper Root Node `/nifi`

**Why**:
- Standard NiFi convention
- Clear namespace separation
- Easy to identify NiFi data in ZK

**Impact**:
- All cluster state stored under this path
- Flow synchronization uses this namespace
- Leader election occurs here

---

## 4. Current Capabilities

### 4.1 What Works

✅ **High Availability**
- 3-node cluster with automatic failover
- Leader election via ZooKeeper
- Shared flow state across nodes

✅ **Load Balancing**
- Automatic flow file distribution
- Connection load balancing
- Site-to-Site load balancing

✅ **Security**
- TLS encryption for all communication
- Certificate-based node authentication
- HTTPS web interface

✅ **Data Persistence**
- Content repository: Flow file content
- FlowFile repository: Flow file metadata
- Provenance repository: Data lineage
- Database repository: Cluster metadata

✅ **Cluster Coordination**
- Automatic flow synchronization
- Distributed state management
- Leader election for primary node

### 4.2 Current Limitations

❌ **Single Cluster Only**
- Cannot run multiple independent clusters
- No environment isolation (dev/staging/prod)
- All work shares same resources

❌ **Fixed Port Configuration**
- Ports hardcoded in docker-compose.yml
- Cannot run second cluster without port conflicts

❌ **Manual Scaling**
- Adding nodes requires manual configuration
- No automated node provisioning

❌ **No Multi-Tenancy**
- Single authentication domain
- No user/team isolation
- Shared flow namespace

---

## 5. Performance & Capacity

### 5.1 Resource Allocation

**Per NiFi Node**:
- JVM Heap: 2GB initial, 2GB max
- CPU: No limit (shared host)
- Disk: Unlimited (host filesystem)

**Cluster Total**:
- 3 NiFi nodes × 2GB = 6GB minimum RAM
- 3 ZooKeeper nodes × ~512MB = 1.5GB RAM
- **Total**: ~8GB RAM recommended minimum

### 5.2 Storage Layout

**Per NiFi Node**:
```
volumes/nifi-X/
├── content_repository/      # Largest - flow file content
├── database_repository/     # Small - H2 database
├── flowfile_repository/     # Medium - flow file metadata
├── provenance_repository/   # Large - data lineage
├── state/                   # Small - component state
└── logs/                    # Medium - application logs
```

**Growth Rate**:
- Depends on flow throughput
- Content repo grows with queued data
- Provenance grows with processed events

---

## 6. Known Issues & Workarounds

### Issue 1: Cluster Startup Time

**Symptom**: Nodes take 2-5 minutes to fully connect to cluster

**Cause**: 
- Certificate loading
- Flow synchronization
- ZooKeeper session establishment

**Workaround**: Wait for "Successfully connected to cluster" in logs

### Issue 2: Port Already in Use

**Symptom**: Container fails to start with "port already allocated"

**Cause**: Previous containers not cleaned up

**Fix**:
```bash
docker compose down
docker compose up -d
```

### Issue 3: Web UI Not Accessible

**Symptom**: Cannot access https://localhost:59443/nifi

**Possible Causes**:
- Container not started
- Certificate issues
- Browser not trusting self-signed cert

**Troubleshooting**:
```bash
# Check container running
docker compose ps

# Check logs for errors
docker compose logs nifi-1 | grep -i error

# Accept self-signed cert in browser
```

---

## 7. Maintenance

### 7.1 Certificate Renewal

**Current Validity**: 10 years (generated with `-days 3650`)

**Renewal Process**:
1. Stop cluster
2. Regenerate certificates with `certs/generate-certs.sh`
3. Copy new certs to `conf/nifi-X/`
4. Restart cluster

### 7.2 Backup Strategy

**What to Backup**:
```bash
# Full backup
tar -czf backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml \
  .env \
  conf/ \
  volumes/
```

**Restore**:
```bash
docker compose down
tar -xzf backup-YYYYMMDD.tar.gz
docker compose up -d
```

### 7.3 Updates

**NiFi Version Update**:
1. Edit `.env` or docker-compose.yml: `NIFI_VERSION=x.y.z`
2. Pull new image: `docker compose pull`
3. Restart cluster: `docker compose up -d`

**Rolling Update** (zero downtime):
1. Stop node 1: `docker compose stop nifi-1`
2. Update image
3. Start node 1: `docker compose up -d nifi-1`
4. Wait for cluster reconnection
5. Repeat for nodes 2 and 3

---

## 8. Access Information

### 8.1 Web UI

**URLs**:
- Node 1: https://localhost:59443/nifi
- Node 2: https://localhost:59444/nifi
- Node 3: https://localhost:59445/nifi

**Credentials**:
- Username: `admin` (from `.env`)
- Password: `changeme123456` (from `.env`)

### 8.2 API Access

**REST API Endpoints**:
```
https://localhost:59443/nifi-api/
https://localhost:59444/nifi-api/
https://localhost:59445/nifi-api/
```

**Authentication**: Basic auth or token-based

---

## 9. Documentation References

**Internal Docs**:
- Main README: `/home/oriol/miimetiq3/nifi-cluster/README.md`
- Certificate Guide: `/home/oriol/miimetiq3/nifi-cluster/certs/README.md`
- Configuration Guide: `/home/oriol/miimetiq3/nifi-cluster/conf/README.md`
- AI Instructions: `/home/oriol/miimetiq3/nifi-cluster/CLAUDE.md`

**External Resources**:
- Apache NiFi Docs: https://nifi.apache.org/docs.html
- NiFi Clustering: https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#clustering
- Docker Compose: https://docs.docker.com/compose/

---

## 10. Future Enhancements (Planned)

See backlog tasks and doc-004 for multi-cluster architecture plans:
- Support for multiple independent clusters
- Template-based cluster creation
- Automated provisioning scripts
- Port range allocation strategy
- Shared CA with network isolation

---

**Document Created**: 2025-11-11  
**System Status**: Production - Operational  
**Last Validated**: 2025-11-11
