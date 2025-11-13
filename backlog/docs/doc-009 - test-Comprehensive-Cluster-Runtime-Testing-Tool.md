---
id: doc-009
title: test - Comprehensive Cluster Runtime Testing Tool
type: other
created_date: '2025-11-13 14:30'
---
# test - Comprehensive Cluster Runtime Testing Tool

## Overview

The `test` script is a comprehensive runtime validation tool that performs end-to-end testing of a running NiFi cluster. It validates SSL/TLS connectivity, authentication, API functionality, cluster health, ZooKeeper ensemble status, and data flow replication across all nodes. Unlike the `validate` script (which checks static configuration), `test` verifies the running cluster's operational status.

## Purpose

- **Runtime verification:** Confirm cluster is fully operational after startup
- **End-to-end testing:** Validate complete request flow from authentication to data replication
- **Auto-detection:** Automatically discovers cluster parameters from configuration
- **Comprehensive coverage:** Tests 9 critical areas of cluster operation
- **Non-destructive:** Creates and cleans up test resources
- **CI/CD friendly:** Returns exit code 0 for success, 1 for failures

## Script Architecture

```
test (Comprehensive Runtime Test Suite)
├── Dependencies
│   └── lib/cluster-utils.sh (for auto-detection functions)
│
├── Configuration Phase
│   ├── Auto-detect cluster parameters
│   ├── Load credentials (NIFI_USERNAME, NIFI_PASSWORD)
│   └── Locate CA certificate
│
└── Testing Phase (9 Test Suites)
    ├── 1. Prerequisites Check
    │   ├── curl availability
    │   ├── jq availability
    │   ├── docker availability
    │   └── CA certificate existence
    │
    ├── 2. Container Status Check
    │   └── Verify all NiFi containers are running
    │
    ├── 3. Web UI Access (HTTPS)
    │   └── Test HTTPS endpoint on each node (HTTP 200)
    │
    ├── 4. Authentication & JWT Tokens
    │   ├── Login to each node
    │   ├── Obtain JWT token
    │   └── Validate token length
    │
    ├── 5. Backend API Access
    │   ├── Call cluster summary API
    │   └── Parse JSON response
    │
    ├── 6. Cluster Status Verification
    │   ├── Connected node count
    │   ├── Total node count
    │   └── Clustered flag status
    │
    ├── 7. ZooKeeper Health Check
    │   ├── Container status
    │   └── Four-letter word (ruok) test
    │
    ├── 8. SSL/TLS Certificate Validation
    │   ├── SSL handshake test
    │   └── Certificate chain validation (with openssl)
    │
    └── 9. Flow Replication Test
        ├── Create test processor on Node 1
        ├── Wait for replication (5 seconds)
        ├── Verify processor exists on all nodes
        └── Cleanup (delete test processor)
```

## Parameters

### Required Parameter

| Parameter        | Type   | Description                                         | Example                      |
| ---------------- | ------ | --------------------------------------------------- | ---------------------------- |
| `CLUSTER_NAME` | String | Name of running cluster to test (format: clusterXX) | `cluster01`, `cluster02` |

### Optional Flags

| Flag               | Description                |
| ------------------ | -------------------------- |
| `--help`, `-h` | Show help message and exit |

### Environment Variables

| Variable          | Default            | Description         |
| ----------------- | ------------------ | ------------------- |
| `NIFI_USERNAME` | `admin`          | NiFi login username |
| `NIFI_PASSWORD` | `changeme123456` | NiFi login password |

### Auto-Detected Parameters

| Parameter       | Source                                           | Example                         |
| --------------- | ------------------------------------------------ | ------------------------------- |
| `CLUSTER_NUM` | Extracted from CLUSTER_NAME                      | `1` from `cluster01`        |
| `NODE_COUNT`  | Counted from docker-compose file                 | `3`                           |
| `BASE_PORT`   | Calculated from CLUSTER_NUM                      | `30000` = 29000 + (1 × 1000) |
| `HTTPS_BASE`  | BASE_PORT + 443                                  | `30443`                       |
| `ZK_BASE`     | BASE_PORT + 181                                  | `30181`                       |
| `CA_CERT`     | `clusters/<CLUSTER_NAME>/certs/ca/ca-cert.pem` | Path to CA certificate          |

## Test Suites

