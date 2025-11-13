---
id: doc-008
title: validate - Cluster Configuration Validation Tool
type: other
created_date: '2025-11-13 14:25'
---
# validate - Cluster Configuration Validation Tool

## Overview

The `validate` script is an intelligent pre-deployment validation tool that automatically detects cluster parameters and performs comprehensive checks on cluster configuration, certificates, volumes, and Docker Compose files before deployment. It ensures that clusters are correctly configured and ready to start without errors.

## Purpose

- **Pre-deployment verification:** Catch configuration errors before starting containers
- **Auto-detection:** Automatically discovers cluster parameters from existing configuration
- **Comprehensive checks:** Validates 7 critical areas of cluster setup
- **Clear reporting:** Color-coded pass/fail/warning system with detailed error messages
- **Exit codes:** Returns 0 for success, 1 for failure (CI/CD friendly)

## Script Architecture

```
validate (Cluster Validation Tool)
├── Dependencies
│   └── lib/cluster-utils.sh (for auto-detection functions)
│
├── Auto-Detection Phase
│   ├── get_cluster_num() - Extract cluster number from name
│   ├── get_node_count() - Count nodes from docker-compose
│   ├── get_base_port() - Calculate base port from cluster number
│   ├── validate_cluster_name() - Validate naming format
│   └── cluster_exists() - Verify cluster configuration exists
│
└── Validation Phase (7 Sections)
    ├── 1. Directory Structure Validation
    │   ├── Cluster workspace directory
    │   ├── certs/, conf/, volumes/ directories
    │   ├── ZooKeeper volume directories (data, datalog, logs)
    │   └── NiFi volume directories (6 repositories per node)
    │
    ├── 2. Certificate Validation
    │   ├── CA certificate validity
    │   ├── Node keystores (PKCS12 format)
    │   ├── Node truststores
    │   └── Certificate chain validation
    │
    ├── 3. Configuration Files Validation
    │   ├── nifi.properties (per node)
    │   ├── state-management.xml (per node)
    │   ├── authorizers.xml (per node)
    │   └── bootstrap.conf (per node)
    │
    ├── 4. Node Address Validation
    │   ├── nifi.cluster.node.address correctness
    │   └── nifi.remote.input.host correctness
    │
    ├── 5. ZooKeeper Configuration Validation
    │   └── nifi.zookeeper.connect.string correctness
    │
    ├── 6. Docker Compose Validation
    │   ├── Compose file existence
    │   ├── YAML syntax validation
    │   └── Service count verification
    │
    └── 7. Port Conflict Check
        ├── Duplicate port detection
        └── Port availability check (uses lsof/ss/netstat)
```

## Parameters

### Required Parameter

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `CLUSTER_NAME` | String | Name of cluster to validate (format: clusterXX) | `cluster01`, `cluster02` |

### Optional Flags

| Flag | Description |
|------|-------------|
| `--help`, `-h` | Show help message and exit |

### Auto-Detected Parameters

The script automatically detects these from existing configuration:

| Parameter | Source | Example |
|-----------|--------|---------|
| `CLUSTER_NUM` | Extracted from CLUSTER_NAME | `1` from `cluster01` |
| `NODE_COUNT` | Counted from docker-compose file | `3` |
| `BASE_PORT` | Calculated from CLUSTER_NUM | `30000` = 29000 + (1 × 1000) |

## Validation Checks

### Section 1: Directory Structure Validation

**Checks Performed:**
1. Cluster workspace directory exists: `clusters/<CLUSTER_NAME>/`
2. Main subdirectories exist:
   - `clusters/<CLUSTER_NAME>/certs/`
   - `clusters/<CLUSTER_NAME>/conf/`
   - `clusters/<CLUSTER_NAME>/volumes/`

3. **ZooKeeper volume directories** (per node):
   ```
   volumes/<CLUSTER_NAME>.zookeeper-<N>/
   ├── data/           ✓ Must exist
   ├── datalog/        ✓ Must exist
   └── logs/           ✓ Must exist
   ```

