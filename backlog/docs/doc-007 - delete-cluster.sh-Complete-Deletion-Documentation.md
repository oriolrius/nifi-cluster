---
id: doc-007
title: delete-cluster.sh - Complete Deletion Documentation
type: other
created_date: '2025-11-13 14:20'
---
# delete-cluster.sh - Complete Deletion Documentation

## Overview

`delete-cluster.sh` is a safe cluster removal script that systematically deletes all cluster resources including Docker containers, networks, configuration files, and runtime data while **preserving** the shared Certificate Authority (CA) for use by other clusters.

## Purpose

Provides a safe, auditable, and reversible (with confirmation) way to remove NiFi clusters without affecting:
- The shared CA infrastructure
- Other running clusters
- System-level Docker configuration

## Script Architecture

```
delete-cluster.sh (Standalone Script)
├── Argument Parsing
│   ├── CLUSTER_NAME (required)
│   └── --force/-f flag (optional)
│
├── Validation
│   ├── Cluster name format validation (must match: clusterXX)
│   └── Resource existence checks
│
├── Resource Discovery
│   ├── Check for cluster workspace directory
│   ├── Check for Docker Compose file
│   ├── Check for running/stopped containers
│   └── Calculate workspace size
│
├── Deletion Planning
│   ├── Display what will be deleted
│   ├── Display what will be preserved
│   └── Interactive confirmation (unless --force)
│
└── Deletion Execution (4 Steps)
    ├── Step 1: Stop and remove Docker containers + networks
    ├── Step 2: Delete Docker Compose file
    ├── Step 3: Delete cluster workspace (requires sudo)
    └── Step 4: Verify shared CA preservation
```

## Parameters & Options

### Required Parameter

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `CLUSTER_NAME` | String | Name of cluster to delete (format: clusterXX) | `cluster01`, `cluster02` |

### Optional Flags

| Flag | Description | Effect |
|------|-------------|--------|
| `--force`, `-f` | Skip confirmation prompt | Immediate deletion without user confirmation |
| `--help`, `-h` | Show help message | Display usage information and exit |

### Cluster Name Validation

The script enforces strict naming format:
- **Pattern:** `clusterXX` where XX is exactly 2 digits
- **Valid:** `cluster01`, `cluster02`, `cluster99`
- **Invalid:** `cluster1`, `cluster`, `clstr01`, `cluster001`

## Execution Flow

### Phase 1: Resource Discovery

```bash
# Checked resources:
EXISTS_WORKSPACE=false    # clusters/<CLUSTER_NAME>/
EXISTS_COMPOSE=false      # docker-compose-<CLUSTER_NAME>.yml
EXISTS_CONTAINERS=false   # Docker containers (any state)

# Discovery process:
1. Check for workspace directory: clusters/<CLUSTER_NAME>/
   - Calculate disk usage with du -sh
   
2. Check for Docker Compose file: docker-compose-<CLUSTER_NAME>.yml

3. Check for Docker containers:
   - Pattern match: ^<CLUSTER_NAME>[-.]
   - Includes both running and stopped containers
   - Supports both dash (cluster01-nifi-1) and dot (cluster01.nifi-1) naming
```

**Early Exit Conditions:**
- If no resources found: Script exits with warning (nothing to delete)
- If resources found: Proceed to deletion planning

### Phase 2: Deletion Planning & Confirmation

```
┌─────────────────────────────────────────┐
│ Display Deletion Plan                   │
├─────────────────────────────────────────┤
│ What WILL be deleted:                   │
│   ✗ Docker containers (count + names)   │
│   ✗ Docker Compose file (path)          │
│   ✗ Cluster workspace (path + size)     │
│     - certs/ (node certificates)        │
│     - conf/ (node configurations)       │
│     - volumes/ (runtime data)           │
│                                         │
│ What will be PRESERVED:                 │
│   ✓ Shared Certificate Authority        │
│     certs/ca/ (used by all clusters)    │
└─────────────────────────────────────────┘
```

**Confirmation Prompt:**
- Displayed unless `--force` flag is used
- User must type exactly `yes` to proceed
- Any other input cancels deletion

### Phase 3: Deletion Execution

#### Step 1: Stop and Remove Docker Containers

**Primary Method (preferred):**
```bash
docker compose -f docker-compose-<CLUSTER_NAME>.yml down --volumes
```
- Gracefully stops all containers
- Removes containers, networks, and anonymous volumes
- Preserves named volumes (handled separately)