### Test Suite 1: Prerequisites Check

**Purpose:** Verify all required tools are available

**Tests:**

1. **curl availability**

   ```bash
   command -v curl &> /dev/null
   ```

   - **Pass:** curl is installed
   - **Fail:** curl is not installed (required for API calls)
2. **jq availability**

   ```bash
   command -v jq &> /dev/null
   ```

   - **Pass:** jq is installed
   - **Fail:** jq is not installed (required for JSON parsing)
3. **docker availability**

   ```bash
   command -v docker &> /dev/null
   ```

   - **Pass:** docker is installed
   - **Fail:** docker is not installed (required for container checks)
4. **CA certificate existence**

   ```bash
   [ -f clusters/<CLUSTER_NAME>/certs/ca/ca-cert.pem ]
   ```

   - **Pass:** CA certificate found
   - **Fail:** CA certificate not found (required for SSL/TLS)

**Failure Impact:** Missing prerequisites will cause subsequent tests to fail

### Test Suite 2: Container Status Check

**Purpose:** Verify all NiFi containers are running

**Tests:**
For each node (1 to NODE_COUNT):

```bash
docker ps --format '{{.Names}}\t{{.State}}' | grep "^<CLUSTER_NAME>.nifi-${i}"
```

- **Pass:** Container is running
- **Fail:** Container is stopped, paused, or not found

**Example Output:**

```
[TEST] Checking Docker containers...
  ✓ PASS: cluster01.nifi-1 is running
  ✓ PASS: cluster01.nifi-2 is running
  ✓ PASS: cluster01.nifi-3 is running
```

**Failure Impact:** Subsequent tests will fail if containers are not running

### Test Suite 3: Web UI Access (HTTPS)

**Purpose:** Verify HTTPS endpoints are accessible

**Tests:**
For each node (1 to NODE_COUNT):

```bash
curl --cacert $CA_CERT -s -o /dev/null -w "%{http_code}" -L https://localhost:$PORT/nifi/
```

**Expected:** HTTP 200
**Pass Conditions:** Returns HTTP 200
**Fail Conditions:** Returns any other HTTP status code

**Example Output:**

```
[TEST] Testing Node 1 (port 30443)...
  ✓ PASS: Web UI accessible (HTTP 200)
[TEST] Testing Node 2 (port 30444)...
  ✓ PASS: Web UI accessible (HTTP 200)
[TEST] Testing Node 3 (port 30445)...
  ✓ PASS: Web UI accessible (HTTP 200)
```

**What This Tests:**

- HTTPS listener is active
- SSL/TLS handshake succeeds
- NiFi UI is responsive
- Certificate chain is valid

### Test Suite 4: Authentication & JWT Tokens

**Purpose:** Verify authentication system and obtain access tokens

**Tests:**
For each node (1 to NODE_COUNT):

```bash
curl --cacert $CA_CERT -s -X POST \
  https://localhost:$PORT/nifi-api/access/token \
  -d "username=$USERNAME&password=$PASSWORD"
```

**Expected:** JWT token (long base64-encoded string)

**Pass Conditions:**

- Token is non-empty
- Token length > 100 characters

**Fail Conditions:**

- No token returned
- Token too short (indicates error)

**Example Output:**

```
[TEST] Testing login on Node 1...
  ✓ PASS: JWT token obtained (847 chars)
[TEST] Testing login on Node 2...
  ✓ PASS: JWT token obtained (851 chars)
[TEST] Testing login on Node 3...
  ✓ PASS: JWT token obtained (849 chars)
```

**What This Tests:**

- Single user authentication is configured
- Username/password are correct
- Token generation is working
- Saves tokens for subsequent API tests

**Token Storage:**
Tokens are stored in variables: `NODE_1_TOKEN`, `NODE_2_TOKEN`, `NODE_3_TOKEN`

### Test Suite 5: Backend API Access

**Purpose:** Verify REST API is functional with authentication

**Tests:**
For each node (1 to NODE_COUNT):

```bash
curl --cacert $CA_CERT -s \
  -H "Authorization: Bearer $TOKEN" \
  https://localhost:$PORT/nifi-api/flow/cluster/summary
```

**Expected:** JSON response with `clusterSummary` object

**Pass Conditions:**

- Response contains valid JSON
- `clusterSummary` field exists
- `connectedNodes` value is present

