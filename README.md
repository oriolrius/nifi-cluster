# Multi-Cluster Apache NiFi Platform

Production-ready multi-cluster Apache NiFi deployment with complete isolation, automated configuration, and shared PKI infrastructure.

## Quick Start

```bash
# Create first cluster (cluster01, 3 nodes, on ports 30xxx)
./create-cluster.sh cluster01 1 3

# Start cluster01
docker compose -f docker-compose-cluster01.yml up -d

# Access cluster01
open https://localhost:30443/nifi
```

**Default Credentials**: `admin` / `changeme123456`

## Features

- **Multi-Cluster Support**: Run multiple independent clusters on one host
- **Complete Isolation**: Separate networks, volumes, configurations, and docker-compose files per cluster
- **Shared PKI**: Single Certificate Authority for all clusters simplifies certificate management
- **Automated Setup**: One-command cluster creation with full validation
- **Port Management**: Systematic port allocation prevents conflicts
- **Production Ready**: TLS/SSL enabled, configurable JVM settings
- **Mandatory Naming**: Strict clusterXX naming convention (cluster01, cluster02, etc.)

## Architecture

Each cluster has:
- **Dedicated Docker network**: Complete network isolation
- **Dedicated docker-compose file**: `docker-compose-<CLUSTER_NAME>.yml`
- **Separate ports**: 30xxx for cluster01, 31xxx for cluster02, etc.
- **Independent volumes**: Isolated data storage
- **Own ZooKeeper ensemble**: Separate cluster coordination
- **Isolated workspace**: All resources in `clusters/<CLUSTER_NAME>/`

All clusters share:
- **Single Certificate Authority**: Simplifies certificate management and enables inter-cluster communication

```
┌─────────────────────────────────────────────────────┐
│                  Host Infrastructure                 │
│                                                      │
│  ┌────────────────┐        ┌────────────────┐      │
│  │  cluster01     │        │  cluster02     │      │
│  │  Ports: 30xxx  │        │  Ports: 31xxx  │      │
│  │  Network: own  │        │  Network: own  │      │
│  │  3 NiFi nodes  │        │  3 NiFi nodes  │      │
│  │  3 ZK nodes    │        │  3 ZK nodes    │      │
│  └────────────────┘        └────────────────┘      │
│                                                      │
│          Shared: Certificate Authority (CA)         │
└─────────────────────────────────────────────────────┘
```

## Directory Structure

```
nifi-cluster/
├── certs/                           # Shared CA for all clusters
│   ├── ca/                          # Certificate Authority (shared)
│   │   ├── ca-key.pem               # CA private key (CRITICAL)
│   │   ├── ca-cert.pem              # CA certificate
│   │   └── truststore.p12           # CA truststore
│   ├── generate-certs.sh            # Certificate generation script
│   └── README.md                    # CA documentation
│
├── clusters/                        # All cluster workspaces
│   ├── cluster01/                   # Cluster01 isolated workspace
│   │   ├── certs/                   # Cluster01 node certificates
│   │   │   ├── ca/                  # Copy of shared CA
│   │   │   ├── cluster01-nifi-1/    # Node 1 certificates
│   │   │   ├── cluster01-nifi-2/    # Node 2 certificates
│   │   │   ├── cluster01-nifi-3/    # Node 3 certificates
│   │   │   ├── cluster01-zookeeper-1/
│   │   │   ├── cluster01-zookeeper-2/
│   │   │   └── cluster01-zookeeper-3/
│   │   ├── conf/                    # Cluster01 configurations
│   │   │   ├── cluster01-nifi-1/    # Node 1 config
│   │   │   │   ├── nifi.properties
│   │   │   │   ├── keystore.p12
│   │   │   │   └── truststore.p12
│   │   │   ├── cluster01-nifi-2/    # Node 2 config
│   │   │   └── cluster01-nifi-3/    # Node 3 config
│   │   └── volumes/                 # Cluster01 runtime data
│   │       ├── cluster01-nifi-1/
│   │       ├── cluster01-nifi-2/
│   │       ├── cluster01-nifi-3/
│   │       ├── cluster01-zookeeper-1/
│   │       ├── cluster01-zookeeper-2/
│   │       └── cluster01-zookeeper-3/
│   │
│   └── cluster02/                   # Cluster02 isolated workspace
│       └── (same structure as cluster01)
│
├── conf/                            # Configuration templates
│   └── templates/                   # Base config files
│       ├── authorizers.xml
│       ├── bootstrap.conf
│       ├── logback.xml
│       ├── login-identity-providers.xml
│       └── zookeeper.properties
│
├── backlog/                         # Project management
│   ├── docs/                        # Design documents
│   └── tasks/                       # Task tracking
│
├── create-cluster.sh                # Cluster creation script
├── delete-cluster.sh                # Cluster deletion script
├── test                             # Comprehensive cluster testing (auto-detects parameters)
├── validate                         # Configuration validation (auto-detects parameters)
├── generate-docker-compose.sh       # Compose file generator
│
├── docker-compose-cluster01.yml     # Cluster01 compose file
├── docker-compose-cluster02.yml     # Cluster02 compose file
└── CLAUDE.md                        # Project instructions

Note: All cluster data is in clusters/<CLUSTER_NAME>/ and is .gitignored
      The shared CA is in certs/ca/ and is copied to each cluster workspace
```