4. **NiFi volume directories** (per node):
   ```
   volumes/<CLUSTER_NAME>.nifi-<N>/
   ├── content_repository/      ✓ Must exist
   ├── database_repository/     ✓ Must exist
   ├── flowfile_repository/     ✓ Must exist
   ├── provenance_repository/   ✓ Must exist
   ├── state/                   ✓ Must exist
   └── logs/                    ✓ Must exist
   ```

**Check Labels:**
- `[DIR]` - General directory checks
- `[ZK1]`, `[ZK2]`, `[ZK3]` - ZooKeeper node volumes
- `[NFI1]`, `[NFI2]`, `[NFI3]` - NiFi node volumes

**Failure Conditions:**
- Directory missing
- Incorrect permissions preventing access

### Section 2: Certificate Validation

**Checks Performed:**

1. **CA Certificate Validation:**
   ```bash
   # Location: clusters/<CLUSTER_NAME>/certs/ca/ca-cert.pem
   # Validation: openssl x509 -in ca-cert.pem -noout -text
   ```

2. **Node Certificate Validation** (per node):
   ```bash
   # Keystore: clusters/<CLUSTER_NAME>/conf/<CLUSTER_NAME>.nifi-<N>/keystore.p12
   # Truststore: clusters/<CLUSTER_NAME>/conf/<CLUSTER_NAME>.nifi-<N>/truststore.p12
   # Validation: openssl pkcs12 -in keystore.p12 -nokeys -passin pass:changeme123456
   ```

**Check Labels:**
- `[CA]` - CA certificate
- `[CRT1]`, `[CRT2]`, `[CRT3]` - Node certificates

**Dependencies:**
- Requires `openssl` command
- If openssl unavailable, skips with warning

**Failure Conditions:**
- Certificate file missing
- Certificate corrupted or invalid
- Incorrect keystore password (expects: `changeme123456`)

### Section 3: Configuration Files Validation

**Checks Performed** (per node):

Required files in `clusters/<CLUSTER_NAME>/conf/<CLUSTER_NAME>.nifi-<N>/`:
1. `nifi.properties` - Main NiFi configuration
2. `state-management.xml` - State management with ZooKeeper
3. `authorizers.xml` - Authorization policies
4. `bootstrap.conf` - JVM bootstrap configuration

**Check Labels:**
- `[CFG1]`, `[CFG2]`, `[CFG3]` - Node configuration files

**Failure Conditions:**
- Any required file missing
- Files not readable

**Note:** Does not validate file *contents*, only existence.

### Section 4: Node Address Validation

**Checks Performed:**

1. **Cluster Node Address Validation** (per node):
   ```properties
   # Property: nifi.cluster.node.address
   # Expected: <CLUSTER_NAME>.nifi-<N>
   # Example: cluster01.nifi-1
   ```

2. **Remote Input Host Validation** (per node):
   ```properties
   # Property: nifi.remote.input.host
   # Expected: <CLUSTER_NAME>.nifi-<N> (or FQDN if DOMAIN set)
   # Example: cluster01.nifi-1 or cluster01.nifi-1.ymbihq.local
   ```

**Check Labels:**
- `[ADR1]`, `[ADR2]`, `[ADR3]` - Node addresses
- `[RMT1]`, `[RMT2]`, `[RMT3]` - Remote input hosts

**Failure Conditions:**
- Node address doesn't match expected format
- Remote input host doesn't match expected format
- Property missing from nifi.properties

**Critical for:**
- Cluster node discovery
- Site-to-Site communication (especially cross-cluster)

### Section 5: ZooKeeper Configuration Validation

**Checks Performed:**

Build expected ZooKeeper connect string:
```
<CLUSTER_NAME>.zookeeper-1:2181,<CLUSTER_NAME>.zookeeper-2:2181,...
```

Validate in each node's `nifi.properties`:
```properties
# Property: nifi.zookeeper.connect.string
# Expected: cluster01.zookeeper-1:2181,cluster01.zookeeper-2:2181,cluster01.zookeeper-3:2181
```

