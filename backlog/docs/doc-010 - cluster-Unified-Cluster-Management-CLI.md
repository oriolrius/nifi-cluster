---
id: doc-010
title: cluster - Unified Cluster Management CLI
type: other
created_date: '2025-11-13 14:33'
---
# cluster - Unified Cluster Management CLI

## Overview

The `cluster` script is a unified command-line interface that provides a consistent, user-friendly way to manage NiFi clusters throughout their entire lifecycle. It acts as a wrapper around multiple specialized scripts, offering intuitive subcommands for all common cluster operations.

## Purpose

- **Single entry point:** One command for all cluster operations
- **Consistent interface:** Unified syntax across all operations
- **Simplified workflow:** No need to remember multiple script names and paths
- **Built-in help:** Comprehensive help system for all subcommands
- **Auto-detection:** Automatically discovers cluster parameters
- **CI/CD friendly:** Exit codes and scriptable output

## Script Architecture

```
cluster (Unified CLI Orchestrator)
├── Dependencies
│   ├── lib/cluster-utils.sh (utility functions)
│   ├── lib/check-cluster.sh (health checking)
│   ├── create-cluster.sh (cluster creation)
│   ├── delete-cluster.sh (cluster deletion)
│   ├── validate (configuration validation)
│   ├── test (runtime testing)
│   ├── generate-docker-compose.sh (compose regeneration)
│   └── Docker Compose (container orchestration)
│
├── Command Parsing
│   ├── Subcommand dispatch
│   ├── Argument validation
│   └── Help system
│
└── Subcommands (20+ operations)
    ├── Cluster Lifecycle
    │   ├── create - Create new cluster
    │   ├── start - Start cluster containers
    │   ├── stop - Stop cluster containers
    │   ├── restart - Restart cluster
    │   ├── delete - Remove cluster completely
    │   └── recreate - Delete and recreate cluster
    │
    ├── Status & Monitoring
    │   ├── status - Show cluster status
    │   ├── ps - List containers
    │   ├── health - Check cluster health
    │   ├── wait - Wait for cluster readiness
    │   └── info - Display cluster information
    │
    ├── Logs & Debugging
    │   ├── logs - View container logs
    │   ├── follow - Follow logs in real-time
    │   ├── exec - Execute command in container
    │   └── shell - Interactive shell in container
    │
    ├── Testing & Validation
    │   ├── validate - Validate configuration
    │   ├── test - Run comprehensive tests
    │   └── check - Quick health check
    │
    ├── Configuration Management
    │   ├── reconfig - Regenerate configuration
    │   ├── ports - Show port mappings
    │   └── inspect - Inspect cluster details
    │
    └── Utility Operations
        ├── list - List all clusters
        ├── url - Get NiFi UI URL
        └── compose - Direct docker-compose passthrough
```

## Command Syntax

### General Format

```bash
./cluster <SUBCOMMAND> <CLUSTER_NAME> [OPTIONS]
```

### Special Commands (No Cluster Name Required)

```bash
./cluster list           # List all available clusters
./cluster help           # Show general help
./cluster help <SUBCOMMAND>  # Show subcommand help
```

## Subcommands Reference

### Cluster Lifecycle Commands

#### `create` - Create New Cluster

**Syntax:**
```bash
./cluster create <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
```

**Description:**
Creates a complete cluster setup including:
- SSL/TLS certificates
- Configuration files
- Volume directories
- Docker Compose file

**Parameters:**
- `CLUSTER_NAME` - Descriptive name (format: clusterXX)
- `CLUSTER_NUM` - Numeric identifier for port calculation (≥ 0)
- `NODE_COUNT` - Number of NiFi and ZooKeeper nodes (≥ 1)

**Examples:**
```bash
./cluster create cluster01 1 3     # 3-node cluster on ports 30xxx
./cluster create cluster02 2 3     # 3-node cluster on ports 31xxx
./cluster create cluster03 3 5     # 5-node cluster on ports 32xxx
```

**Delegates to:** `create-cluster.sh`

**Exit Codes:**
- 0 - Success
- 1 - Creation failed

---

#### `start` - Start Cluster

**Syntax:**
```bash
./cluster start <CLUSTER_NAME> [OPTIONS]
```

**Description:**
Starts all cluster containers (ZooKeeper + NiFi nodes)

**Options:**
- `--detach`, `-d` - Run in background (default)
- `--wait` - Wait for cluster to be ready after starting
- `--build` - Rebuild images before starting

