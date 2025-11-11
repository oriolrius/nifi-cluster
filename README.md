# Apache NiFi Cluster with ZooKeeper

A production-ready Apache NiFi cluster setup using Docker Compose with external ZooKeeper coordination.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    NiFi Cluster                         │
│  ┌─────────┐      ┌─────────┐      ┌─────────┐        │
│  │ NiFi-1  │      │ NiFi-2  │      │ NiFi-3  │        │
│  │ :8443   │      │ :8444   │      │ :8445   │        │
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

## Components

### NiFi Cluster (3 nodes)
- **Node 1**: https://localhost:59443/nifi
- **Node 2**: https://localhost:59444/nifi
- **Node 3**: https://localhost:59445/nifi

### ZooKeeper Ensemble (3 nodes)
- **Node 1**: localhost:59181
- **Node 2**: localhost:59182
- **Node 3**: localhost:59183

## Features

- **High Availability**: 3-node NiFi cluster with automatic failover
- **ZooKeeper Coordination**: External 3-node ZooKeeper ensemble
- **Host Bind Mounts**: All data stored in `./volumes/` directory
- **Modern Docker Compose**: No deprecated version field
- **Health Checks**: Automatic health monitoring
- **Production Ready**: Configurable JVM heap, security settings

## Quick Start

### 1. Initialize Volumes

```bash
./init-volumes.sh
```

This creates the directory structure:
```
nifi-cluster/
├── conf/                   # Custom configuration (mounted into containers)
│   ├── nifi-1/            # Node 1 configuration
│   │   ├── nifi.properties
│   │   ├── keystore.p12   # Private PKI keystore
│   │   ├── truststore.p12 # CA truststore
│   │   └── ... (other NiFi config files)
│   ├── nifi-2/            # Node 2 configuration
│   └── nifi-3/            # Node 3 configuration
├── certs/                  # Private PKI certificates (source)
│   ├── ca/                # Root Certificate Authority
│   ├── nifi-1/            # Node 1 source certificates
│   ├── nifi-2/            # Node 2 source certificates
│   └── nifi-3/            # Node 3 source certificates
├── volumes/               # Runtime data storage
│   ├── zookeeper-1/
│   ├── zookeeper-2/
│   ├── zookeeper-3/
│   ├── nifi-1/
│   ├── nifi-2/
│   └── nifi-3/
```

### 2. Configure Environment

Edit `.env` file and change default passwords:

```bash
NIFI_SINGLE_USER_USERNAME=admin
NIFI_SINGLE_USER_PASSWORD=your-secure-password-here
```

### 3. Start Cluster

```bash
docker compose up -d
```

### 4. Wait for Initialization

The cluster takes 2-3 minutes to start. Monitor progress:

```bash
docker compose logs -f
```

### 5. Access NiFi UI

Connect to any node (they share the same cluster state):
- https://localhost:59443/nifi
- https://localhost:59444/nifi
- https://localhost:59445/nifi

**Default credentials**: admin / changeme123456 (change in `.env`)

## Management

### View Status

```bash
# Check all services
docker compose ps

# Check cluster health
docker compose logs -f nifi-1 nifi-2 nifi-3

# Check ZooKeeper status
docker compose exec zookeeper-1 zkServer.sh status
```

### Stop Cluster

```bash
# Stop all services
docker compose down

# Stop and remove volumes (CAUTION: deletes all data!)
docker compose down -v
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart nifi-1
docker compose restart zookeeper-1
```

### Scale Cluster

To add more NiFi nodes, edit `docker-compose.yml` and add nifi-4, nifi-5, etc. following the same pattern.

## Configuration

### Custom Configuration with Private PKI

This cluster uses **custom `nifi.properties` files** and **private PKI certificates** for each node:

- **Configuration Directory**: Each node has its own `conf/nifi-X/` directory containing:
  - `nifi.properties` - Custom NiFi configuration
  - `keystore.p12` - Node's private key and certificate (from your private CA)
  - `truststore.p12` - CA certificate for trust validation
  - All other NiFi configuration files (bootstrap.conf, authorizers.xml, etc.)

- **Private PKI**: Certificates are issued by your own Certificate Authority:
  - **CA**: CN=NiFi Cluster Root CA
  - **Node Certificates**: CN=nifi-1, CN=nifi-2, CN=nifi-3
  - **Certificate Format**: PKCS12 (.p12)
  - **Password**: changeme123456 (change in production!)

- **Mount Strategy**: The entire `conf/` directory is mounted into each container:
  ```yaml
  volumes:
    - ./conf/nifi-1:/opt/nifi/nifi-current/conf:rw
  ```

**To modify configuration**: Edit files in `conf/nifi-X/` and restart the node.