**Check Labels:**
- `[ZKC1]`, `[ZKC2]`, `[ZKC3]` - ZooKeeper connect strings

**Failure Conditions:**
- Connect string doesn't match expected format
- Missing ZooKeeper nodes in string
- Incorrect hostname format
- Property missing from nifi.properties

**Critical for:**
- Cluster coordination
- Leader election
- Shared state management

### Section 6: Docker Compose Validation

**Checks Performed:**

1. **Compose File Existence:**
   ```bash
   # File: docker-compose-<CLUSTER_NAME>.yml
   # Example: docker-compose-cluster01.yml
   ```

2. **YAML Syntax Validation:**
   ```bash
   docker compose -f docker-compose-<CLUSTER_NAME>.yml config --quiet
   ```

3. **Service Count Verification:**
   ```bash
   # Count container_name entries matching pattern: *nifi-*
   # Expected: NODE_COUNT (e.g., 3)
   # Also checks ZooKeeper services
   ```

**Check Labels:**
- `[YML]` - Compose file existence
- `[SYN]` - YAML syntax validation
- `[SVC]` - Service count verification

**Failure Conditions:**
- Compose file missing
- Invalid YAML syntax
- Service count mismatch (expected vs. actual)

### Section 7: Port Conflict Check

**Checks Performed:**

1. **Duplicate Port Detection:**
   ```bash
   # Extract all port mappings from compose file
   # Check for duplicates using uniq -d
   # Example: If two services use 30443, it's a duplicate
   ```

2. **Port Availability Check:**
   ```bash
   # For each port, check if already in use
   # Uses (in order of preference):
   #   - lsof -Pi :$PORT -sTCP:LISTEN -t
   #   - ss -tlnH | grep ":$PORT "
   #   - netstat -tln | grep ":$PORT "
   ```

**Check Labels:**
- `[DUP]` - Duplicate port detection
- `[USE]` - Port availability check

**Failure Conditions:**
- **Fail:** Duplicate ports found in compose file
- **Warning:** Ports already in use on host (may be from this cluster if running)

**Special Cases:**
- Skips port availability check if running inside Docker container (`/.dockerenv` exists)
- Skips if no port checking tools available (lsof, ss, netstat)

## Output Format

### Color Coding

```
✓ PASS    - Green  - Check passed
✗ FAIL    - Red    - Check failed (blocks deployment)
⚠ WARNING - Yellow - Non-critical issue (doesn't block deployment)
```

### Check Format

```
[LABEL] Description... ✓ PASS
[LABEL] Description... ✗ FAIL
          └─ Error details

[LABEL] Description... ⚠ WARNING
          └─ Warning details
```

### Section Headers

```
════════════════════════════════════════════════════════════════
 1. Directory Structure Validation
════════════════════════════════════════════════════════════════
```

### Summary Format

```
════════════════════════════════════════════════════════════════
 Validation Summary
════════════════════════════════════════════════════════════════

Results:
  Passed:   42 / 50
  Failed:   0 / 50
  Warnings: 8 / 50

╔════════════════════════════════════════════════════════════════╗
║  ✓ All validations passed!                                    ║
╚════════════════════════════════════════════════════════════════╝

Note: There are 8 warning(s) - review them above

Your cluster is ready to deploy!

Next steps:
  Start:    ./cluster start cluster01
  Wait:     ./cluster wait cluster01
  Test:     ./test cluster01
```

## Exit Codes

| Code | Condition | Meaning |
|------|-----------|---------|
| 0 | FAILED == 0 | All validations passed (warnings OK) |
| 1 | FAILED > 0 | One or more validations failed |
| 1 | Invalid arguments | Cluster name missing or invalid |
| 1 | Cluster not found | No configuration exists for specified cluster |

## Usage Examples

### Example 1: Validate Newly Created Cluster

```bash
./validate cluster01
```