**Examples:**
```bash
./cluster start cluster01              # Start in background
./cluster start cluster01 --wait       # Start and wait for readiness
./cluster start cluster01 -d           # Explicit detached mode
```

**Delegates to:** `docker compose up`

**Exit Codes:**
- 0 - Success
- 1 - Start failed

---

#### `stop` - Stop Cluster

**Syntax:**
```bash
./cluster stop <CLUSTER_NAME> [OPTIONS]
```

**Description:**
Gracefully stops all cluster containers without removing them

**Options:**
- `--timeout <seconds>` - Timeout before force kill (default: 10)

**Examples:**
```bash
./cluster stop cluster01               # Stop with default timeout
./cluster stop cluster01 --timeout 30  # Stop with 30s timeout
```

**Delegates to:** `docker compose stop`

**Exit Codes:**
- 0 - Success
- 1 - Stop failed

**Note:** Containers remain available for `start` command

---

#### `restart` - Restart Cluster

**Syntax:**
```bash
./cluster restart <CLUSTER_NAME> [NODE]
```

**Description:**
Restarts cluster or specific node

**Parameters:**
- `NODE` - Optional node number (1, 2, 3, etc.)

**Examples:**
```bash
./cluster restart cluster01            # Restart all nodes
./cluster restart cluster01 1          # Restart only node 1
./cluster restart cluster01 nifi-2     # Restart node 2 (with prefix)
```

**Delegates to:** `docker compose restart`

**Exit Codes:**
- 0 - Success
- 1 - Restart failed

---

#### `delete` - Remove Cluster

**Syntax:**
```bash
./cluster delete <CLUSTER_NAME> [--force]
```

**Description:**
Completely removes cluster including:
- Docker containers and networks
- Configuration files
- Volume data (WARNING: DATA LOSS)
- Docker Compose file

**Options:**
- `--force`, `-f` - Skip confirmation prompt

**Examples:**
```bash
./cluster delete cluster01             # Delete with confirmation
./cluster delete cluster01 --force     # Delete without confirmation
```

**Delegates to:** `delete-cluster.sh`

**Exit Codes:**
- 0 - Success
- 1 - Deletion failed or cancelled

**Note:** Shared CA (certs/ca/) is preserved

---

#### `recreate` - Recreate Cluster

**Syntax:**
```bash
./cluster recreate <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
```

**Description:**
Deletes and recreates cluster with same or different configuration

**Parameters:**
- Same as `create` command

**Examples:**
```bash
./cluster recreate cluster01 1 3       # Recreate with same config
./cluster recreate cluster01 1 5       # Recreate with 5 nodes instead of 3
```

**Workflow:**
1. Delete cluster (with confirmation)
2. Create new cluster with specified parameters
3. Optionally start if `--start` flag provided

**Exit Codes:**
- 0 - Success
- 1 - Recreate failed

---

### Status & Monitoring Commands

#### `status` - Show Cluster Status

**Syntax:**
```bash
./cluster status <CLUSTER_NAME>
```

**Description:**
Displays comprehensive cluster status including:
- Container states (running/stopped/exited)
- Cluster connectivity (connected nodes)
- ZooKeeper ensemble health
- Port mappings
- Disk usage

**Output Format:**
```
════════════════════════════════════════
 Cluster Status: cluster01
════════════════════════════════════════

Containers:
  ✓ cluster01.nifi-1      running (2m)
  ✓ cluster01.nifi-2      running (2m)
  ✓ cluster01.nifi-3      running (2m)
  ✓ cluster01.zookeeper-1 running (2m)
  ✓ cluster01.zookeeper-2 running (2m)
  ✓ cluster01.zookeeper-3 running (2m)

Cluster Health:
  Connected Nodes: 3 / 3
  Cluster Active: Yes
  Coordinator: cluster01.nifi-1

Ports:
  Node 1: https://localhost:30443/nifi
  Node 2: https://localhost:30444/nifi
  Node 3: https://localhost:30445/nifi

Disk Usage:
  Total: 2.3G
```

**Delegates to:** Custom status checking logic + `lib/cluster-utils.sh`

**Exit Codes:**
- 0 - Cluster healthy
- 1 - Cluster unhealthy or not running

---

#### `ps` - List Containers

**Syntax:**
```bash
./cluster ps <CLUSTER_NAME> [OPTIONS]
```