**Fallback Method (if compose fails):**
```bash
# Manual container removal
for container in $RUNNING_CONTAINERS; do
    docker rm -f "$container"
done
```
- Force removes each container individually
- Used when compose file is missing or corrupted

**Network Cleanup:**
```bash
# Network name pattern: <CLUSTER_NAME>-nifi-cluster_<CLUSTER_NAME>-network
docker network rm "${CLUSTER_NAME}-nifi-cluster_${CLUSTER_NAME}-network"
```

**Container Name Patterns Matched:**
- `cluster01-nifi-1` (dash separator)
- `cluster01.nifi-1` (dot separator)
- `cluster01-zookeeper-1` (dash separator)
- `cluster01.zookeeper-1` (dot separator)

#### Step 2: Delete Docker Compose File

```bash
rm -f docker-compose-<CLUSTER_NAME>.yml
```

**File Deleted:**
- `docker-compose-cluster01.yml`
- `docker-compose-cluster02.yml`
- etc.

**Result:**
- Cluster cannot be restarted without regeneration
- Frees minimal disk space (~few KB)

#### Step 3: Delete Cluster Workspace

```bash
sudo rm -rf clusters/<CLUSTER_NAME>/
```

**Why sudo?**
- Volume directories are owned by UID:GID 1000:1000 (container user)
- May not be writable by current user
- Ensures complete deletion regardless of permissions

**Directory Structure Deleted:**
```
clusters/<CLUSTER_NAME>/
├── volumes/
│   ├── <CLUSTER_NAME>.zookeeper-1/
│   │   ├── data/           # ZooKeeper data
│   │   ├── datalog/        # Transaction logs
│   │   └── logs/           # ZooKeeper logs
│   ├── <CLUSTER_NAME>.zookeeper-2/
│   ├── <CLUSTER_NAME>.zookeeper-3/
│   ├── <CLUSTER_NAME>.nifi-1/
│   │   ├── content_repository/     # FlowFile content (can be LARGE)
│   │   ├── database_repository/    # H2 database
│   │   ├── flowfile_repository/    # FlowFile metadata
│   │   ├── provenance_repository/  # Provenance events (can be LARGE)
│   │   ├── state/                  # Component state
│   │   └── logs/                   # NiFi application logs
│   ├── <CLUSTER_NAME>.nifi-2/
│   └── <CLUSTER_NAME>.nifi-3/
├── conf/
│   ├── <CLUSTER_NAME>.nifi-1/
│   │   ├── nifi.properties
│   │   ├── state-management.xml
│   │   ├── keystore.p12
│   │   ├── truststore.p12
│   │   ├── authorizers.xml
│   │   ├── bootstrap.conf
│   │   ├── logback.xml
│   │   ├── login-identity-providers.xml
│   │   └── archive/              # Flow archives
│   ├── <CLUSTER_NAME>.nifi-2/
│   └── <CLUSTER_NAME>.nifi-3/
└── certs/
    ├── ca/                         # LOCAL COPY (deleted with workspace)
    │   ├── ca-key.pem
    │   ├── ca-cert.pem
    │   ├── truststore.jks
    │   └── truststore.p12
    ├── <CLUSTER_NAME>.nifi-1/
    │   ├── server-key.pem
    │   ├── server-cert.pem
    │   ├── cert-chain.pem
    │   ├── keystore.p12
    │   ├── keystore.jks
    │   ├── truststore.p12
    │   └── truststore.jks
    ├── <CLUSTER_NAME>.nifi-2/
    ├── <CLUSTER_NAME>.nifi-3/
    ├── <CLUSTER_NAME>.zookeeper-1/
    ├── <CLUSTER_NAME>.zookeeper-2/
    └── <CLUSTER_NAME>.zookeeper-3/
```

**Data Loss Warning:**
- **Irreversible:** All data in volumes/ is permanently deleted
- **FlowFiles:** Any in-flight data is lost
- **Provenance:** Historical event data is lost
- **State:** Component state is lost
- **Configuration:** Custom configs are lost
- **Logs:** Troubleshooting information is lost

#### Step 4: Verify Shared CA Preservation

```bash
# Check that shared CA still exists
if [ -d "certs/ca" ] && [ -f "certs/ca/ca-cert.pem" ]; then
    ✓ Shared CA preserved
fi
```