**Fail Conditions:**

- No response
- Invalid JSON
- Missing expected fields

**Example Output:**

```
[TEST] Testing backend API on Node 1...
  ✓ PASS: Cluster summary API working (3 nodes)
[TEST] Testing backend API on Node 2...
  ✓ PASS: Cluster summary API working (3 nodes)
[TEST] Testing backend API on Node 3...
  ✓ PASS: Cluster summary API working (3 nodes)
```

**What This Tests:**

- JWT token authentication works
- REST API is responsive
- JSON responses are properly formatted
- Cluster awareness is functioning

### Test Suite 6: Cluster Status Verification

**Purpose:** Verify cluster formation and all nodes are connected

**Test:**
Query Node 1 for cluster summary:

```bash
curl --cacert $CA_CERT -s \
  -H "Authorization: Bearer $TOKEN" \
  https://localhost:$HTTPS_BASE/nifi-api/flow/cluster/summary
```

**Parse Response:**

```json
{
  "clusterSummary": {
    "connectedNodeCount": 3,
    "totalNodeCount": 3,
    "clustered": true,
    "connectedNodes": "3 / 3 nodes are connected"
  }
}
```

**Pass Conditions:**

- `connectedNodeCount` == `totalNodeCount`
- `clustered` == `true`

**Fail Conditions:**

- Nodes not fully connected
- Cluster mode not active
- Missing nodes

**Example Output:**

```
[TEST] Checking cluster status...
  ✓ PASS: All nodes connected: 3 / 3
  ✓ PASS: Cluster mode active: true
```

**What This Tests:**

- All nodes discovered each other
- ZooKeeper coordination working
- Cluster election completed
- No split-brain scenarios

### Test Suite 7: ZooKeeper Health Check

**Purpose:** Verify ZooKeeper ensemble is healthy

**Tests:**
For each ZooKeeper node (1 to NODE_COUNT):

1. **Container Status:**

   ```bash
   docker ps --format '{{.Names}}' | grep "^<CLUSTER_NAME>.zookeeper-${i}$"
   ```
2. **Four-Letter Word Test** (if `nc` available):

   ```bash
   echo "ruok" | nc localhost $ZK_PORT
   ```

   - **Expected:** `imok` response

**Pass Conditions:**

- Container is running
- Responds to `ruok` with `imok` (if nc available)
- Or just container running (if nc unavailable)

**Fail Conditions:**

- Container not running
- No response to health check

**Example Output:**

```
[TEST] Testing ZooKeeper Node 1...
  ✓ PASS: ZooKeeper-1 is healthy
[TEST] Testing ZooKeeper Node 2...
  ✓ PASS: ZooKeeper-2 is healthy
[TEST] Testing ZooKeeper Node 3...
  ✓ PASS: ZooKeeper-3 is healthy
```

**What This Tests:**

- ZooKeeper containers are running
- ZooKeeper is accepting connections
- Ensemble is responsive

**Note:** Four-letter word commands require ZooKeeper configuration to whitelist them (`ZOO_4LW_COMMANDS_WHITELIST: "*"`)

### Test Suite 8: SSL/TLS Certificate Validation

**Purpose:** Verify SSL/TLS configuration and certificate validity

**Tests:**
For each node (1 to NODE_COUNT):

1. **SSL Handshake Test:**

   ```bash
   curl --cacert $CA_CERT -s -o /dev/null https://localhost:$PORT/nifi/
   ```
2. **Certificate Details** (if openssl available):

   ```bash
   echo | openssl s_client -connect localhost:$PORT -CAfile $CA_CERT 2>/dev/null | \
     openssl x509 -noout -subject -issuer
   ```

**Pass Conditions:**

- SSL handshake succeeds
- Certificate validated by CA
- Certificate details retrieved (if openssl available)

**Fail Conditions:**

- SSL handshake fails
- Certificate not trusted
- Certificate expired or invalid

**Example Output:**

```
[TEST] Testing SSL handshake on Node 1...
  ✓ PASS: SSL/TLS handshake successful
  ✓ PASS: Certificate validated
[TEST] Testing SSL handshake on Node 2...
  ✓ PASS: SSL/TLS handshake successful
  ✓ PASS: Certificate validated
[TEST] Testing SSL handshake on Node 3...
  ✓ PASS: SSL/TLS handshake successful
  ✓ PASS: Certificate validated
```