**Description:**
Lists all containers for the cluster

**Options:**
- `--all`, `-a` - Show stopped containers
- `--quiet`, `-q` - Only show container IDs

**Examples:**
```bash
./cluster ps cluster01                 # Show running containers
./cluster ps cluster01 --all           # Show all containers
./cluster ps cluster01 -q              # Only container IDs
```

**Delegates to:** `docker compose ps`

**Exit Codes:**
- 0 - Success
- 1 - Failed

---

#### `health` - Check Cluster Health

**Syntax:**
```bash
./cluster health <CLUSTER_NAME>
```

**Description:**
Performs quick health check:
- Containers running
- NiFi UI responding
- Cluster connected
- ZooKeeper responding

**Output:**
```
[✓] All containers running
[✓] NiFi UI accessible
[✓] Cluster fully connected (3/3)
[✓] ZooKeeper healthy

Cluster is healthy!
```

**Delegates to:** `lib/check-cluster.sh` (if available) or custom health logic

**Exit Codes:**
- 0 - Healthy
- 1 - Unhealthy

---

#### `wait` - Wait for Cluster Readiness

**Syntax:**
```bash
./cluster wait <CLUSTER_NAME> [OPTIONS]
```

**Description:**
Waits for cluster to be fully operational before returning

**Options:**
- `--timeout <seconds>` - Maximum wait time (default: 300)
- `--interval <seconds>` - Check interval (default: 10)
- `--quiet` - Suppress progress output

**Examples:**
```bash
./cluster wait cluster01               # Wait up to 5 minutes
./cluster wait cluster01 --timeout 600 # Wait up to 10 minutes
./cluster wait cluster01 --quiet       # Silent mode
```

**Wait Conditions:**
- All containers running
- All NiFi nodes responding to HTTPS
- Cluster fully connected
- ZooKeeper ensemble healthy

**Output:**
```
Waiting for cluster01 to be ready...
[30s] Containers starting... (6/6)
[60s] NiFi nodes starting... (2/3)
[90s] Cluster connecting... (2/3)
[120s] ✓ Cluster ready!

Total wait time: 2m 0s
```

**Exit Codes:**
- 0 - Cluster ready
- 1 - Timeout reached

---

#### `info` - Display Cluster Information

**Syntax:**
```bash
./cluster info <CLUSTER_NAME>
```

**Description:**
Shows detailed cluster configuration and parameters

**Output:**
```
Cluster Information: cluster01
═════════════════════════════════════════════════

Configuration:
  Cluster Number:     1
  Node Count:         3
  Base Port:          30000
  HTTPS Ports:        30443, 30444, 30445
  ZooKeeper Ports:    30181, 30182, 30183
  S2S Ports:          30100, 30101, 30102

Paths:
  Workspace:          clusters/cluster01/
  Compose File:       docker-compose-cluster01.yml
  Certificates:       clusters/cluster01/certs/
  Configuration:      clusters/cluster01/conf/
  Volumes:            clusters/cluster01/volumes/

URLs:
  Node 1:             https://localhost:30443/nifi
  Node 2:             https://localhost:30444/nifi
  Node 3:             https://localhost:30445/nifi

Credentials:
  Username:           admin
  Password:           changeme123456
```

**Delegates to:** `lib/cluster-utils.sh` (print_cluster_info)

**Exit Codes:**
- 0 - Success
- 1 - Cluster not found

---

### Logs & Debugging Commands

#### `logs` - View Container Logs

**Syntax:**
```bash
./cluster logs <CLUSTER_NAME> [SERVICE] [OPTIONS]
```

**Description:**
Views logs from cluster containers

**Parameters:**
- `SERVICE` - Optional service name (nifi-1, nifi-2, zookeeper-1, etc.)

**Options:**
- `--tail <lines>` - Number of lines to show (default: 100)
- `--since <time>` - Show logs since time (e.g., 2m, 1h)
- `--timestamps` - Show timestamps

**Examples:**
```bash
./cluster logs cluster01                       # All services
./cluster logs cluster01 nifi-1                # Only node 1
./cluster logs cluster01 nifi-1 --tail 50      # Last 50 lines
./cluster logs cluster01 --since 5m            # Last 5 minutes
```

**Delegates to:** `docker compose logs`

**Exit Codes:**
- 0 - Success
- 1 - Failed

---

#### `follow` - Follow Logs in Real-Time

**Syntax:**
```bash
./cluster follow <CLUSTER_NAME> [SERVICE]
```