**Typical Output (Success):**
```
╔════════════════════════════════════════════════════════════════╗
║  NiFi Cluster Configuration Validator                         ║
╚════════════════════════════════════════════════════════════════╝

Configuration (auto-detected):
  Cluster Name:   cluster01
  Cluster Number: 1
  Node Count:     3
  Base Port:      30000
  Cluster Dir:    clusters/cluster01

════════════════════════════════════════════════════════════════
 1. Directory Structure Validation
════════════════════════════════════════════════════════════════

  [DIR] Checking clusters/cluster01/ workspace... ✓ PASS
  [DIR] Checking clusters/cluster01/certs/ directory... ✓ PASS
  [DIR] Checking clusters/cluster01/conf/ directory... ✓ PASS
  [DIR] Checking clusters/cluster01/volumes/ directory... ✓ PASS
  [ZK1] Checking cluster01.zookeeper-1 volumes... ✓ PASS
  [ZK2] Checking cluster01.zookeeper-2 volumes... ✓ PASS
  [ZK3] Checking cluster01.zookeeper-3 volumes... ✓ PASS
  [NFI1] Checking cluster01.nifi-1 volumes... ✓ PASS
  [NFI2] Checking cluster01.nifi-2 volumes... ✓ PASS
  [NFI3] Checking cluster01.nifi-3 volumes... ✓ PASS

════════════════════════════════════════════════════════════════
 2. Certificate Validation
════════════════════════════════════════════════════════════════

  [CA] Checking CA certificate... ✓ PASS
  [CRT1] Checking cluster01.nifi-1 certificates... ✓ PASS
  [CRT2] Checking cluster01.nifi-2 certificates... ✓ PASS
  [CRT3] Checking cluster01.nifi-3 certificates... ✓ PASS

════════════════════════════════════════════════════════════════
 3. Configuration Files Validation
════════════════════════════════════════════════════════════════

  [CFG1] Checking cluster01.nifi-1 config files... ✓ PASS
  [CFG2] Checking cluster01.nifi-2 config files... ✓ PASS
  [CFG3] Checking cluster01.nifi-3 config files... ✓ PASS

════════════════════════════════════════════════════════════════
 4. Node Address Validation
════════════════════════════════════════════════════════════════

  [ADR1] Checking cluster01.nifi-1 node address... ✓ PASS
  [ADR2] Checking cluster01.nifi-2 node address... ✓ PASS
  [ADR3] Checking cluster01.nifi-3 node address... ✓ PASS
  [RMT1] Checking cluster01.nifi-1 remote input host... ✓ PASS
  [RMT2] Checking cluster01.nifi-2 remote input host... ✓ PASS
  [RMT3] Checking cluster01.nifi-3 remote input host... ✓ PASS

════════════════════════════════════════════════════════════════
 5. ZooKeeper Configuration Validation
════════════════════════════════════════════════════════════════

  [ZKC1] Checking cluster01.nifi-1 ZooKeeper connect string... ✓ PASS
  [ZKC2] Checking cluster01.nifi-2 ZooKeeper connect string... ✓ PASS
  [ZKC3] Checking cluster01.nifi-3 ZooKeeper connect string... ✓ PASS

════════════════════════════════════════════════════════════════
 6. Docker Compose Validation
════════════════════════════════════════════════════════════════

  [YML] Checking docker-compose-cluster01.yml... ✓ PASS
  [SYN] Validating docker-compose syntax... ✓ PASS
  [SVC] Checking service count in compose file... ✓ PASS

════════════════════════════════════════════════════════════════
 7. Port Conflict Check
════════════════════════════════════════════════════════════════

  [DUP] Checking for duplicate port mappings... ✓ PASS
  [USE] Checking if ports are available... ✓ PASS

════════════════════════════════════════════════════════════════
 Validation Summary
════════════════════════════════════════════════════════════════

Results:
  Passed:   31 / 31
  Failed:   0 / 31
  Warnings: 0 / 31

╔════════════════════════════════════════════════════════════════╗
║  ✓ All validations passed!                                    ║
╚════════════════════════════════════════════════════════════════╝

Your cluster is ready to deploy!

Next steps:
  Start:    ./cluster start cluster01
  Wait:     ./cluster wait cluster01
  Test:     ./test cluster01
```