See [`conf/README.md`](conf/README.md) for detailed configuration management instructions.

### Environment Variables (.env)

| Variable | Default | Description |
|----------|---------|-------------|
| NIFI_VERSION | latest | NiFi Docker image version |
| ZOOKEEPER_VERSION | 3.9 | ZooKeeper version |
| NIFI_SINGLE_USER_USERNAME | admin | NiFi admin username |
| NIFI_SINGLE_USER_PASSWORD | changeme123456 | NiFi admin password |
| NIFI_JVM_HEAP_INIT | 2g | Initial JVM heap size |
| NIFI_JVM_HEAP_MAX | 2g | Maximum JVM heap size |

### Port Allocation Strategy

This project uses a systematic port allocation strategy that allows running multiple independent NiFi clusters on the same host without port conflicts.

#### Port Calculation Formula

```
BASE_PORT = 29000 + (CLUSTER_NUM × 1000)
```

Each cluster gets a 1000-port range, allowing room for growth and ensuring complete isolation between clusters.

#### Port Offsets

Within each cluster's 1000-port range, ports are assigned with consistent offsets:

| Service | Offset | Formula | Example (Cluster 0) |
|---------|--------|---------|---------------------|
| **HTTPS (NiFi UI)** | +443 to +443+N-1 | `BASE_PORT + 443 + (node - 1)` | 29443, 29444, 29445 |
| **ZooKeeper Client** | +181 to +181+N-1 | `BASE_PORT + 181 + (node - 1)` | 29181, 29182, 29183 |
| **Site-to-Site** | +100 to +100+N-1 | `BASE_PORT + 100 + (node - 1)` | 29100, 29101, 29102 |
| **Cluster Protocol** | +82 | `BASE_PORT + 82` (all nodes) | 29082 |
| **Load Balance** | +342 | `BASE_PORT + 342` (all nodes) | 29342 |

*N = Number of nodes in the cluster*

#### Port Ranges by Cluster Number

Reference table for the first 10 clusters:

| Cluster # | Base Port | HTTPS Range | ZooKeeper Range | S2S Range | Cluster Proto | Load Balance |
|-----------|-----------|-------------|-----------------|-----------|---------------|--------------|
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

*Table shows port ranges for 3-node clusters. Adjust upper range based on your NODE_COUNT.*

#### Current Cluster Port Mapping (Cluster 0)

**NiFi HTTPS UI:**
- Node 1: 29443 → https://localhost:29443/nifi
- Node 2: 29444 → https://localhost:29444/nifi
- Node 3: 29445 → https://localhost:29445/nifi

**ZooKeeper Client:**
- Node 1: 29181
- Node 2: 29182
- Node 3: 29183

**NiFi Site-to-Site:**
- Node 1: 29100
- Node 2: 29101
- Node 3: 29102

**Internal Ports (same for all nodes):**
- Cluster Protocol: 29082
- Load Balance: 29342

#### Examples

**Example 1: Production Cluster (Cluster 0, 3 nodes)**
```bash
./create-cluster.sh production 0 3
```
- HTTPS: 29443, 29444, 29445
- ZooKeeper: 29181, 29182, 29183
- Site-to-Site: 29100, 29101, 29102

**Example 2: Staging Cluster (Cluster 1, 3 nodes)**
```bash
./create-cluster.sh staging 1 3
```
- HTTPS: 30443, 30444, 30445
- ZooKeeper: 30181, 30182, 30183
- Site-to-Site: 30100, 30101, 30102

**Example 3: Development Cluster (Cluster 2, 2 nodes)**
```bash
./create-cluster.sh dev 2 2
```
- HTTPS: 31443, 31444
- ZooKeeper: 31181, 31182
- Site-to-Site: 31100, 31101

#### Avoiding Port Conflicts

**1. Between Clusters**
- Use different CLUSTER_NUM values (0, 1, 2, etc.)
- Each cluster gets a 1000-port range
- Maximum recommended: 10 clusters per host

**2. With System Services**
- Ports below 29000 are avoided to prevent conflicts with common services
- Standard ports (80, 443, 8080, etc.) are not used
- Range 29000-38999 is dedicated to NiFi clusters

**3. Validation**
- Use `./validate-cluster.sh` to check for port conflicts before deployment
- The script checks for duplicate port mappings and port availability
- Run validation after generating configuration:
  ```bash
  ./create-cluster.sh production 0 3
  ./validate-cluster.sh 3
  ```

**4. Dynamic Port Check**
Check if a port is in use before deployment:
```bash
# Linux
lsof -i :29443
ss -tlnH | grep :29443

# Or during validation
./validate-cluster.sh 3
```

#### Edge Cases