**Description:**
Streams logs in real-time (alias for `logs --follow`)

**Examples:**
```bash
./cluster follow cluster01                     # Follow all services
./cluster follow cluster01 nifi-2              # Follow node 2
```

**Delegates to:** `docker compose logs -f`

**Exit Codes:**
- 0 - Success
- 1 - Failed

---

#### `exec` - Execute Command in Container

**Syntax:**
```bash
./cluster exec <CLUSTER_NAME> <NODE> <COMMAND>
```

**Description:**
Executes command in running container

**Parameters:**
- `NODE` - Node number or full service name (1, 2, nifi-1, zookeeper-1)
- `COMMAND` - Command to execute

**Examples:**
```bash
./cluster exec cluster01 1 ls -la /opt/nifi/nifi-current/logs
./cluster exec cluster01 nifi-2 cat conf/nifi.properties
./cluster exec cluster01 zookeeper-1 zkCli.sh
```

**Delegates to:** `docker compose exec`

**Exit Codes:**
- 0 - Command succeeded
- Non-zero - Command exit code

---

#### `shell` - Interactive Shell in Container

**Syntax:**
```bash
./cluster shell <CLUSTER_NAME> <NODE>
```

**Description:**
Opens interactive shell in container

**Parameters:**
- `NODE` - Node number or full service name

**Examples:**
```bash
./cluster shell cluster01 1                    # Shell in nifi-1
./cluster shell cluster01 nifi-2               # Shell in nifi-2
./cluster shell cluster01 zookeeper-1          # Shell in zookeeper-1
```

**Delegates to:** `docker compose exec <service> bash`

**Exit Codes:**
- 0 - Shell exited normally
- Non-zero - Shell exit code

---

### Testing & Validation Commands

#### `validate` - Validate Configuration

**Syntax:**
```bash
./cluster validate <CLUSTER_NAME>
```

**Description:**
Validates cluster configuration before starting:
- Directory structure
- Certificates
- Configuration files
- Node addresses
- ZooKeeper configuration
- Docker Compose syntax
- Port conflicts

**Output:**
```
[✓] Directory structure valid
[✓] Certificates valid
[✓] Configuration files valid
[✓] Node addresses correct
[✓] ZooKeeper configuration correct
[✓] Docker Compose valid
[✓] No port conflicts

Validation passed! (31/31 checks)
```

**Delegates to:** `validate` script

**Exit Codes:**
- 0 - All validations passed
- 1 - Validation failures

---

#### `test` - Run Comprehensive Tests

**Syntax:**
```bash
./cluster test <CLUSTER_NAME>
```

**Description:**
Runs comprehensive runtime tests:
- Prerequisites
- Container status
- Web UI access
- Authentication
- API access
- Cluster status
- ZooKeeper health
- SSL/TLS validation
- Flow replication

**Output:**
```
[✓] Prerequisites check (4/4)
[✓] Container status (6/6)
[✓] Web UI access (3/3)
[✓] Authentication (3/3)
[✓] API access (3/3)
[✓] Cluster status (2/2)
[✓] ZooKeeper health (3/3)
[✓] SSL/TLS validation (3/3)
[✓] Flow replication (1/1)

All tests passed! (32/32)
```

**Delegates to:** `test` script

**Exit Codes:**
- 0 - All tests passed
- 1 - Test failures

---

#### `check` - Quick Health Check

**Syntax:**
```bash
./cluster check <CLUSTER_NAME>
```

**Description:**
Quick health check (faster than `test`, less comprehensive than `health`)

**Checks:**
- Containers running
- Basic connectivity

**Delegates to:** `lib/check-cluster.sh` or custom logic

**Exit Codes:**
- 0 - Basic health OK
- 1 - Issues detected

---

### Configuration Management Commands

#### `reconfig` - Regenerate Configuration

**Syntax:**
```bash
./cluster reconfig <CLUSTER_NAME> [OPTIONS]
```

**Description:**
Regenerates cluster configuration files without recreating volumes

**Options:**
- `--certs` - Regenerate certificates
- `--config` - Regenerate NiFi configuration
- `--compose` - Regenerate Docker Compose file
- `--all` - Regenerate everything (default if no options)

**Examples:**
```bash
./cluster reconfig cluster01                   # Regenerate all
./cluster reconfig cluster01 --certs           # Only certificates
./cluster reconfig cluster01 --config          # Only configs
./cluster reconfig cluster01 --compose         # Only compose file
```