**Critical Difference:**
- `clusters/<CLUSTER_NAME>/certs/ca/` - **DELETED** (local copy)
- `certs/ca/` - **PRESERVED** (shared across all clusters)

**Why Preserve Shared CA?**
1. Other clusters depend on it for SSL/TLS trust
2. New clusters can reuse it for consistent PKI
3. Regenerating CA would break existing clusters
4. Certificate renewal requires original CA

## Resources Affected

### Deleted Resources

| Resource Type | Location | Size Impact | Recovery |
|--------------|----------|-------------|----------|
| Docker Containers | Docker daemon | Minimal | Restart with `docker compose up` if compose file exists |
| Docker Networks | Docker daemon | None | Auto-created on cluster restart |
| Docker Volumes | Docker daemon | Large (depends on data flow) | Cannot recover, data lost |
| Compose File | Project root | ~5-10 KB | Regenerate with `create-cluster.sh` |
| Node Configurations | clusters/\<CLUSTER_NAME\>/conf/ | ~100 KB per node | Regenerate with `create-cluster.sh` |
| Node Certificates | clusters/\<CLUSTER_NAME\>/certs/ | ~50 KB per node | Regenerate with `create-cluster.sh` |
| Runtime Data | clusters/\<CLUSTER_NAME\>/volumes/ | **Variable (GB to TB)** | **PERMANENT DATA LOSS** |

### Preserved Resources

| Resource Type | Location | Reason |
|--------------|----------|--------|
| Shared CA | certs/ca/ | Used by all clusters for SSL/TLS trust |
| Other Clusters | clusters/\<OTHER_NAME\>/ | Deletion is cluster-specific |
| Docker Images | Docker daemon | Shared across all clusters |
| Host Network | System | Cluster networks are isolated |

## Usage Examples

### Example 1: Delete with Confirmation (Safe)

```bash
./delete-cluster.sh cluster01
```

**Output:**
```
╔════════════════════════════════════════════════════════════════╗
║  NiFi Cluster Deletion - cluster01                            ║
╚════════════════════════════════════════════════════════════════╝

Checking cluster resources...

  ℹ Cluster workspace found: clusters/cluster01 (2.3G)
  ℹ Docker Compose file found: docker-compose-cluster01.yml
  ℹ Docker containers found: 6

Containers:
    cluster01.nifi-1
    cluster01.nifi-2
    cluster01.nifi-3
    cluster01.zookeeper-1
    cluster01.zookeeper-2
    cluster01.zookeeper-3

╔════════════════════════════════════════════════════════════════╗
║  Deletion Plan                                                ║
╚════════════════════════════════════════════════════════════════╝

The following will be DELETED:

  ✗ Docker containers (stopped and removed):
      cluster01.nifi-1
      cluster01.nifi-2
      cluster01.nifi-3
      cluster01.zookeeper-1
      cluster01.zookeeper-2
      cluster01.zookeeper-3

  ✗ Docker Compose file:
      docker-compose-cluster01.yml

  ✗ Cluster workspace (certificates, configs, volumes):
      clusters/cluster01/ (2.3G)
      - certs/ (node certificates)
      - conf/ (node configurations)
      - volumes/ (runtime data)

The following will be PRESERVED:

  ✓ Shared Certificate Authority:
      certs/ca/ (used by all clusters)

═══════════════════════════════════════════════════
WARNING: This action cannot be undone!
═══════════════════════════════════════════════════

Are you sure you want to delete cluster 'cluster01'? (yes/no): yes

╔════════════════════════════════════════════════════════════════╗
║  Deleting Cluster: cluster01                                  ║
╚════════════════════════════════════════════════════════════════╝

[1/4] Stopping Docker containers

  ✓ Docker containers and networks removed

[2/4] Deleting Docker Compose file

  ✓ Deleted: docker-compose-cluster01.yml

[3/4] Deleting cluster workspace

  ✓ Deleted: clusters/cluster01/
  ℹ Removed certificates, configurations, and volumes

[4/4] Verifying shared CA preservation

  ✓ Shared CA preserved: certs/ca/
  ℹ CA can be used for future clusters

╔════════════════════════════════════════════════════════════════╗
║  Deletion Complete                                            ║
╚════════════════════════════════════════════════════════════════╝

✓ Cluster 'cluster01' has been deleted

Summary:
  - Docker containers: Stopped and removed
  - Docker networks: Removed
  - Compose file: Deleted
  - Cluster workspace: Deleted
  - Shared CA: Preserved

Remaining clusters:
  - cluster02
```