**Large Clusters (>10 nodes)**
- Each cluster reserves 1000 ports, supporting up to ~500 nodes theoretically
- Practical limit: ~20 nodes per cluster (limited by node count × ports per node)
- For larger deployments, use separate hosts or Kubernetes

**Port Exhaustion**
- With 10 clusters × 1000 ports = 10,000 ports used
- Additional clusters should use CLUSTER_NUM 10+ or separate hosts
- Monitor with: `./validate-cluster.sh [NODE_COUNT]`

**Conflicts with Existing Services**
- If port range 29000-38999 conflicts with existing services
- Option 1: Change CLUSTER_NUM to use different range (e.g., 10-19 → ports 39000-48999)
- Option 2: Modify port calculation formula in scripts
- Option 3: Use host networking or different deployment approach

## Cluster Coordination

### ZooKeeper Connection String

NiFi nodes connect to ZooKeeper ensemble:
```
zookeeper-1:2181,zookeeper-2:2181,zookeeper-3:2181
```

### Leader Election

- NiFi automatically elects a cluster coordinator
- If coordinator fails, a new one is elected automatically
- ZooKeeper maintains cluster state and coordination

### Data Distribution

- Each node processes data independently
- Flow configuration is shared across all nodes
- Content is distributed based on load balancing

## Monitoring

### Check Cluster Status

```bash
# View NiFi logs
docker compose logs -f nifi-1

# Check ZooKeeper quorum
docker compose exec zookeeper-1 zkCli.sh -server localhost:2181 ls /nifi
```

### Health Checks

Each NiFi node has automatic health checks:
- Interval: 30 seconds
- Timeout: 10 seconds
- Retries: 5
- Start period: 120 seconds

## Troubleshooting

### Cluster Won't Start

1. Check ZooKeeper is running:
```bash
docker compose ps | grep zookeeper
```

2. Check ZooKeeper logs:
```bash
docker compose logs zookeeper-1 zookeeper-2 zookeeper-3
```

3. Verify network connectivity:
```bash
docker compose exec nifi-1 ping zookeeper-1
```

### Node Not Joining Cluster

1. Check node logs:
```bash
docker compose logs -f nifi-1
```

2. Verify ZooKeeper connection:
```bash
docker compose exec nifi-1 cat /opt/nifi/nifi-current/logs/nifi-app.log | grep -i zookeeper
```

3. Check firewall/network:
```bash
docker compose exec nifi-1 nc -zv zookeeper-1 2181
```

### Performance Issues

1. Increase JVM heap in `.env`:
```bash
NIFI_JVM_HEAP_INIT=4g
NIFI_JVM_HEAP_MAX=4g
```

2. Restart affected nodes:
```bash
docker compose restart nifi-1 nifi-2 nifi-3
```

### Port Conflicts

If ports are already in use, edit `docker-compose.yml` and change port mappings:
```yaml
ports:
  - "60443:8443"  # Change external port (example)
```

## Backup & Recovery

### Backup Cluster Data

```bash
# Stop cluster
docker compose down

# Backup everything
tar -czf nifi-cluster-backup-$(date +%Y%m%d).tar.gz volumes/ .env docker-compose.yml

# Restart cluster
docker compose up -d
```

### Backup Individual Nodes

```bash
# Backup NiFi node 1
tar -czf nifi-1-backup.tar.gz volumes/nifi-1/

# Backup ZooKeeper node 1
tar -czf zookeeper-1-backup.tar.gz volumes/zookeeper-1/
```

### Restore from Backup

```bash
# Stop cluster
docker compose down

# Restore data
tar -xzf nifi-cluster-backup-YYYYMMDD.tar.gz

# Start cluster
docker compose up -d
```

## Security Recommendations

1. **Change default passwords** in `.env` before deployment
2. **Use HTTPS only** (disable HTTP in production)
3. **Enable mutual TLS** for production clusters
4. **Restrict network access** using firewall rules
5. **Regular security updates** - keep images up to date
6. **Use secrets management** for production (Docker secrets, Vault)

## Production Deployment

For production environments:

1. Use specific version tags instead of `latest`
2. Set up proper TLS certificates
3. Configure external authentication (LDAP, OIDC)
4. Enable authorization policies
5. Set up monitoring (Prometheus, Grafana)
6. Configure log aggregation (ELK, Splunk)
7. Implement backup automation
8. Use Docker Swarm or Kubernetes for orchestration

## Resources

- [Apache NiFi Documentation](https://nifi.apache.org/docs.html)
- [NiFi Administration Guide](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html)
- [ZooKeeper Documentation](https://zookeeper.apache.org/doc/current/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

## License

This configuration is provided as-is for use with Apache NiFi and Apache ZooKeeper.