**Use Cases:**
- Update DOMAIN in .env
- Change passwords
- Fix configuration errors
- Update to new configuration templates

**Workflow:**
1. Stops cluster
2. Regenerates specified configuration
3. Prompts to restart

**Exit Codes:**
- 0 - Success
- 1 - Failed

---

#### `ports` - Show Port Mappings

**Syntax:**
```bash
./cluster ports <CLUSTER_NAME>
```

**Description:**
Displays all port mappings for the cluster

**Output:**
```
Cluster: cluster01
═════════════════════════════════════════════════

NiFi HTTPS Ports:
  Node 1:    30443 → cluster01.nifi-1:30443
  Node 2:    30444 → cluster01.nifi-2:30444
  Node 3:    30445 → cluster01.nifi-3:30445

Site-to-Site Ports:
  Node 1:    30100 → cluster01.nifi-1:30100
  Node 2:    30101 → cluster01.nifi-2:30101
  Node 3:    30102 → cluster01.nifi-3:30102

ZooKeeper Client Ports:
  ZK 1:      30181 → cluster01.zookeeper-1:2181
  ZK 2:      30182 → cluster01.zookeeper-2:2181
  ZK 3:      30183 → cluster01.zookeeper-3:2181

Internal Ports (not exposed):
  Cluster Protocol:    8082
  Load Balancing:      6342
```

**Delegates to:** `lib/cluster-utils.sh` + docker compose port parsing

**Exit Codes:**
- 0 - Success
- 1 - Failed

---

#### `inspect` - Inspect Cluster Details

**Syntax:**
```bash
./cluster inspect <CLUSTER_NAME> [OPTIONS]
```

**Description:**
Shows detailed cluster information for debugging

**Options:**
- `--json` - Output as JSON
- `--yaml` - Output as YAML

**Output:**
Shows Docker inspect output for all cluster containers

**Delegates to:** `docker inspect`

**Exit Codes:**
- 0 - Success
- 1 - Failed

---

### Utility Operations

#### `list` - List All Clusters

**Syntax:**
```bash
./cluster list [OPTIONS]
```

**Description:**
Lists all available clusters

**Options:**
- `--running` - Only show running clusters
- `--stopped` - Only show stopped clusters
- `--verbose` - Show detailed information

**Output:**
```
Available Clusters:
═════════════════════════════════════════════════

cluster01 (3 nodes, running)
  HTTPS: 30443-30445
  Status: 3/3 nodes connected

cluster02 (3 nodes, stopped)
  HTTPS: 31443-31445
  Status: stopped

cluster03 (5 nodes, running)
  HTTPS: 32443-32447
  Status: 5/5 nodes connected
```

**Delegates to:** `lib/cluster-utils.sh` (get_all_clusters)

**Exit Codes:**
- 0 - Success
- 1 - Failed

---

#### `url` - Get NiFi UI URL

**Syntax:**
```bash
./cluster url <CLUSTER_NAME> [NODE]
```

**Description:**
Returns the NiFi UI URL for the cluster or specific node

**Parameters:**
- `NODE` - Optional node number (default: 1)

**Examples:**
```bash
./cluster url cluster01                # Node 1 URL
./cluster url cluster01 2              # Node 2 URL
```

**Output:**
```
https://localhost:30443/nifi
```

**Use Cases:**
- Quick copy-paste to browser
- Scripting: `open $(./cluster url cluster01)`

**Exit Codes:**
- 0 - Success
- 1 - Cluster not found

---

#### `compose` - Direct Docker Compose Passthrough

**Syntax:**
```bash
./cluster compose <CLUSTER_NAME> <COMPOSE_ARGS...>
```

**Description:**
Passes arguments directly to docker-compose for the cluster

**Examples:**
```bash
./cluster compose cluster01 config                # Validate compose file
./cluster compose cluster01 pull                  # Pull images
./cluster compose cluster01 build --no-cache      # Rebuild images
./cluster compose cluster01 exec nifi-1 bash      # Direct exec
```

**Use Case:**
Access any docker-compose command not wrapped by cluster CLI

**Delegates to:** `docker compose -f docker-compose-<CLUSTER_NAME>.yml`

**Exit Codes:**
- Varies by docker-compose command

---

## Global Options

Available for all subcommands:

