# NiFi Cluster Quick Start Guide

## Super Simple Commands - Just Provide the Cluster Name!

All tools now automatically detect parameters. You only need to provide the cluster name!

### Quick Reference

```bash
# List all clusters
./cluster list

# Create a cluster (still needs parameters for creation)
./create-cluster.sh cluster01 1 3

# Validate configuration
./validate cluster01              # Auto-detects everything!

# Start cluster
./cluster start cluster01

# Wait for cluster to be ready
./cluster wait cluster01

# Check status
./cluster status cluster01
# OR
./check-cluster.sh cluster01

# Test cluster
./test cluster01                  # Auto-detects ports, nodes, etc.!

# View cluster info
./cluster info cluster01

# Stop cluster
./cluster stop cluster01
```

## Comparison: Old vs New

### Old Way (Many Parameters) ❌
```bash
# Had to remember/calculate everything
./validate-cluster.sh cluster01 3
./test-cluster.sh cluster01 3 30443
docker compose -f docker-compose-cluster01.yml logs -f nifi-1
```

### New Way (Just Cluster Name) ✅
```bash
# Everything auto-detected
./validate cluster01
./test cluster01
./cluster logs cluster01
```

## Complete Workflow Example

### 1. Create a Cluster
```bash
# Create 3-node cluster (still needs parameters for creation)
./create-cluster.sh cluster01 1 3
```

### 2. Validate Before Starting
```bash
# Validate configuration (auto-detects 3 nodes, ports, etc.)
./validate cluster01

# Output shows auto-detected parameters:
#   Cluster Name:   cluster01
#   Cluster Number: 1         <- Auto-detected from name
#   Node Count:     3         <- Auto-detected from docker-compose
#   Base Port:      30000     <- Auto-calculated
```

### 3. Start and Monitor
```bash
# Start the cluster
./cluster start cluster01

# Wait for it to be ready (auto-waits up to 3 minutes)
./cluster wait cluster01

# Check detailed status
./cluster status cluster01
```

### 4. Test Everything
```bash
# Comprehensive testing (auto-detects all parameters)
./test cluster01

# Tests performed automatically:
#   - Web UI access on all nodes
#   - Authentication
#   - Backend API
#   - Cluster connectivity
#   - ZooKeeper health
#   - SSL/TLS certificates
```

### 5. Daily Operations
```bash
# Quick status check
./cluster list
./cluster status cluster01

# View logs
./cluster logs cluster01

# Restart
./cluster restart cluster01

# Stop
./cluster stop cluster01
```

## All Available Commands

### Cluster Management (`./cluster`)
```bash
./cluster list                    # List all clusters with status
./cluster info <cluster>          # Detailed cluster information
./cluster status [cluster]        # Health check (all or specific)
./cluster start <cluster>         # Start cluster
./cluster stop <cluster>          # Stop cluster
./cluster restart <cluster>       # Restart cluster
./cluster logs <cluster>          # Follow logs
./cluster wait <cluster>          # Wait for ready state
./cluster validate <cluster>      # Validate configuration
```

### Validation (`./validate`)
```bash
./validate cluster01              # Validate cluster01
./validate cluster02              # Validate cluster02
```

**Checks:**
- ✓ Directory structure
- ✓ Certificates
- ✓ Configuration files
- ✓ Node addresses
- ✓ ZooKeeper settings
- ✓ Docker Compose syntax
- ✓ Port conflicts

### Testing (`./test`)
```bash
./test cluster01                  # Test cluster01
./test cluster02                  # Test cluster02
```

**Tests:**
- ✓ Prerequisites (tools, certificates)
- ✓ Container status
- ✓ Web UI access (HTTPS)
- ✓ Authentication & JWT tokens
- ✓ Backend API
- ✓ Cluster status
- ✓ ZooKeeper health
- ✓ SSL/TLS validation

### Status Check (`./check-cluster.sh`)
```bash
./check-cluster.sh                # Check all clusters
./check-cluster.sh cluster01      # Check specific cluster
```