**What This Tests:**

- SSL/TLS listener is configured
- Certificates are properly installed
- CA trust chain is valid
- TLS protocol negotiation works

### Test Suite 9: Flow Replication Test

**Purpose:** Verify cluster replication is working by creating and verifying a test processor

**Test Steps:**

1. **Create Test Processor on Node 1:**

   ```bash
   # Get root process group ID
   ROOT_PG=$(curl ... /nifi-api/flow/process-groups/root | jq -r '.processGroupFlow.id')

   # Create GenerateFlowFile processor with unique name
   PROCESSOR_NAME="ClusterReplicationTest-$(date +%s)"
   curl -X POST .../nifi-api/process-groups/$ROOT_PG/processors \
     -d '{"component": {"type": "org.apache.nifi.processors.standard.GenerateFlowFile", ...}}'
   ```
2. **Wait for Replication:**

   ```bash
   sleep 5  # Allow time for cluster replication
   ```
3. **Verify on All Nodes:**
   For each node, query:

   ```bash
   curl .../nifi-api/flow/process-groups/$ROOT_PG | \
     jq ".processGroupFlow.flow.processors[] | select(.component.name==\"$PROCESSOR_NAME\")"
   ```
4. **Cleanup:**

   ```bash
   # Delete test processor
   curl -X DELETE .../nifi-api/processors/$PROCESSOR_ID?version=$VERSION
   ```

**Pass Conditions:**

- Processor created successfully on Node 1
- Processor ID returned
- Processor found on all nodes after 5 seconds
- Processor deleted successfully

**Fail Conditions:**

- Cannot create processor
- Processor not replicated to all nodes
- Replication timeout

**Example Output:**

```
[TEST] Creating test processor on Node 1...
  ✓ PASS: Test processor created: ClusterReplicationTest-1699876543
  ℹ INFO: Processor ID: 12345678-1234-1234-1234-123456789012
  ℹ INFO: Waiting 5 seconds for cluster replication...
[TEST] Verifying flow replication across all nodes...
  ✓ PASS: Node 1: Processor replicated successfully
  ✓ PASS: Node 2: Processor replicated successfully
  ✓ PASS: Node 3: Processor replicated successfully
[TEST] Cleaning up test processor...
  ℹ INFO: Test processor deleted
```

**What This Tests:**

- Flow replication is working
- Cluster coordination via ZooKeeper
- All nodes can modify the flow
- Changes propagate to all nodes
- RESTful API for flow modifications

**Processor Configuration:**