| Option | Description |
|--------|-------------|
| `-h`, `--help` | Show help for subcommand |
| `-v`, `--verbose` | Enable verbose output |
| `--dry-run` | Show what would be done (don't execute) |
| `--quiet` | Suppress non-error output |

## Help System

### General Help

```bash
./cluster help
./cluster --help
./cluster
```

**Output:**
```
NiFi Cluster Management CLI

Usage: ./cluster <SUBCOMMAND> <CLUSTER_NAME> [OPTIONS]

Lifecycle Commands:
  create      Create a new cluster
  start       Start cluster containers
  stop        Stop cluster containers
  restart     Restart cluster or node
  delete      Remove cluster completely
  recreate    Delete and recreate cluster

Status & Monitoring:
  status      Show cluster status
  ps          List containers
  health      Check cluster health
  wait        Wait for cluster readiness
  info        Display cluster information

Logs & Debugging:
  logs        View container logs
  follow      Follow logs in real-time
  exec        Execute command in container
  shell       Interactive shell in container

Testing & Validation:
  validate    Validate configuration
  test        Run comprehensive tests
  check       Quick health check

Configuration:
  reconfig    Regenerate configuration
  ports       Show port mappings
  inspect     Inspect cluster details

Utilities:
  list        List all clusters
  url         Get NiFi UI URL
  compose     Docker compose passthrough

Run './cluster help <SUBCOMMAND>' for detailed help on any command.
```

### Subcommand Help

```bash
./cluster help start
./cluster start --help
```

**Output:**
```
Usage: ./cluster start <CLUSTER_NAME> [OPTIONS]

Start all cluster containers (ZooKeeper + NiFi nodes)

Options:
  -d, --detach       Run in background (default)
  --wait             Wait for cluster to be ready
  --build            Rebuild images before starting
  -h, --help         Show this help

Examples:
  ./cluster start cluster01
  ./cluster start cluster01 --wait
  ./cluster start cluster01 --build

See also:
  stop, restart, status, wait
```

## Workflow Examples

### Complete Cluster Lifecycle

```bash
# 1. Create cluster
./cluster create cluster01 1 3

# 2. Validate configuration
./cluster validate cluster01

# 3. Start cluster
./cluster start cluster01

# 4. Wait for readiness
./cluster wait cluster01

# 5. Test cluster
./cluster test cluster01

# 6. Get URL and open in browser
./cluster url cluster01

# 7. Check status
./cluster status cluster01

# 8. View logs
./cluster logs cluster01 nifi-1 --tail 100

# 9. Stop cluster
./cluster stop cluster01

# 10. Restart cluster
./cluster start cluster01

# 11. Delete cluster
./cluster delete cluster01
```

### Quick Development Workflow

```bash
# Create and start in one go
./cluster create cluster01 1 3 && \
./cluster start cluster01 --wait && \
./cluster test cluster01

# Get URL
open $(./cluster url cluster01)
```

### Troubleshooting Workflow

```bash
# Check status
./cluster status cluster01

# Health check
./cluster health cluster01

# View logs
./cluster follow cluster01

# Execute debug command
./cluster exec cluster01 1 cat /opt/nifi/nifi-current/logs/nifi-app.log

# Shell into container
./cluster shell cluster01 1
```

### Configuration Update Workflow

```bash
# Update .env file
vim .env

# Regenerate configuration
./cluster reconfig cluster01 --config

# Restart cluster to apply changes
./cluster restart cluster01

# Verify changes
./cluster test cluster01
```

## Implementation Details

### Directory Structure

```bash
.
├── cluster                          # Main CLI script (this)
├── lib/
│   ├── cluster-utils.sh            # Utility functions
│   └── check-cluster.sh            # Health checking
├── create-cluster.sh               # Cluster creation
├── delete-cluster.sh               # Cluster deletion
├── validate                        # Configuration validation
├── test                            # Runtime testing
├── generate-docker-compose.sh      # Compose generation
└── docker-compose-cluster*.yml     # Generated compose files
```

### Function Organization

```bash
# Main entry point
main() {
    parse_global_options "$@"
    dispatch_subcommand "$@"
}

# Command dispatch
dispatch_subcommand() {
    case "$1" in
        create)   cmd_create "$@" ;;
        start)    cmd_start "$@" ;;
        stop)     cmd_stop "$@" ;;
        ...
    esac
}

# Individual command implementations
cmd_create() { ... }
cmd_start() { ... }
cmd_stop() { ... }
...
```

### Error Handling

```bash
# Consistent error handling
error() {
    echo "Error: $*" >&2
    exit 1
}

# Validation
validate_cluster_exists() {
    if ! cluster_exists "$CLUSTER_NAME"; then
        error "Cluster '$CLUSTER_NAME' not found"
    fi
}

# Safe command execution
safe_exec() {
    if ! "$@"; then
        error "Command failed: $*"
    fi
}
```

### Auto-Detection Logic

```bash
# Uses lib/cluster-utils.sh
CLUSTER_NUM=$(get_cluster_num "$CLUSTER_NAME")
NODE_COUNT=$(get_node_count "$CLUSTER_NAME")
BASE_PORT=$(get_base_port "$CLUSTER_NUM")
```

## Exit Codes Summary

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Cluster not found |
| 4 | Cluster already exists |
| 124 | Timeout |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NIFI_USERNAME` | `admin` | NiFi login username |
| `NIFI_PASSWORD` | `changeme123456` | NiFi login password |
| `NIFI_VERSION` | `latest` | NiFi Docker image version |
| `ZOOKEEPER_VERSION` | `3.9` | ZooKeeper Docker image version |
| `DOMAIN` | (empty) | Domain for FQDN resolution |

## Dependencies

### Required

- `bash` (4.0+)
- `docker` and `docker compose`
- `lib/cluster-utils.sh`
- Individual operation scripts (create-cluster.sh, etc.)

### Optional (Enhanced Functionality)

- `jq` - JSON parsing for status/info commands
- `curl` - API testing
- `openssl` - Certificate validation

## Best Practices

### Always Validate Before Starting

```bash
./cluster create cluster01 1 3
./cluster validate cluster01 && ./cluster start cluster01
```

### Use wait Before Testing

```bash
./cluster start cluster01
./cluster wait cluster01
./cluster test cluster01
```

### Check Status Regularly

```bash
# Quick check
./cluster health cluster01

# Detailed status
./cluster status cluster01
```

### Save URLs for Quick Access

```bash
# Save to file
./cluster url cluster01 > cluster01-url.txt

# Open in browser (macOS)
open $(./cluster url cluster01)

# Open in browser (Linux)
xdg-open $(./cluster url cluster01)
```

## Troubleshooting

### Problem: "Cluster not found"

```bash
# List available clusters
./cluster list

# Create if needed
./cluster create cluster01 1 3
```

### Problem: Commands fail silently

```bash
# Use verbose mode
./cluster --verbose status cluster01

# Check cluster exists
./cluster list
```

### Problem: Can't remember subcommand

```bash
# Show all commands
./cluster help

# Show command help
./cluster help <command>
```

## Integration with Other Tools

### CI/CD Pipeline

```yaml
# .gitlab-ci.yml
test-cluster:
  script:
    - ./cluster create test-cluster 99 3
    - ./cluster validate test-cluster
    - ./cluster start test-cluster --wait
    - ./cluster test test-cluster
    - ./cluster delete test-cluster --force
```

### Monitoring Script

```bash
#!/bin/bash
# cluster-monitor.sh

for cluster in $(./cluster list --quiet); do
    if ! ./cluster health "$cluster" --quiet; then
        echo "Alert: $cluster is unhealthy!"
        ./cluster status "$cluster"
    fi
done
```

### Backup Script

```bash
#!/bin/bash
# cluster-backup.sh

CLUSTER=$1
./cluster stop "$CLUSTER"
tar -czf "${CLUSTER}-backup-$(date +%Y%m%d).tar.gz" "clusters/$CLUSTER/"
./cluster start "$CLUSTER"
```

## Related Documentation

- `create-cluster.sh` - Cluster creation (doc-006)
- `delete-cluster.sh` - Cluster deletion (doc-007)
- `validate` - Configuration validation (doc-008)
- `test` - Runtime testing (doc-009)
- `lib/cluster-utils.sh` - Utility functions

## Summary

The `cluster` CLI provides:
- **Unified interface:** Single command for all operations
- **Intuitive syntax:** Consistent subcommand pattern
- **Auto-detection:** No need to remember cluster parameters
- **Comprehensive help:** Built-in documentation
- **Complete lifecycle:** Create to delete
- **Flexible workflows:** Compose multiple commands
- **CI/CD friendly:** Scriptable with proper exit codes

**Key Principle:** One command to rule them all. The `cluster` CLI is the primary interface for all cluster management operations.