**Shows:**
- ✓ Node readiness
- ✓ Startup time
- ✓ Summary (ready/starting/failed)
- ✓ Access URLs

## Examples

### Scenario 1: Quick Health Check
```bash
# One command to see everything
./cluster list

# Output:
#   ● cluster01     3 nodes  Port: 30000  Status: running
#   ● cluster02     3 nodes  Port: 31000  Status: running
```

### Scenario 2: Detailed Investigation
```bash
# Check specific cluster
./check-cluster.sh cluster01

# Output shows each node:
#   cluster01.nifi-1: ✓ READY - Started Application in 87.281 seconds
#   cluster01.nifi-2: ✓ READY - Started Application in 92.345 seconds
#   cluster01.nifi-3: ✓ READY - Started Application in 92.245 seconds
#
# Summary:
#   Ready: 3/3
#
# Access URLs:
#   Node 1: https://localhost:30443/nifi
#   Node 2: https://localhost:30444/nifi
#   Node 3: https://localhost:30445/nifi
```

### Scenario 3: Complete Testing
```bash
# Comprehensive test
./test cluster01

# Auto-detects:
#   Cluster Number: 1
#   Node Count:     3
#   HTTPS Ports:    30443-30445
#   ZK Ports:       30181-30183
#
# Then runs all tests automatically!
```

### Scenario 4: Troubleshooting
```bash
# 1. Check status
./cluster status cluster01

# 2. View logs
./cluster logs cluster01

# 3. Get detailed info
./cluster info cluster01

# 4. Validate configuration
./validate cluster01
```

## What Gets Auto-Detected?

| Parameter | How It's Detected | Example |
|-----------|-------------------|---------|
| **Cluster Number** | Extracted from name | `cluster01` → `1` |
| **Node Count** | Counted from docker-compose | Finds `cluster01-nifi-*` services |
| **Base Port** | Calculated from number | `29000 + (1 * 1000)` = `30000` |
| **HTTPS Ports** | Base + 443 + node index | `30443, 30444, 30445` |
| **ZK Ports** | Base + 181 + node index | `30181, 30182, 30183` |
| **S2S Ports** | Base + 100 + node index | `30100, 30101, 30102` |
| **Container Names** | From cluster name | `cluster01.nifi-1` |
| **Service Names** | From cluster name | `cluster01-nifi-1` |

## Benefits

### Before (Old Scripts) ❌
- Required 2-3 parameters minimum
- Had to remember cluster numbers
- Had to calculate ports manually
- Different commands for different tasks
- Confusing parameter order

### After (New Scripts) ✅
- **One parameter**: cluster name
- **Auto-detection**: everything else figured out automatically
- **Consistent**: same pattern for all tools
- **Simple**: easy to remember
- **Fast**: less typing, fewer errors

## Environment Variables

Some tools support environment variables:

```bash
# For testing
export NIFI_USERNAME=admin
export NIFI_PASSWORD=your-password

./test cluster01
```

## Help

All tools have built-in help:

```bash
./cluster --help
./validate --help
./test --help
./check-cluster.sh --help
```

## Tips

1. **Always validate before starting**: `./validate cluster01`
2. **Use wait after start**: `./cluster wait cluster01`
3. **Check status regularly**: `./cluster status`
4. **Test after major changes**: `./test cluster01`
5. **Keep it simple**: Just provide the cluster name!

## Common Tasks

### Morning Startup
```bash
./cluster start cluster01
./cluster wait cluster01
./cluster status cluster01
```

### Evening Shutdown
```bash
./cluster stop cluster01
```

### After Configuration Changes
```bash
./validate cluster01
./cluster restart cluster01
./cluster wait cluster01
./test cluster01
```

### Troubleshooting
```bash
./cluster status cluster01      # Quick check
./check-cluster.sh cluster01    # Detailed status
./cluster logs cluster01        # View logs
./cluster info cluster01        # Full info
```

## Summary

**Remember:** Just provide the cluster name, everything else is automatic!

```bash
./validate cluster01
./test cluster01
./cluster status cluster01
```

That's it! 🚀