### Example 2: Force Delete (No Confirmation)

```bash
./delete-cluster.sh cluster02 --force
```

**Behavior:**
- Skips confirmation prompt
- Immediately deletes all resources
- Useful for automation/scripts
- **USE WITH CAUTION**

### Example 3: Delete Non-Existent Cluster

```bash
./delete-cluster.sh cluster99
```

**Output:**
```
Checking cluster resources...

  ⚠ Warning: Cluster 'cluster99' does not exist or has already been deleted
```

**Result:**
- Script exits gracefully
- No errors
- Exit code: 0

### Example 4: Invalid Cluster Name

```bash
./delete-cluster.sh cluster1    # Missing leading zero
./delete-cluster.sh myapp      # Wrong format
```

**Output:**
```
  ✗ Error: Invalid cluster name format
  ℹ Cluster name must follow pattern: clusterXX (e.g., cluster01, cluster02)
```

**Result:**
- Script exits with error
- Exit code: 1

## Error Handling & Edge Cases

### Case 1: Compose File Missing, Containers Exist

```bash
# docker-compose-cluster01.yml deleted manually
# But containers are still running
```

**Handling:**
- Script detects containers via `docker ps -a`
- Falls back to manual container removal: `docker rm -f <container>`
- Continues with workspace deletion

### Case 2: Permission Denied on Workspace Deletion

```bash
# Current user doesn't have write access to volumes/
```

**Handling:**
- Script uses `sudo rm -rf` for workspace deletion
- Ensures deletion regardless of ownership
- May prompt for sudo password

**Requirement:**
- User must have sudo privileges
- If sudo unavailable, manual cleanup required

### Case 3: Network Already Removed

```bash
# Docker network was removed manually
```

**Handling:**
- Script checks for network existence
- Silently skips if not found
- Continues with next step

### Case 4: Container Removal Fails

```bash
# Container is locked or corrupted
```

**Handling:**
- Prints warning for each failed container
- Continues attempting to remove other containers
- Does not halt script execution

### Case 5: Shared CA Accidentally Deleted

```bash
# Someone deleted certs/ca/ manually
```

**Handling:**
- Step 4 verification detects missing CA
- Prints warning message
- Informs user it will be recreated by `create-cluster.sh`
- **Does not fail** - CA regeneration is automatic

## Recovery Options

### Full Recovery (If Caught Immediately)

If deletion was just executed and you need to recover:

1. **Restore from backup** (if available):
   ```bash
   # Restore cluster workspace from backup
   sudo cp -r /backup/clusters/cluster01 clusters/
   
   # Restore compose file
   cp /backup/docker-compose-cluster01.yml .
   ```

2. **Restart cluster:**
   ```bash
   docker compose -f docker-compose-cluster01.yml up -d
   ```

### Partial Recovery (Recreate Empty Cluster)

If data is lost but you need the same cluster configuration:

1. **Recreate cluster structure:**
   ```bash
   # Use same CLUSTER_NUM to get same ports
   ./create-cluster.sh cluster01 1 3
   ```

2. **Start cluster:**
   ```bash
   docker compose -f docker-compose-cluster01.yml up -d
   ```

**Result:**
- Same ports and configuration
- Empty data repositories
- No flows, state, or provenance
- Clean slate

### No Recovery (Data Lost)

- **FlowFile content:** Cannot recover
- **Provenance history:** Cannot recover
- **Component state:** Cannot recover
- **Logs:** Cannot recover
- **Flows:** Can recover if version controlled in NiFi Registry or Git

## Safety Features

### 1. Shared CA Preservation

**Critical Safety Mechanism:**
```bash
# Script NEVER touches:
certs/ca/ca-key.pem      # Root CA private key
certs/ca/ca-cert.pem     # Root CA certificate
certs/ca/truststore.*    # Shared truststores
```

**Why This Matters:**
- All clusters trust the same CA
- Deleting CA breaks SSL/TLS for all clusters
- Regenerating CA requires re-issuing all node certificates
- Cross-cluster Site-to-Site requires consistent CA

### 2. Interactive Confirmation

**User Must:**
1. Review deletion plan
2. See exact resources being deleted
3. Type `yes` to confirm (case-sensitive)