- Type: `GenerateFlowFile` (standard processor)
- Scheduling: 60 seconds (won't actually run)
- Auto-terminated: Success relationship
- Position: (300, 300) on canvas

## Output Format

### Color Coding

```
✓ PASS - Green  - Test passed
✗ FAIL - Red    - Test failed
ℹ INFO - Yellow - Informational message
```

### Test Format

```
[TEST] Description...
  ✓ PASS: Success message
  ✗ FAIL: Failure message
  ℹ INFO: Additional information
```

### Summary Format

```
════════════════════════════════════════════════════════════════
 Test Summary
════════════════════════════════════════════════════════════════

Results:
  Passed:   32 / 32
  Failed:   0 / 32

╔════════════════════════════════════════════════════════════════╗
║  ✓ All tests passed!                                          ║
╚════════════════════════════════════════════════════════════════╝

Your cluster is fully operational!

  Node 1: https://localhost:30443/nifi
  Node 2: https://localhost:30444/nifi
  Node 3: https://localhost:30445/nifi
```

## Exit Codes

| Code | Condition         | Meaning                                       |
| ---- | ----------------- | --------------------------------------------- |
| 0    | FAILED == 0       | All tests passed                              |
| 1    | FAILED > 0        | One or more tests failed                      |
| 1    | Invalid arguments | Cluster name missing or invalid               |
| 1    | Cluster not found | No configuration exists for specified cluster |

## Usage Examples

### Example 1: Test Newly Started Cluster

```bash
./test cluster01
```

**Typical Output (All Pass):**

```
╔════════════════════════════════════════════════════════════════╗
║  NiFi Cluster Comprehensive Test Suite                        ║
╚════════════════════════════════════════════════════════════════╝

Configuration (auto-detected):
  Cluster Name:   cluster01
  Cluster Number: 1
  Node Count:     3
  Base Port:      30000
  HTTPS Ports:    30443-30445
  ZK Ports:       30181-30183
  CA Certificate: /path/to/clusters/cluster01/certs/ca/ca-cert.pem
  Username:       admin

════════════════════════════════════════════════════════════════
 1. Prerequisites Check
════════════════════════════════════════════════════════════════

[TEST] Checking required tools...
  ✓ PASS: curl is installed
  ✓ PASS: jq is installed
  ✓ PASS: docker is installed
  ✓ PASS: CA certificate found

════════════════════════════════════════════════════════════════
 2. Container Status Check
════════════════════════════════════════════════════════════════

[TEST] Checking Docker containers...
  ✓ PASS: cluster01.nifi-1 is running
  ✓ PASS: cluster01.nifi-2 is running
  ✓ PASS: cluster01.nifi-3 is running

════════════════════════════════════════════════════════════════
 3. Web UI Access (HTTPS)
════════════════════════════════════════════════════════════════

[TEST] Testing Node 1 (port 30443)...
  ✓ PASS: Web UI accessible (HTTP 200)
[TEST] Testing Node 2 (port 30444)...
  ✓ PASS: Web UI accessible (HTTP 200)
[TEST] Testing Node 3 (port 30445)...
  ✓ PASS: Web UI accessible (HTTP 200)

════════════════════════════════════════════════════════════════
 4. Authentication & JWT Tokens
════════════════════════════════════════════════════════════════

[TEST] Testing login on Node 1...
  ✓ PASS: JWT token obtained (847 chars)
[TEST] Testing login on Node 2...
  ✓ PASS: JWT token obtained (851 chars)
[TEST] Testing login on Node 3...
  ✓ PASS: JWT token obtained (849 chars)

════════════════════════════════════════════════════════════════
 5. Backend API Access
════════════════════════════════════════════════════════════════

[TEST] Testing backend API on Node 1...
  ✓ PASS: Cluster summary API working (3 nodes)
[TEST] Testing backend API on Node 2...
  ✓ PASS: Cluster summary API working (3 nodes)
[TEST] Testing backend API on Node 3...
  ✓ PASS: Cluster summary API working (3 nodes)

════════════════════════════════════════════════════════════════
 6. Cluster Status Verification
════════════════════════════════════════════════════════════════

[TEST] Checking cluster status...
  ✓ PASS: All nodes connected: 3 / 3
  ✓ PASS: Cluster mode active: true

════════════════════════════════════════════════════════════════
 7. ZooKeeper Health Check
════════════════════════════════════════════════════════════════

[TEST] Testing ZooKeeper Node 1...
  ✓ PASS: ZooKeeper-1 is healthy
[TEST] Testing ZooKeeper Node 2...
  ✓ PASS: ZooKeeper-2 is healthy
[TEST] Testing ZooKeeper Node 3...
  ✓ PASS: ZooKeeper-3 is healthy

════════════════════════════════════════════════════════════════
 8. SSL/TLS Certificate Validation
════════════════════════════════════════════════════════════════

[TEST] Testing SSL handshake on Node 1...
  ✓ PASS: SSL/TLS handshake successful
  ✓ PASS: Certificate validated
[TEST] Testing SSL handshake on Node 2...
  ✓ PASS: SSL/TLS handshake successful
  ✓ PASS: Certificate validated
[TEST] Testing SSL handshake on Node 3...
  ✓ PASS: SSL/TLS handshake successful
  ✓ PASS: Certificate validated

════════════════════════════════════════════════════════════════
 9. Flow Replication Test
════════════════════════════════════════════════════════════════

[TEST] Creating test processor on Node 1...
  ✓ PASS: Test processor created: ClusterReplicationTest-1699876543
  ℹ INFO: Processor ID: 018c1234-5678-1234-5678-123456789012
  ℹ INFO: Waiting 5 seconds for cluster replication...
[TEST] Verifying flow replication across all nodes...
  ✓ PASS: Node 1: Processor replicated successfully
  ✓ PASS: Node 2: Processor replicated successfully
  ✓ PASS: Node 3: Processor replicated successfully
[TEST] Cleaning up test processor...
  ℹ INFO: Test processor deleted

════════════════════════════════════════════════════════════════
 Test Summary
════════════════════════════════════════════════════════════════

Results:
  Passed:   32 / 32
  Failed:   0 / 32

╔════════════════════════════════════════════════════════════════╗
║  ✓ All tests passed!                                          ║
╚════════════════════════════════════════════════════════════════╝

Your cluster is fully operational!

  Node 1: https://localhost:30443/nifi
  Node 2: https://localhost:30444/nifi
  Node 3: https://localhost:30445/nifi
```

### Example 2: Test with Failures

```bash
./test cluster02
```

**Output (with failures):**

```
════════════════════════════════════════════════════════════════
 2. Container Status Check
════════════════════════════════════════════════════════════════

[TEST] Checking Docker containers...
  ✓ PASS: cluster02.nifi-1 is running
  ✗ FAIL: cluster02.nifi-2 is exited
  ✓ PASS: cluster02.nifi-3 is running

[... more tests ...]

════════════════════════════════════════════════════════════════
 6. Cluster Status Verification
════════════════════════════════════════════════════════════════

[TEST] Checking cluster status...
  ✗ FAIL: Cluster not fully connected: 2 / 3

════════════════════════════════════════════════════════════════
 Test Summary
════════════════════════════════════════════════════════════════

Results:
  Passed:   25 / 32
  Failed:   7 / 32

╔════════════════════════════════════════════════════════════════╗
║  ✗ Some tests failed                                          ║
╚════════════════════════════════════════════════════════════════╝

Review the failed tests above.
```

### Example 3: Custom Credentials

```bash
export NIFI_USERNAME=myuser
export NIFI_PASSWORD=mysecurepass
./test cluster01
```

### Example 4: Test Non-Existent Cluster

```bash
./test cluster99
```

**Output:**

```
Error: Cluster cluster99 not found

Available clusters:
  cluster01
  cluster02
```

## Common Failure Scenarios

### Scenario 1: Containers Not Running

**Symptoms:**

```
[TEST] Checking Docker containers...
  ✗ FAIL: cluster01.nifi-1 is exited
```

**Causes:**

- Cluster not started
- Container crashed
- Resource constraints

**Diagnosis:**

```bash
# Check container logs
docker logs cluster01.nifi-1

# Check container status
docker ps -a | grep cluster01.nifi
```

**Fix:**

```bash
# Restart cluster
docker compose -f docker-compose-cluster01.yml restart

# Or investigate and fix underlying issue
```

### Scenario 2: Authentication Failures

**Symptoms:**

```
[TEST] Testing login on Node 1...
  ✗ FAIL: Failed to obtain JWT token
```

**Causes:**

- Wrong username/password
- Single user authentication not configured
- NiFi not fully started

**Diagnosis:**

```bash
# Check credentials in .env
cat .env | grep NIFI_SINGLE_USER

# Check NiFi logs for auth errors
docker logs cluster01.nifi-1 | grep -i "auth\|login"
```

**Fix:**

```bash
# Use correct credentials
export NIFI_USERNAME=admin
export NIFI_PASSWORD=changeme123456
./test cluster01

# Or wait for NiFi to fully start
./cluster wait cluster01
./test cluster01
```

### Scenario 3: Cluster Not Fully Connected

**Symptoms:**

```
[TEST] Checking cluster status...
  ✗ FAIL: Cluster not fully connected: 2 / 3
```

**Causes:**

- ZooKeeper issues
- Network connectivity problems
- Node configuration mismatch
- Insufficient startup time

**Diagnosis:**

```bash
# Check ZooKeeper logs
docker logs cluster01.zookeeper-1

# Check NiFi cluster logs
docker logs cluster01.nifi-3 | grep -i "cluster"

# Check cluster status via API
curl -k -u admin:changeme123456 \
  https://localhost:30443/nifi-api/controller/cluster
```

**Fix:**

```bash
# Wait longer for cluster formation
sleep 60
./test cluster01

# Or restart problematic node
docker restart cluster01.nifi-3
```

### Scenario 4: Flow Replication Fails

**Symptoms:**

```
[TEST] Verifying flow replication across all nodes...
  ✓ PASS: Node 1: Processor replicated successfully
  ✗ FAIL: Node 2: Processor NOT found (replication failed)
  ✓ PASS: Node 3: Processor replicated successfully
```

**Causes:**

- Cluster coordination issues
- ZooKeeper problems
- Network partitioning
- Replication lag (need more than 5 seconds)

**Diagnosis:**

```bash
# Check cluster connectivity
docker logs cluster01.nifi-2 | grep -i "cluster\|replication"

# Check ZooKeeper connectivity
docker logs cluster01.nifi-2 | grep -i "zookeeper"
```

**Fix:**

```bash
# Restart affected node
docker restart cluster01.nifi-2

# Wait and re-test
sleep 60
./test cluster01
```

### Scenario 5: SSL/TLS Handshake Failures

**Symptoms:**

```
[TEST] Testing SSL handshake on Node 1...
  ✗ FAIL: SSL/TLS handshake failed
```

**Causes:**

- Certificate expired
- CA certificate mismatch
- Wrong certificate path
- TLS protocol mismatch

**Diagnosis:**

```bash
# Check certificate validity
openssl x509 -in clusters/cluster01/certs/ca/ca-cert.pem -noout -dates

# Test SSL connection manually
openssl s_client -connect localhost:30443 -CAfile clusters/cluster01/certs/ca/ca-cert.pem
```

**Fix:**

```bash
# Regenerate certificates if needed
cd certs
./generate-certs.sh 3 ../clusters/cluster01/certs cluster01
cd ..

# Restart cluster to load new certificates
docker compose -f docker-compose-cluster01.yml restart
```

## Integration with Cluster Workflow

### Recommended Workflow

```bash
# 1. Create cluster
./create-cluster.sh cluster01 1 3

# 2. Validate configuration
./validate cluster01

# 3. Start cluster
docker compose -f docker-compose-cluster01.yml up -d

# 4. Wait for cluster to be ready
./cluster wait cluster01

# 5. Test cluster (THIS SCRIPT)
./test cluster01

# 6. If all tests pass, cluster is ready for use
```

### CI/CD Integration

```yaml
# Example GitLab CI
test-cluster:
  stage: test
  script:
    - docker compose -f docker-compose-cluster01.yml up -d
    - sleep 180  # Wait for startup
    - ./test cluster01
  only:
    - main
```

```yaml
# Example GitHub Actions
- name: Test Cluster
  run: |
    docker compose -f docker-compose-cluster01.yml up -d
    timeout 300 bash -c 'until ./test cluster01; do sleep 10; done'
```

## Dependencies

### Required

| Dependency               | Purpose              | Install                                         |
| ------------------------ | -------------------- | ----------------------------------------------- |
| `bash`                 | Shell interpreter    | System default                                  |
| `curl`                 | HTTP client          | `apt install curl`                            |
| `jq`                   | JSON parser          | `apt install jq`                              |
| `docker`               | Container management | [Docker Docs](https://docs.docker.com/get-docker/) |
| `lib/cluster-utils.sh` | Auto-detection       | Local file                                      |

### Optional (Enhanced Functionality)

| Tool            | Purpose                | Fallback Behavior         |
| --------------- | ---------------------- | ------------------------- |
| `nc` (netcat) | ZooKeeper health check | Skips detailed ZK test    |
| `openssl`     | Certificate validation | Skips certificate details |

## Performance Considerations

### Execution Time

**Typical test times:**

- Prerequisites: ~1 second
- Container checks: ~1 second
- Web UI tests: ~3 seconds (1 second per node)
- Authentication: ~3 seconds (1 second per node)
- API tests: ~3 seconds (1 second per node)
- Cluster status: ~1 second
- ZooKeeper: ~3 seconds (1 second per node)
- SSL validation: ~6 seconds (2 seconds per node)
- Flow replication: ~10 seconds (5 second wait + verifications)

**Total:** ~30-40 seconds for 3-node cluster

### Optimization Tips

1. **Skip slow tests for quick checks:**

   - Comment out Test Suite 9 (flow replication)
   - Reduces runtime by ~10 seconds
2. **Parallel execution** (for multiple clusters):

   ```bash
   ./test cluster01 & ./test cluster02 & wait
   ```
3. **Adjust replication wait time:**

   - Default 5 seconds may be too short for large clusters
   - Increase for slower networks: `sleep 10`

## Limitations

### What Test Does NOT Check

1. **Data flow execution:**

   - Does not start processors
   - Does not verify data processing
   - Does not test actual FlowFile routing
2. **Performance testing:**

   - No load testing
   - No throughput measurements
   - No latency testing
3. **Advanced features:**

   - Site-to-Site to remote clusters
   - User/group management
   - Custom processors
   - Parameter contexts
   - Version control (NiFi Registry)
4. **Security audit:**

   - Certificate expiration dates
   - Password strength
   - Authorization policies details

### For Additional Testing

Use these complementary tools:

- **NiFi UI:** Manual testing of flows
- **Performance testing:** JMeter, custom load scripts
- **Monitoring:** Prometheus + Grafana
- **Site-to-Site testing:** Custom scripts (see `verify-s2s-port.sh`)

## Best Practices

### When to Test

**Always test:**

1. After cluster startup (before using)
2. After cluster restart
3. After configuration changes
4. Before deploying flows to production
5. In CI/CD pipelines
6. After infrastructure changes

**Periodic testing:**

- Daily health checks (automated)
- Before major deployments
- After system updates

### Interpreting Results

1. **All tests pass:** Cluster is fully operational
2. **Prerequisites fail:** Install missing tools
3. **Container tests fail:** Investigate container health
4. **Auth tests fail:** Check credentials and NiFi startup
5. **Cluster tests fail:** Wait longer or investigate coordination
6. **Replication fails:** Check cluster connectivity

### Handling Intermittent Failures

Some tests may fail intermittently due to timing:

```bash
# Retry mechanism
for i in {1..3}; do
  if ./test cluster01; then
    echo "Tests passed on attempt $i"
    break
  fi
  echo "Tests failed on attempt $i, retrying in 30s..."
  sleep 30
done
```

## Troubleshooting

### Problem: "CA certificate not found"

**Cause:**

- Certificates not generated
- Wrong working directory

**Solution:**

```bash
# Regenerate certificates
cd certs
./generate-certs.sh 3 ../clusters/cluster01/certs cluster01
cd ..

# Ensure running from project root
cd /path/to/nifi-cluster
./test cluster01
```

### Problem: "curl is not installed"

**Cause:**

- curl not installed on system

**Solution:**

```bash
# Ubuntu/Debian
sudo apt-get install curl jq

# RHEL/CentOS
sudo yum install curl jq

# macOS
brew install curl jq
```

### Problem: All tests timeout

**Cause:**

- NiFi not fully started
- Containers not running

**Solution:**

```bash
# Check container status
docker ps | grep cluster01

# Wait for full startup
./cluster wait cluster01

# Then test
./test cluster01
```

### Problem: "Cluster not fully connected" persists

**Cause:**

- ZooKeeper issues
- Configuration mismatch
- Network problems

**Solution:**

```bash
€€# Check ZooKeeper logs
docker logs cluster01.zookeeper-1

# Check NiFi cluster logs
for i in {1..3}; do
  echo "=== Node $i ==="
  docker logs cluster01.nifi-$i | grep -i "cluster" | tail -20
done

# Restart cluster
docker compose -f docker-compose-cluster01.yml restart
sleep 180
./test cluster01
```

## Related Scripts

| Script                | Relationship              | When to Use             |
| --------------------- | ------------------------- | ----------------------- |
| `create-cluster.sh` | Creates cluster           | Before test             |
| `validate`          | Pre-deployment validation | Before starting cluster |
| `./cluster start`   | Starts cluster            | Before test             |
| `./cluster wait`    | Waits for readiness       | Before test             |
| `check-cluster.sh`  | Runtime health check      | Alternative to test     |
| `delete-cluster.sh` | Removes cluster           | After testing complete  |

## Summary

The `test` script provides:

- **Comprehensive runtime validation:** 9 test suites covering all critical areas
- **End-to-end verification:** From SSL handshake to flow replication
- **Auto-detection:** No need to remember cluster parameters
- **Non-destructive:** Creates and cleans up test resources
- **Clear reporting:** Color-coded results with detailed messages
- **CI/CD friendly:** Exit codes and scriptable output
- **Fast execution:** Completes in ~30-40 seconds

**Key Principle:** Test after deployment, deploy with confidence. All tests passing means your cluster is fully operational and ready for production flows.