### Example 2: Validation with Errors

```bash
./validate cluster02
```

**Output (with errors):**
```
Configuration (auto-detected):
  Cluster Name:   cluster02
  Cluster Number: 2
  Node Count:     3
  Base Port:      31000
  Cluster Dir:    clusters/cluster02

════════════════════════════════════════════════════════════════
 1. Directory Structure Validation
════════════════════════════════════════════════════════════════

  [DIR] Checking clusters/cluster02/ workspace... ✓ PASS
  [DIR] Checking clusters/cluster02/certs/ directory... ✗ FAIL
          └─ Directory certs/ not found
  [DIR] Checking clusters/cluster02/conf/ directory... ✓ PASS
  [DIR] Checking clusters/cluster02/volumes/ directory... ✓ PASS

[... more checks ...]

════════════════════════════════════════════════════════════════
 4. Node Address Validation
════════════════════════════════════════════════════════════════

  [ADR1] Checking cluster02.nifi-1 node address... ✗ FAIL
          └─ Expected 'cluster02.nifi-1' but found 'cluster01.nifi-1'

[... more checks ...]

════════════════════════════════════════════════════════════════
 Validation Summary
════════════════════════════════════════════════════════════════

Results:
  Passed:   25 / 31
  Failed:   6 / 31
  Warnings: 0 / 31

╔════════════════════════════════════════════════════════════════╗
║  ✗ Validation failed - fix errors above                       ║
╚════════════════════════════════════════════════════════════════╝
```

### Example 3: Validation with Warnings

```bash
./validate cluster01
```

**Output (with warnings):**
```
[... earlier checks pass ...]

════════════════════════════════════════════════════════════════
 7. Port Conflict Check
════════════════════════════════════════════════════════════════

  [DUP] Checking for duplicate port mappings... ✓ PASS
  [USE] Checking if ports are available... ⚠ WARNING
          └─ Ports already in use: 30443 30444 30445 (may conflict if not from this cluster)

════════════════════════════════════════════════════════════════
 Validation Summary
════════════════════════════════════════════════════════════════

Results:
  Passed:   30 / 31
  Failed:   0 / 31
  Warnings: 1 / 31

╔════════════════════════════════════════════════════════════════╗
║  ✓ All validations passed!                                    ║
╚════════════════════════════════════════════════════════════════╝

Note: There are 1 warning(s) - review them above

Your cluster is ready to deploy!
```

### Example 4: Invalid Cluster Name

```bash
./validate cluster1    # Missing leading zero
```

**Output:**
```
Error: Invalid cluster name format
  Cluster name must follow pattern: clusterXX (e.g., cluster01, cluster02)
```

### Example 5: Non-Existent Cluster

```bash
./validate cluster99
```

**Output:**
```
Error: Cluster cluster99 not found

Available clusters:
  cluster01
  cluster02
```

## Common Failure Scenarios

### Scenario 1: Missing Certificates

**Cause:**
- Certificate generation was skipped or failed
- Certificates were deleted manually

**Error:**
```
[CRT1] Checking cluster01.nifi-1 certificates... ✗ FAIL
         └─ Certificates missing
```

**Fix:**
```bash
# Regenerate certificates
cd certs
./generate-certs.sh 3 ../clusters/cluster01/certs cluster01
cd ..
```

### Scenario 2: Incorrect Node Addresses

**Cause:**
- Configuration generated for wrong cluster name
- Manual configuration edits introduced errors

**Error:**
```
[ADR1] Checking cluster01.nifi-1 node address... ✗ FAIL
         └─ Expected 'cluster01.nifi-1' but found 'cluster02.nifi-1'
```

**Fix:**
```bash
# Regenerate configurations
cd conf
./generate-cluster-configs.sh cluster01 1 3 ../clusters/cluster01/conf ../clusters/cluster01/certs
cd ..
```

### Scenario 3: Port Conflicts

**Cause:**
- Another cluster using same ports
- Other services on host using ports