**Prevents:**
- Accidental deletions from typos
- Script automation errors
- Copy-paste mistakes

### 3. Cluster Name Validation

**Strict Format Enforcement:**
- Pattern: `clusterXX` (exactly 2 digits)
- Prevents deletion of non-cluster directories
- Protects against wildcard expansion

### 4. Graceful Container Shutdown

**Preferred Method:**
```bash
docker compose down --volumes
```

**Benefits:**
- Allows containers to shut down gracefully
- NiFi can flush pending FlowFiles
- Prevents data corruption
- Cleaner than force kill

### 5. Step-by-Step Progress Reporting

**Visibility:**
- Shows exactly what is being deleted at each step
- Reports success/failure for each operation
- Final summary confirms deletion

## Integration with Other Scripts

### Used In Conjunction With

| Script | Relationship | Purpose |
|--------|-------------|---------|
| `create-cluster.sh` | Inverse operation | Create cluster → Delete cluster lifecycle |
| `check-cluster.sh` | Pre-deletion verification | Verify cluster status before deletion |
| `lib/cluster-utils.sh` | Not used | delete-cluster.sh is standalone |

### Workflow Example

```bash
# 1. Create cluster
./create-cluster.sh cluster01 1 3

# 2. Use cluster (flows, data processing, etc.)
docker compose -f docker-compose-cluster01.yml up -d

# 3. Check cluster status
./check-cluster.sh cluster01

# 4. Stop cluster temporarily
docker compose -f docker-compose-cluster01.yml down

# 5. Decide to permanently remove
./delete-cluster.sh cluster01

# 6. Create new cluster with same ports
./create-cluster.sh cluster01 1 3
```

## Command-Line Interface

### Help Output

```bash
./delete-cluster.sh --help
```

```
NiFi Cluster Deletion Script

Safely removes a cluster including:
  - Docker containers and networks
  - Cluster workspace (certs, config, volumes)
  - Docker Compose file

IMPORTANT: The shared CA (certs/ca/) is NEVER deleted.

Usage:
  ./delete-cluster.sh <CLUSTER_NAME> [--force]

Arguments:
  CLUSTER_NAME    Name of the cluster to delete (e.g., cluster01)

Options:
  --force, -f     Skip confirmation prompt
  --help, -h      Show this help message

Examples:
  ./delete-cluster.sh cluster01                 # Delete cluster01 (with confirmation)
  ./delete-cluster.sh cluster02 --force         # Delete cluster02 (no confirmation)
```

### Exit Codes

| Code | Meaning | When |
|------|---------|------|
| 0 | Success | Cluster deleted successfully, or nothing to delete |
| 1 | Error | Invalid arguments, invalid cluster name format |

## Best Practices

### Before Deletion

1. **Backup critical data:**
   ```bash
   # Backup entire cluster workspace
   sudo tar -czf cluster01-backup-$(date +%Y%m%d).tar.gz clusters/cluster01/
   
   # Backup specific volumes
   sudo tar -czf cluster01-volumes-$(date +%Y%m%d).tar.gz clusters/cluster01/volumes/
   ```

2. **Export flows (if not using NiFi Registry):**
   - Download flow definition from NiFi UI
   - Save templates
   - Document processor configurations

3. **Export provenance (if needed for audit):**
   - Use NiFi UI to export provenance queries
   - Save to external storage

4. **Document cluster configuration:**
   - Note CLUSTER_NUM for port assignments
   - Record NODE_COUNT
   - Save any custom nifi.properties changes

5. **Verify cluster is stopped:**
   ```bash
   docker compose -f docker-compose-cluster01.yml down
   ```

### During Deletion

1. **Use confirmation mode (default):**
   ```bash
   ./delete-cluster.sh cluster01  # No --force
   ```

2. **Review deletion plan carefully:**
   - Check workspace size (is it expected?)
   - Verify container count matches cluster
   - Ensure correct cluster name

3. **Don't interrupt the script:**
   - Let all 4 steps complete
   - Don't Ctrl+C during deletion
   - Wait for summary

### After Deletion

1. **Verify deletion:**
   ```bash
   # Check no containers remain
   docker ps -a | grep cluster01
   
   # Check workspace removed
   ls -la clusters/ | grep cluster01
   
   # Check compose file removed
   ls docker-compose-cluster01.yml
   ```

2. **Check remaining clusters:**
   ```bash
   ls -1d clusters/cluster*/ 2>/dev/null | xargs -n1 basename
   ```

