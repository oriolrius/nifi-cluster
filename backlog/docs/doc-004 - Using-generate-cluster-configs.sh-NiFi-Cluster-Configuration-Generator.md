---
id: doc-004
title: Using generate-cluster-configs.sh - NiFi Cluster Configuration Generator
type: other
created_date: '2025-11-11 16:19'
---
# Using generate-cluster-configs.sh - NiFi Cluster Configuration Generator

## Overview

The `generate-cluster-configs.sh` script is a fundamental tool for creating NiFi cluster configurations from templates. It automates the generation of all necessary configuration files for any number of NiFi nodes with consistent, calculated port assignments.

**Location**: `conf/generate-cluster-configs.sh`

## Why Use This Script?

Manual configuration of NiFi clusters is error-prone and time-consuming. This script ensures:

- **Consistency**: All nodes use the same cluster-wide settings
- **Correctness**: Node-specific values are automatically calculated
- **Speed**: Generate configurations for multiple nodes in seconds
- **Flexibility**: Support multiple clusters with different port ranges

## When to Use

Use this script when you need to:

1. **Initialize a new cluster** - First-time setup
2. **Add/remove nodes** - Scale the cluster up or down
3. **Reconfigure ports** - Change port assignments for different clusters
4. **Reset configurations** - Start fresh with clean configs
5. **Create multiple clusters** - Run multiple independent clusters

## Syntax

```bash
./generate-cluster-configs.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
```

### Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `CLUSTER_NAME` | String | Descriptive name for the cluster | `production`, `staging`, `dev` |
| `CLUSTER_NUM` | Integer ≥ 0 | Cluster number for port calculation | `0`, `1`, `2` |
| `NODE_COUNT` | Integer ≥ 1 | Number of nodes in the cluster | `3`, `5`, `7` |

### Port Calculation Formula

The script uses this formula to calculate port ranges:

```
BASE_PORT = 29000 + (CLUSTER_NUM × 1000)
```

Then assigns:
- **HTTPS Ports**: `BASE_PORT + 443` to `BASE_PORT + 443 + NODE_COUNT - 1`
- **Site-to-Site Ports**: `BASE_PORT + 100` to `BASE_PORT + 100 + NODE_COUNT - 1`
- **Cluster Protocol Port**: `BASE_PORT + 82` (same for all nodes)
- **Load Balance Port**: `BASE_PORT + 342` (same for all nodes)

## Examples

### Example 1: Production Cluster (Default)

```bash
cd conf
./generate-cluster-configs.sh production 0 3
```

**Results:**
- Cluster Name: `production`
- Base Port: `29000` (29000 + 0×1000)
- 3 nodes created
- HTTPS Access:
  - Node 1: https://localhost:29443/nifi
  - Node 2: https://localhost:29444/nifi
  - Node 3: https://localhost:29445/nifi

### Example 2: Staging Cluster

```bash
cd conf
./generate-cluster-configs.sh staging 1 3
```

**Results:**
- Cluster Name: `staging`
- Base Port: `30000` (29000 + 1×1000)
- 3 nodes created
- HTTPS Access:
  - Node 1: https://localhost:30443/nifi
  - Node 2: https://localhost:30444/nifi
  - Node 3: https://localhost:30445/nifi

### Example 3: Development Cluster

```bash
cd conf
./generate-cluster-configs.sh dev 2 2
```

**Results:**
- Cluster Name: `dev`
- Base Port: `31000` (29000 + 2×1000)
- 2 nodes created
- HTTPS Access:
  - Node 1: https://localhost:31443/nifi
  - Node 2: https://localhost:31444/nifi

### Example 4: Large Production Cluster

```bash
cd conf
./generate-cluster-configs.sh prod-large 3 7
```

**Results:**
- Cluster Name: `prod-large`
- Base Port: `32000` (29000 + 3×1000)
- 7 nodes created
- HTTPS Access:
  - Node 1: https://localhost:32443/nifi
  - Node 2: https://localhost:32444/nifi
  - ... through Node 7: https://localhost:32449/nifi

## What Gets Generated

For each node (`nifi-1`, `nifi-2`, etc.), the script creates/copies:

### 1. Generated Files

| File | Description | Node-Specific? |
|------|-------------|----------------|
| `nifi.properties` | Main configuration | ✓ Yes |
| `state-management.xml` | ZooKeeper state provider config | ✓ Yes (but values consistent) |

### 2. Copied Files

These are copied from `nifi-1` to other nodes (or should exist from initial setup):

- `authorizers.xml` - Authorization configuration
- `bootstrap.conf` - JVM bootstrap settings
- `logback.xml` - Logging configuration
- `login-identity-providers.xml` - Authentication providers
- `zookeeper.properties` - Embedded ZooKeeper settings (if needed)

### 3. Certificates

Certificates are copied from `certs/nifi-X/` to `conf/nifi-X/`:

- `keystore.p12` - Node's private key and certificate
- `truststore.p12` - CA certificate for cluster trust

## Node-Specific vs Cluster-Wide Settings