**Error:**
```
[DUP] Checking for duplicate port mappings... ✗ FAIL
        └─ Duplicate ports found: 30443 30444
```

**Fix:**
```bash
# Regenerate compose with different CLUSTER_NUM
./lib/generate-docker-compose.sh cluster01 2 3  # Use cluster num 2 instead of 1
```

### Scenario 4: Docker Compose Syntax Errors

**Cause:**
- Manual edits introduced YAML syntax errors
- Corrupted compose file

**Error:**
```
[SYN] Validating docker-compose syntax... ✗ FAIL
        └─ docker-compose-cluster01.yml has syntax errors
```

**Fix:**
```bash
# Regenerate compose file
./lib/generate-docker-compose.sh cluster01 1 3
```

### Scenario 5: Missing Volume Directories

**Cause:**
- Volume initialization was skipped
- Directories were deleted manually

**Error:**
```
[NFI1] Checking cluster01.nifi-1 volumes... ✗ FAIL
         └─ cluster01.nifi-1 volume directories incomplete
```

**Fix:**
```bash
# Recreate volume directories
mkdir -p clusters/cluster01/volumes/cluster01.nifi-1/{content_repository,database_repository,flowfile_repository,provenance_repository,state,logs}

# Set ownership
sudo chown -R 1000:1000 clusters/cluster01/volumes/
```

## Integration with Cluster Workflow

### Recommended Workflow

```bash
# 1. Create cluster
./create-cluster.sh cluster01 1 3

# 2. Validate before starting (THIS SCRIPT)
./validate cluster01

# 3. If validation passes, start cluster
if [ $? -eq 0 ]; then
    docker compose -f docker-compose-cluster01.yml up -d
fi

# 4. Wait for cluster to be ready
./cluster wait cluster01

# 5. Test cluster connectivity
./test cluster01
```

### CI/CD Integration

```yaml
# Example GitLab CI
validate-cluster:
  stage: validate
  script:
    - ./create-cluster.sh cluster01 1 3
    - ./validate cluster01
  only:
    - main
```

```yaml
# Example GitHub Actions
- name: Validate Cluster
  run: |
    ./create-cluster.sh cluster01 1 3
    ./validate cluster01
```

## Dependencies

### Required

| Dependency | Source | Purpose |
|------------|--------|---------|
| `lib/cluster-utils.sh` | Local | Auto-detection functions |
| `bash` | System | Shell interpreter |
| `docker compose` | Docker | Syntax validation |

### Optional (Enhanced Functionality)

| Tool | Purpose | Fallback Behavior |
|------|---------|-------------------|
| `openssl` | Certificate validation | Skips cert checks with warning |
| `lsof` | Port availability check | Tries `ss` or `netstat` |
| `ss` | Port availability check | Tries `lsof` or `netstat` |
| `netstat` | Port availability check | Tries `lsof` or `ss` |

## Performance Considerations

### Execution Time

**Typical validation times:**
- 3-node cluster: ~2-5 seconds
- 5-node cluster: ~3-7 seconds
- Large cluster (10+ nodes): ~5-15 seconds

**Slowest operations:**
- Certificate validation (openssl x509/pkcs12 checks)
- Docker Compose syntax validation
- Port availability checks

### Optimization Tips

1. **Skip on repeated runs:**
   ```bash
   # Validate once after creation
   ./create-cluster.sh cluster01 1 3 && ./validate cluster01
   
   # Skip validation on restarts
   docker compose -f docker-compose-cluster01.yml restart
   ```

2. **Parallel validation** (for multiple clusters):
   ```bash
   ./validate cluster01 & ./validate cluster02 & wait
   ```

## Limitations

### What Validate Does NOT Check

1. **Runtime behavior:**
   - Does not start containers
   - Does not verify cluster connectivity
   - Does not check ZooKeeper ensemble health
   - Does not validate NiFi cluster formation

2. **Content validation:**
   - Does not parse entire nifi.properties
   - Does not validate all configuration values
   - Does not check template files in conf/templates/