3. **Verify shared CA preserved:**
   ```bash
   ls -la certs/ca/
   ```

4. **Clean up Docker resources (optional):**
   ```bash
   # Remove unused images
   docker image prune -a
   
   # Remove unused volumes
   docker volume prune
   
   # Remove unused networks
   docker network prune
   ```

## Security Considerations

### Sensitive Data Deletion

**What Gets Deleted:**
- SSL/TLS private keys (node-specific)
- NiFi flow configurations (may contain credentials)
- Provenance data (may contain sensitive information)
- FlowFile content (actual data being processed)
- Component state (may contain API keys, tokens)

**Deletion Method:**
- `rm -rf` does NOT securely wipe data
- File contents may be recoverable with forensic tools
- For truly sensitive data, consider:
  - Encrypted filesystems
  - Secure deletion tools (`shred`, `wipe`)
  - Full disk encryption

### Permission Requirements

**Operations Requiring Elevated Privileges:**
1. Workspace deletion (UID:GID 1000:1000 ownership)
   - Uses: `sudo rm -rf`
   - Reason: Container volumes owned by container user

**Operations NOT Requiring Sudo:**
1. Docker container removal
2. Compose file deletion (if user owns it)
3. Network removal

### Audit Trail

**Script Provides:**
- Pre-deletion summary (what will be deleted)
- Step-by-step confirmation (what is being deleted)
- Post-deletion summary (what was deleted)

**For Audit Compliance:**
```bash
# Log deletion to syslog or audit file
./delete-cluster.sh cluster01 2>&1 | tee -a /var/log/nifi-cluster-deletions.log
```

## Troubleshooting

### Problem: "Permission denied" during workspace deletion

**Cause:**
- User doesn't have sudo privileges
- User not in docker group

**Solution:**
```bash
# Add user to docker group (requires logout/login)
sudo usermod -aG docker $USER

# Or manually delete with sudo
sudo rm -rf clusters/cluster01/
```

### Problem: Containers won't stop

**Cause:**
- Containers are unresponsive
- Docker daemon issues

**Solution:**
```bash
# Force kill containers
docker kill $(docker ps -a --filter "name=cluster01." --format "{{.ID}}")

# Remove containers
docker rm -f $(docker ps -a --filter "name=cluster01." --format "{{.ID}}")

# Re-run delete script
./delete-cluster.sh cluster01 --force
```

### Problem: Network removal fails

**Cause:**
- Network still has connected endpoints
- Other containers using network

**Solution:**
```bash
# Inspect network
docker network inspect cluster01-nifi-cluster_cluster01-network

# Disconnect any remaining endpoints
docker network disconnect -f cluster01-nifi-cluster_cluster01-network <container_id>

# Remove network manually
docker network rm cluster01-nifi-cluster_cluster01-network
```

### Problem: Shared CA accidentally deleted

**Cause:**
- Manual deletion of certs/ca/
- Script bug (shouldn't happen)

**Solution:**
```bash
# CA will be regenerated on next cluster creation
./create-cluster.sh cluster01 1 3

# Or restore from backup
tar -xzf backup.tar.gz certs/ca/
```

**Impact:**
- Existing clusters will have SSL/TLS trust issues
- Need to regenerate all node certificates
- Cross-cluster S2S will break

### Problem: Disk space not freed after deletion

**Cause:**
- Docker volumes not removed
- Anonymous volumes persist

**Solution:**
```bash
# Remove all unused volumes
docker volume prune

# Force remove specific volumes
docker volume rm $(docker volume ls -q --filter "label=com.docker.compose.project=cluster01-nifi-cluster")

# Check disk usage
du -sh clusters/ certs/ volumes/
```

## Related Documentation

- `create-cluster.sh` - Inverse operation (create clusters)
- `check-cluster.sh` - Verify cluster status before deletion
- `Docker Compose Reference` - Understanding container lifecycle
- `NiFi Backup & Recovery Guide` - Data backup strategies

## Summary

`delete-cluster.sh` provides:
- **Safe deletion** with interactive confirmation
- **Complete cleanup** of all cluster resources
- **CA preservation** for other clusters
- **Clear reporting** of what is being deleted
- **Error handling** for edge cases
- **Recovery guidance** for accidental deletions

**Key Principle:** Cluster-specific resources are deleted, shared infrastructure (CA) is preserved.