### Node-Specific Values (Different for Each Node)

These values are unique per node:

```properties
nifi.cluster.node.address=nifi-1              # nifi-2, nifi-3, etc.
nifi.remote.input.host=nifi-1                 # nifi-2, nifi-3, etc.
nifi.remote.input.socket.port=29100          # 29101, 29102, etc.
```

### Cluster-Wide Values (Same for All Nodes)

These values are identical across the cluster:

```properties
nifi.cluster.node.protocol.port=29082        # Same for all
nifi.cluster.load.balance.port=29342         # Same for all
nifi.zookeeper.connect.string=zookeeper-1:2181,zookeeper-2:2181,zookeeper-3:2181
nifi.sensitive.props.key=changeme_sensitive_key_123
nifi.web.proxy.host=localhost:29443,localhost:29444,localhost:29445,...
```

## Step-by-Step Workflow

### Initial Cluster Setup

1. **Generate certificates first** (if not already done):
   ```bash
   cd certs
   ./generate-certs.sh 3  # For 3 nodes
   cd ..
   ```

2. **Generate configurations**:
   ```bash
   cd conf
   ./generate-cluster-configs.sh production 0 3
   cd ..
   ```

3. **Update docker-compose.yml** (if needed):
   - Ensure port mappings match generated config
   - Current config uses cluster number 0 with ports 59443-59445

4. **Start the cluster**:
   ```bash
   docker compose up -d
   ```

### Scaling the Cluster

#### Adding Nodes (3 → 5 nodes)

1. **Generate certificates for new nodes**:
   ```bash
   cd certs
   ./generate-certs.sh 5  # Regenerate for 5 nodes
   cd ..
   ```

2. **Regenerate all configurations**:
   ```bash
   cd conf
   ./generate-cluster-configs.sh production 0 5
   cd ..
   ```

3. **Update docker-compose.yml**:
   - Add `nifi-4` and `nifi-5` services
   - Add `zookeeper-4` and `zookeeper-5` if needed

4. **Restart cluster**:
   ```bash
   docker compose down
   docker compose up -d
   ```

#### Removing Nodes (3 → 2 nodes)

1. **Stop cluster**:
   ```bash
   docker compose down
   ```

2. **Regenerate configurations**:
   ```bash
   cd conf
   ./generate-cluster-configs.sh production 0 2
   cd ..
   ```

3. **Update docker-compose.yml**:
   - Remove `nifi-3` service
   - Remove `zookeeper-3` if using embedded ZK

4. **Start cluster**:
   ```bash
   docker compose up -d
   ```

### Reconfiguring an Existing Cluster

If you need to change settings across all nodes:

1. **Stop the cluster**:
   ```bash
   docker compose down
   ```

2. **Regenerate configurations**:
   ```bash
   cd conf
   ./generate-cluster-configs.sh production 0 3
   ```

3. **Edit generated files as needed**:
   - Modify `conf/nifi-1/nifi.properties` for custom settings
   - The script copies from nifi-1 to other nodes for standard files

4. **Restart cluster**:
   ```bash
   docker compose up -d
   ```

## Port Ranges by Cluster Number

Quick reference for port assignments:

| Cluster # | Base Port | HTTPS Range | S2S Range | Cluster Proto | Load Balance |
|-----------|-----------|-------------|-----------|---------------|--------------|
| 0 | 29000 | 29443-29445 | 29100-29102 | 29082 | 29342 |
| 1 | 30000 | 30443-30445 | 30100-30102 | 30082 | 30342 |
| 2 | 31000 | 31443-31445 | 31100-31102 | 31082 | 31342 |
| 3 | 32000 | 32443-32445 | 32100-32102 | 32082 | 32342 |
| 4 | 33000 | 33443-33445 | 33100-33102 | 33082 | 33342 |

Each cluster has 1000 ports reserved for growth.

## Validation Checklist

After running the script, verify:

### 1. Configuration Files Exist

```bash
ls -la conf/nifi-1/
ls -la conf/nifi-2/
ls -la conf/nifi-3/
```

Should see:
- nifi.properties
- state-management.xml
- keystore.p12
- truststore.p12
- authorizers.xml
- bootstrap.conf
- etc.

### 2. Port Assignments Are Correct

```bash
grep "nifi.web.https.port" conf/nifi-*/nifi.properties
grep "nifi.remote.input.socket.port" conf/nifi-*/nifi.properties
grep "nifi.cluster.node.protocol.port" conf/nifi-*/nifi.properties
```

### 3. ZooKeeper Connection String

```bash
grep "nifi.zookeeper.connect.string" conf/nifi-1/nifi.properties
grep "Connect String" conf/nifi-1/state-management.xml
```

Should show all ZK nodes: `zookeeper-1:2181,zookeeper-2:2181,zookeeper-3:2181`

### 4. Node Addresses

```bash
grep "nifi.cluster.node.address" conf/nifi-*/nifi.properties
```

Should show: `nifi-1`, `nifi-2`, `nifi-3`, etc.