3. **External dependencies:**
   - Does not verify DNS resolution for FQDNs
   - Does not check network connectivity to remote clusters
   - Does not validate firewall rules

4. **Security audit:**
   - Does not check certificate expiration dates
   - Does not verify password strength
   - Does not audit authorization policies

### For Runtime Validation

Use these complementary tools:
- `./cluster wait <CLUSTER_NAME>` - Wait for cluster to be ready
- `./test <CLUSTER_NAME>` - Test runtime connectivity
- `./lib/check-cluster.sh <CLUSTER_NAME>` - Check running cluster health

## Best Practices

### When to Validate

**Always validate:**
1. After `create-cluster.sh` (before first start)
2. After manual configuration changes
3. Before deploying to production
4. In CI/CD pipelines

**Optional validation:**
- After cluster restarts (configuration rarely changes)
- During development iterations

### Handling Failures

1. **Read the error message:**
   - Provides specific file or property causing issue
   - Suggests expected vs. actual value

2. **Fix at the source:**
   - Regenerate configuration (recommended)
   - Manual fix (only if you understand implications)

3. **Re-validate:**
   ```bash
   ./validate cluster01
   ```

4. **Don't skip failures:**
   - All failures will cause deployment problems
   - Fix before proceeding

### Handling Warnings

1. **Review context:**
   - Warnings don't block deployment
   - May indicate environmental issues

2. **Common warnings:**
   - Ports in use (may be from this cluster if already running)
   - OpenSSL not available (cert validation skipped)
   - Running in container (port check skipped)

3. **Decide if safe to proceed:**
   - Port warnings: OK if cluster is already running
   - Missing tools: OK if you trust configuration generation

## Troubleshooting

### Problem: "Cluster not found"

**Cause:**
- docker-compose-<CLUSTER_NAME>.yml doesn't exist
- Wrong cluster name

**Solution:**
```bash
# List available clusters
ls docker-compose-cluster*.yml

# Create cluster first
./create-cluster.sh cluster01 1 3
```

### Problem: All certificate checks fail

**Cause:**
- OpenSSL not installed
- Wrong working directory

**Solution:**
```bash
# Install openssl
sudo apt-get install openssl   # Debian/Ubuntu
sudo yum install openssl       # RHEL/CentOS

# Run from project root
cd /path/to/nifi-cluster
./validate cluster01
```

### Problem: Port availability check shows false positives

**Cause:**
- Cluster is already running (ports in use by cluster itself)

**Solution:**
- This is a **warning**, not a failure
- Safe to proceed if cluster is running
- Or stop cluster before validation:
  ```bash
  docker compose -f docker-compose-cluster01.yml down
  ./validate cluster01
  ```

### Problem: Docker Compose syntax validation fails

**Cause:**
- Wrong Docker Compose version
- Compose file manually edited with errors

**Solution:**
```bash
# Check Docker Compose version
docker compose version

# Regenerate compose file
./lib/generate-docker-compose.sh cluster01 1 3

# Validate manually
docker compose -f docker-compose-cluster01.yml config
```

## Related Scripts

| Script | Relationship | When to Use |
|--------|-------------|-------------|
| `create-cluster.sh` | Creates what validate checks | Before validate |
| `./cluster start` | Starts validated cluster | After validate passes |
| `./cluster wait` | Waits for runtime readiness | After start |
| `./test` | Tests runtime connectivity | After wait |
| `check-cluster.sh` | Checks running cluster health | After cluster is running |
| `delete-cluster.sh` | Removes cluster | If validation fails irreparably |

## Summary

The `validate` script provides:
- **Pre-deployment safety net:** Catch errors before they cause runtime failures
- **Auto-detection:** No need to remember cluster parameters
- **Comprehensive coverage:** 7 validation sections covering all critical areas
- **Clear reporting:** Color-coded results with specific error messages
- **CI/CD friendly:** Exit codes and scriptable output
- **Fast execution:** Completes in seconds

**Key Principle:** Validate early, deploy confidently. All failures found by `validate` will cause deployment problems - fix them before starting containers.
