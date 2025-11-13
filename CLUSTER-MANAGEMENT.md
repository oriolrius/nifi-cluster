# NiFi Cluster Management Tools

Simplified cluster management tools that automatically detect cluster parameters. You only need to provide the cluster name!

## Quick Start

```bash
# List all available clusters
./cluster list

# Check status of all clusters
./cluster status

# Check specific cluster
./cluster status cluster01

# Get detailed cluster info
./cluster info cluster01

# Start/stop clusters
./cluster start cluster01
./cluster stop cluster01
./cluster restart cluster01

# Wait for cluster to be ready
./cluster wait cluster01

# Validate cluster configuration
./cluster validate cluster01

# Follow cluster logs
./cluster logs cluster01
```

## Tools Overview

### 1. `./cluster` - Unified Management Tool

The main tool for managing NiFi clusters. All commands automatically detect cluster parameters.

**Commands:**
- `list` - List all available clusters with status
- `info <cluster>` - Show detailed information about a cluster
- `status [cluster]` - Show node status (all or specific cluster)
- `start <cluster>` - Start a cluster
- `stop <cluster>` - Stop a cluster
- `restart <cluster>` - Restart a cluster
- `logs <cluster>` - Follow logs for all nodes
- `wait <cluster>` - Wait for cluster to be fully ready
- `validate <cluster>` - Validate cluster configuration

**Examples:**
```bash
# Check what clusters are available
./cluster list

# Get detailed info about cluster01
./cluster info cluster01

# Start cluster and wait for it to be ready
./cluster start cluster01
./cluster wait cluster01

# Check if all nodes are running
./cluster status cluster01

# Follow logs
./cluster logs cluster01
```

### 2. `./check-cluster.sh` - Cluster Health Check

Check the health and readiness of NiFi clusters. Shows detailed node status.

**Usage:**
```bash
# Check all clusters
./check-cluster.sh

# Check specific cluster(s)
./check-cluster.sh cluster01
./check-cluster.sh cluster01 cluster02
```

**Output includes:**
- Node status (READY, STARTING, NOT RUNNING)
- Application startup information
- Summary of ready/starting/failed nodes
- Access URLs for each node

### 3. `lib/cluster-utils.sh` - Utility Library

Shared library used by management tools. Provides functions for:
- Extracting cluster number from name
- Calculating ports automatically
- Detecting node count from docker-compose files
- Checking cluster status
- Validating cluster configuration

**Key Functions:**
```bash
source lib/cluster-utils.sh

# Get cluster number from name
cluster_num=$(get_cluster_num "cluster01")  # Returns: 1

# Get node count automatically
node_count=$(get_node_count "cluster01")    # Returns: 3 (if 3 nodes)

# Get HTTPS port for a node
port=$(get_https_port 1 1)                  # cluster 1, node 1

# Check if cluster exists
if cluster_exists "cluster01"; then
    echo "Cluster exists"
fi

# Get cluster status
status=$(get_cluster_status "cluster01")    # Returns: running/stopped/not-found

# Get NiFi API URL
url=$(get_cluster_url "cluster01" 1)        # Returns: https://localhost:30443
```

## Naming Conventions

The tools automatically understand these naming patterns:

| Component | Pattern | Example |
|-----------|---------|---------|
| Cluster Name | `cluster[number]` | `cluster01`, `cluster02` |
| Service Name | `{cluster}-nifi-{node}` | `cluster01-nifi-1` |
| Container Name | `{cluster}.nifi-{node}` | `cluster01.nifi-1` |
| Hostname | `{cluster}.nifi-{node}` | `cluster01.nifi-1` |

## Port Calculation

Ports are automatically calculated based on cluster number:

```
BASE_PORT = 29000 + (cluster_num × 1000)

Examples:
  cluster01 (num=1): base=30000, HTTPS=30443-30445, ZK=30181-30183
  cluster02 (num=2): base=31000, HTTPS=31443-31445, ZK=31181-31183
  cluster03 (num=3): base=32000, HTTPS=32443-32445, ZK=32181-32183
```

## Common Workflows

### Check Cluster Status
```bash
# Quick check of all clusters
./cluster list

# Detailed status of specific cluster
./check-cluster.sh cluster01
```

### Start and Monitor Cluster
```bash
# Start the cluster
./cluster start cluster01

# Wait for it to be ready (up to 3 minutes)
./cluster wait cluster01

# Check final status
./cluster status cluster01
```

### Validate Configuration
```bash
# Check if all configuration files are in place
./cluster validate cluster01
```

### Troubleshooting
```bash
# Check detailed node status
./check-cluster.sh cluster01

# Follow logs for issues
./cluster logs cluster01

# Check specific container
docker logs cluster01.nifi-1

# Get cluster info
./cluster info cluster01
```

## Migration from Old Scripts

| Old Command | New Command |
|-------------|-------------|
| `./check-nodes.sh` | `./check-cluster.sh` |
| `./check-all-nodes.sh` | `./cluster status` |
| `docker compose -f docker-compose-cluster01.yml ps` | `./cluster status cluster01` |
| `docker compose -f docker-compose-cluster01.yml up -d` | `./cluster start cluster01` |
| `docker compose -f docker-compose-cluster01.yml down` | `./cluster stop cluster01` |
| `docker compose -f docker-compose-cluster01.yml logs -f` | `./cluster logs cluster01` |

## Benefits

1. **Automatic Parameter Detection** - No need to remember cluster numbers or node counts
2. **Consistent Interface** - Same commands work for all clusters
3. **Better Feedback** - Clear status indicators and error messages
4. **Easier Troubleshooting** - Comprehensive validation and status checks
5. **Safer Operations** - Validates cluster existence before operations

## Advanced Usage

### Scripting with cluster-utils.sh

You can use the utility library in your own scripts:

```bash
#!/bin/bash
source "$(dirname "$0")/lib/cluster-utils.sh"

CLUSTER_NAME="cluster01"

# Validate cluster name
if ! validate_cluster_name "$CLUSTER_NAME"; then
    exit 1
fi

# Get cluster info
CLUSTER_NUM=$(get_cluster_num "$CLUSTER_NAME")
NODE_COUNT=$(get_node_count "$CLUSTER_NAME")
BASE_PORT=$(get_base_port "$CLUSTER_NUM")

echo "Cluster $CLUSTER_NAME has $NODE_COUNT nodes"
echo "Base port: $BASE_PORT"

# Check if running
if cluster_is_running "$CLUSTER_NAME"; then
    echo "Cluster is running"
else
    echo "Cluster is stopped"
fi

# Wait for cluster to be ready
if wait_for_cluster "$CLUSTER_NAME" 180; then
    echo "Cluster is ready!"
else
    echo "Cluster failed to start"
    exit 1
fi
```

## Help

All tools provide help:
```bash
./cluster --help
./check-cluster.sh --help
```