### 5. Certificates

```bash
ls -la conf/nifi-*/keystore.p12
ls -la conf/nifi-*/truststore.p12
```

All nodes should have both files.

## Common Issues and Solutions

### Issue 1: Certificates Not Found

**Error**: `⚠ Warning: Certificate directory not found: /path/to/certs/nifi-X`

**Solution**:
```bash
cd certs
./generate-certs.sh <NODE_COUNT>
cd ../conf
./generate-cluster-configs.sh production 0 <NODE_COUNT>
```

### Issue 2: Port Conflicts

**Error**: Port already in use when starting Docker

**Solution**: Use a different cluster number:
```bash
./generate-cluster-configs.sh production 1 3  # Use base port 30000 instead of 29000
```

Then update `docker-compose.yml` port mappings to match.

### Issue 3: Nodes Don't Join Cluster

**Symptoms**: Nodes start but don't communicate

**Check**:
1. All nodes have same `nifi.sensitive.props.key`
2. ZooKeeper is running and accessible
3. `nifi.cluster.node.address` matches container hostname
4. All nodes use same certificate CA (truststore)

**Solution**:
```bash
# Verify ZK is up
docker compose logs zookeeper-1

# Verify all nodes have consistent sensitive key
grep "nifi.sensitive.props.key" conf/nifi-*/nifi.properties

# Regenerate if needed
cd conf
./generate-cluster-configs.sh production 0 3
cd ..
docker compose restart
```

### Issue 4: Standard Config Files Missing

**Error**: `login-identity-providers.xml` not found in nifi-2

**Solution**: The script copies from `nifi-1`. Ensure nifi-1 has all files first:
```bash
# Option 1: Start nifi-1 alone first to get defaults
docker compose up -d nifi-1
sleep 30
docker compose cp nifi-1:/opt/nifi/nifi-current/conf/ ./conf/nifi-1/

# Option 2: Copy from NiFi distribution manually
# Then regenerate
cd conf
./generate-cluster-configs.sh production 0 3
```

## Advanced Usage

### Custom Template

To customize the generated configuration:

1. Run the script once to generate defaults
2. Edit `conf/nifi-1/nifi.properties` with your custom values
3. Run the script again - it will use nifi-1 as the template for standard files

### Multiple Clusters on Same Host

Run multiple independent clusters:

```bash
# Cluster 1: Production (3 nodes, ports 29443-29445)
cd conf
./generate-cluster-configs.sh prod 0 3

# Cluster 2: Staging (3 nodes, ports 30443-30445)
./generate-cluster-configs.sh staging 1 3

# Cluster 3: Dev (2 nodes, ports 31443-31444)
./generate-cluster-configs.sh dev 2 2
```

Update each cluster's `docker-compose.yml` with appropriate port mappings.

### Integrating with docker-compose.yml

The script generates internal port `8443` for all nodes. Map to external ports in docker-compose:

```yaml
services:
  nifi-1:
    ports:
      - "29443:8443"  # Cluster 0: BASE_PORT + 443
  nifi-2:
    ports:
      - "29444:8443"  # Cluster 0: BASE_PORT + 444
  nifi-3:
    ports:
      - "29445:8443"  # Cluster 0: BASE_PORT + 445
```

For staging cluster (CLUSTER_NUM=1):
```yaml
services:
  nifi-1:
    ports:
      - "30443:8443"  # Cluster 1: BASE_PORT + 443
  nifi-2:
    ports:
      - "30444:8443"
  nifi-3:
    ports:
      - "30445:8443"
```

## Related Scripts

- **`certs/generate-certs.sh`** - Generate PKI certificates (run before this script)
- **`conf/create-node-properties.sh`** - Legacy script (replaced by generate-cluster-configs.sh)
- **`conf/update-cert-paths.sh`** - Update certificate paths in existing configs

## Best Practices

1. **Always use version control**: Commit generated configs to git
2. **Run certificate generation first**: Certificates must exist before config generation
3. **Keep cluster number consistent**: Don't change CLUSTER_NUM for an existing cluster
4. **Test with small clusters first**: Try NODE_COUNT=2 before scaling to 7+ nodes
5. **Document your cluster number**: Add a comment in docker-compose.yml noting which cluster number you're using
6. **Backup before regenerating**: `tar -czf conf-backup.tar.gz conf/` before running script

## Summary

The `generate-cluster-configs.sh` script is your primary tool for NiFi cluster configuration management. It ensures consistency, correctness, and saves significant time compared to manual configuration.

**Key takeaways:**
- Use CLUSTER_NUM to avoid port conflicts between multiple clusters
- Run certificate generation before configuration generation
- Validate generated configs before starting the cluster
- Keep the script in version control for reproducibility

**Quick command reference:**
```bash
# Standard 3-node cluster
cd conf && ./generate-cluster-configs.sh production 0 3

# Validate
grep "nifi.cluster.node.address" conf/nifi-*/nifi.properties

# Start cluster
cd .. && docker compose up -d
```