## Port Allocation

### Formula

```
BASE_PORT = 29000 + (CLUSTER_NUM × 1000)
```

### Port Offsets

| Service | Offset | Example (Cluster #1) |
|---------|--------|---------------------|
| HTTPS (NiFi UI) | +443 to +443+N-1 | 30443, 30444, 30445 |
| ZooKeeper | +181 to +181+N-1 | 30181, 30182, 30183 |
| Site-to-Site | +100 to +100+N-1 | 30100, 30101, 30102 |

### Examples

| Cluster Name | Cluster # | HTTPS Ports | ZooKeeper Ports |
|--------------|-----------|-------------|-----------------|
| cluster01 | 1 | 30443-30445 | 30181-30183 |
| cluster02 | 2 | 31443-31445 | 31181-31183 |
| cluster03 | 3 | 32443-32445 | 32181-32183 |

## Scripts

### create-cluster.sh

Creates a complete cluster configuration.

```bash
./create-cluster.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
```

**Example**:
```bash
./create-cluster.sh cluster01 1 3
```

**What it does**:
1. Validates prerequisites
2. Creates volume directories
3. Generates SSL/TLS certificates
4. Generates NiFi configuration files
5. Creates `docker-compose-<CLUSTER_NAME>.yml`

### test

Runs comprehensive cluster tests with automatic parameter detection.

```bash
./test <CLUSTER_NAME>
```

**Example**:
```bash
./test cluster01          # Auto-detects: 3 nodes, ports 30xxx
./test cluster02          # Auto-detects: 3 nodes, ports 31xxx
```

**9 Comprehensive Tests**:
1. Prerequisites check (curl, jq, docker, CA certificates)
2. Container status verification
3. Web UI access (HTTPS with CA validation)
4. Authentication & JWT token generation
5. Backend API access and cluster summary
6. Cluster status verification (all nodes connected)
7. ZooKeeper health check
8. SSL/TLS certificate validation (openssl)
9. Flow replication test (create, verify, cleanup)

All parameters (node count, ports, certificates) are auto-detected from cluster configuration.

### validate

Validates cluster configuration before deployment with automatic parameter detection.

```bash
./validate <CLUSTER_NAME>
```

**Example**:
```bash
./validate cluster01      # Auto-detects all parameters
./validate cluster02      # Auto-detects all parameters
```

**7 Validation Categories**:
1. Directory structure (volumes, certs, configs)
2. Certificate chain (CA, keystores, truststores)
3. Configuration files (nifi.properties, authorizers.xml, etc.)
4. Node addresses & remote input hosts (Site-to-Site)
5. ZooKeeper configuration (connect strings)
6. Docker Compose file syntax & service count
7. Port conflicts & availability (duplicates, in-use ports)

All parameters are auto-detected from cluster workspace.

### delete-cluster.sh

Safely deletes a cluster including containers, networks, and data.

**IMPORTANT**: The shared CA (certs/ca/) is NEVER deleted.

```bash
./delete-cluster.sh <CLUSTER_NAME> [--force]
```

**Example**:
```bash
./delete-cluster.sh cluster01              # With confirmation prompt
./delete-cluster.sh cluster02 --force      # Skip confirmation
```

**Deletes**:
- Docker containers (stopped and removed)
- Docker networks
- Docker Compose file
- Cluster workspace (certs, configs, volumes)

**Preserves**:
- Shared CA at certs/ca/ (used by all clusters)

## Usage Examples

### Single Cluster

```bash
# 1. Create cluster
./create-cluster.sh cluster01 1 3

# 2. Validate
./validate cluster01

# 3. Start
docker compose -f docker-compose-cluster01.yml up -d

# 4. Test
./test cluster01

# 5. Access
open https://localhost:30443/nifi

# 6. View logs
docker compose -f docker-compose-cluster01.yml logs -f

# 7. Stop
docker compose -f docker-compose-cluster01.yml down
```

### Multiple Clusters

```bash
# Create cluster01
./create-cluster.sh cluster01 1 3
docker compose -f docker-compose-cluster01.yml up -d

# Create cluster02
./create-cluster.sh cluster02 2 3
docker compose -f docker-compose-cluster02.yml up -d

# Both running simultaneously
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Test both clusters (auto-detects parameters)
./test cluster01
./test cluster02

# Manage independently
docker compose -f docker-compose-cluster01.yml restart
docker compose -f docker-compose-cluster02.yml restart
```

### Custom Node Count

**IMPORTANT**: Cluster names MUST follow the pattern "clusterXX" (cluster01, cluster02, cluster03, etc.)

```bash
# Single-node cluster
./create-cluster.sh cluster03 3 1

# Two-node cluster
./create-cluster.sh cluster04 4 2

# Five-node cluster
./create-cluster.sh cluster05 5 5
```

## Environment Variables

Each cluster creation generates a `.env` file (optional, uses defaults):

```bash
NIFI_VERSION=latest
ZOOKEEPER_VERSION=3.9
NIFI_SINGLE_USER_USERNAME=admin
NIFI_SINGLE_USER_PASSWORD=changeme123456
NIFI_JVM_HEAP_INIT=2g
NIFI_JVM_HEAP_MAX=2g
```

**Customize before starting**:
```bash
vi .env
docker compose -f docker-compose-cluster01.yml up -d
```

## Troubleshooting

### Cluster Won't Start

```bash
# Check service status
docker compose -f docker-compose-cluster01.yml ps

# View logs
docker compose -f docker-compose-cluster01.yml logs -f nifi-1

# Check ZooKeeper
docker compose -f docker-compose-cluster01.yml logs zookeeper-1
```

### Port Conflicts

```bash
# Check what's using the port
lsof -i :30443

# Validate configuration
./validate cluster01

# Use different cluster number
./create-cluster.sh cluster01 2 3  # Uses ports 31xxx
```

### Certificate Issues

```bash
# Verify shared CA certificate
openssl x509 -in certs/ca/ca-cert.pem -text -noout

# Regenerate cluster certificates (uses existing shared CA)
./create-cluster.sh cluster01 1 3
```

### Node Not Joining Cluster

```bash
# Check cluster logs
docker compose -f docker-compose-cluster01.yml logs -f nifi-1 | grep -i cluster

# Verify ZooKeeper connectivity
docker compose -f docker-compose-cluster01.yml exec nifi-1 nc -zv zookeeper-1 2181

# Restart node
docker compose -f docker-compose-cluster01.yml restart nifi-1
```

## Backup and Recovery

### Backup

```bash
# Stop cluster
docker compose -f docker-compose-cluster01.yml down

# Backup entire cluster (includes node certs, config, volumes)
tar -czf cluster01-backup-$(date +%Y%m%d).tar.gz \
    docker-compose-cluster01.yml \
    clusters/cluster01/

# Backup shared CA (CRITICAL - backs up CA for ALL clusters)
tar -czf ca-backup-$(date +%Y%m%d).tar.gz certs/ca/
```

### Restore

```bash
# Restore files
tar -xzf cluster01-backup-YYYYMMDD.tar.gz

# Start cluster
docker compose -f docker-compose-cluster01.yml up -d
```

## Security Best Practices

1. **Change default passwords** in `.env`
2. **Protect CA private key**: `chmod 600 certs/ca/ca-key.pem`
3. **Use strong passwords** (min 12 characters)
4. **Regular updates**: Keep NiFi version current
5. **Firewall rules**: Restrict access to NiFi ports
6. **Production auth**: Replace single-user with LDAP/OIDC
7. **Backup CA regularly**: The shared CA is critical for all clusters

## Advanced Features

### Network Isolation

Each cluster has its own Docker network:

```bash
# View cluster networks
docker network ls | grep cluster

# Inspect cluster01 network
docker network inspect cluster01-nifi-cluster_cluster01-network
```

### Inter-Cluster Communication

All clusters share the same CA, enabling Site-to-Site connections between clusters without additional certificate configuration.

### Scaling

```bash
# Recreate with more nodes
./create-cluster.sh cluster01 1 5  # Now 5 nodes
docker compose -f docker-compose-cluster01.yml down
docker compose -f docker-compose-cluster01.yml up -d
```

## Resources

- [Apache NiFi Documentation](https://nifi.apache.org/docs.html)
- [NiFi Clustering Guide](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#clustering)
- [ZooKeeper Documentation](https://zookeeper.apache.org/doc/current/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## Quick Reference

```bash
# Create cluster
./create-cluster.sh cluster01 1 3

# Validate
./validate cluster01

# Start
docker compose -f docker-compose-cluster01.yml up -d

# Test
./test cluster01

# Logs
docker compose -f docker-compose-cluster01.yml logs -f

# Stop
docker compose -f docker-compose-cluster01.yml down

# Access
open https://localhost:30443/nifi
```

**Credentials**: `admin` / `changeme123456`
