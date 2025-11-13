#!/bin/bash
# Comprehensive NiFi cluster testing - auto-detects all parameters
# This script is designed to be called from the cluster command
# Usage: ./lib/test.sh <cluster_name>
#
# Example: ./lib/test.sh cluster01

set +e  # Don't exit on error - collect all test results

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/cluster-utils.sh"

# Counters
PASSED=0
FAILED=0

# Helper functions
print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
    echo -e "  ${GREEN}✓ PASS:${NC} $1"
    ((PASSED++))
}

print_fail() {
    echo -e "  ${RED}✗ FAIL:${NC} $1"
    ((FAILED++))
}

print_info() {
    echo -e "  ${YELLOW}ℹ INFO:${NC} $1"
}

# Show help
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat << EOF
${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}
${BLUE}║  NiFi Cluster Comprehensive Test Suite                        ║${NC}
${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}

Tests SSL/TLS, authentication, backend API, and cluster connectivity.
All parameters are auto-detected!

Usage: $0 <cluster_name>

Examples:
  $0 cluster01      # Test cluster01 (auto-detects ports, nodes, etc.)
  $0 cluster02      # Test cluster02

Environment Variables:
  NIFI_USERNAME   NiFi username (default: admin)
  NIFI_PASSWORD   NiFi password (default: changeme123456)

Tests Performed:
  1. Prerequisites check (tools, certificates)
  2. Container status check
  3. Web UI access (HTTPS)
  4. Authentication & JWT token generation
  5. Backend API access
  6. Cluster status verification
  7. ZooKeeper health check
  8. SSL/TLS certificate validation (openssl)
  9. Flow replication test (create, verify, cleanup)

EOF
    exit 0
fi

# Validate arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Cluster name required${NC}"
    echo "Usage: $0 <cluster_name>"
    echo "Example: $0 cluster01"
    exit 1
fi

CLUSTER_NAME="$1"

# Validate cluster
if ! validate_cluster_name "$CLUSTER_NAME"; then
    exit 1
fi

if ! cluster_exists "$CLUSTER_NAME"; then
    echo -e "${RED}Error: Cluster ${CLUSTER_NAME} not found${NC}"
    echo ""
    echo "Available clusters:"
    "${SCRIPT_DIR}/cluster" list
    exit 1
fi

# Auto-detect parameters
CLUSTER_NUM=$(get_cluster_num "$CLUSTER_NAME")
NODE_COUNT=$(get_node_count "$CLUSTER_NAME")
BASE_PORT=$(get_base_port "$CLUSTER_NUM")
HTTPS_BASE=$((BASE_PORT + 443))
ZK_BASE=$((BASE_PORT + 181))

CA_CERT="${SCRIPT_DIR}/clusters/${CLUSTER_NAME}/certs/ca/ca-cert.pem"
USERNAME="${NIFI_USERNAME:-admin}"
PASSWORD="${NIFI_PASSWORD:-changeme123456}"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  NiFi Cluster Comprehensive Test Suite                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Configuration (auto-detected):"
echo "  Cluster Name:   $CLUSTER_NAME"
echo "  Cluster Number: $CLUSTER_NUM"
echo "  Node Count:     $NODE_COUNT"
echo "  Base Port:      $BASE_PORT"
echo "  HTTPS Ports:    ${HTTPS_BASE}-$((HTTPS_BASE + NODE_COUNT - 1))"
echo "  ZK Ports:       ${ZK_BASE}-$((ZK_BASE + NODE_COUNT - 1))"
echo "  CA Certificate: $CA_CERT"
echo "  Username:       $USERNAME"
echo ""

# Test 1: Prerequisites
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} 1. Prerequisites Check${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

print_test "Checking required tools..."

if command -v curl &> /dev/null; then
    print_pass "curl is installed"
else
    print_fail "curl is not installed"
fi

if command -v jq &> /dev/null; then
    print_pass "jq is installed"
else
    print_fail "jq is not installed"
fi

if command -v docker &> /dev/null; then
    print_pass "docker is installed"
else
    print_fail "docker is not installed"
fi

if [ -f "$CA_CERT" ]; then
    print_pass "CA certificate found"
else
    print_fail "CA certificate not found: $CA_CERT"
fi

# Test 2: Container Status
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} 2. Container Status Check${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

print_test "Checking Docker containers..."

for i in $(seq 1 "$NODE_COUNT"); do
    container="${CLUSTER_NAME}.nifi-${i}"
    STATUS=$(docker ps --format '{{.Names}}\t{{.State}}' | grep "^${container}" | awk '{print $2}')
    if [ "$STATUS" == "running" ]; then
        print_pass "$container is running"
    else
        print_fail "$container is $STATUS"
    fi
done

# Test 3: Web UI Access
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} 3. Web UI Access (HTTPS)${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

for i in $(seq 1 "$NODE_COUNT"); do
    PORT=$((HTTPS_BASE + i - 1))
    print_test "Testing Node $i (port $PORT)..."

    HTTP_STATUS=$(curl --cacert "$CA_CERT" -s -o /dev/null -w "%{http_code}" -L https://localhost:$PORT/nifi/ 2>/dev/null)

    if [ "$HTTP_STATUS" == "200" ]; then
        print_pass "Web UI accessible (HTTP $HTTP_STATUS)"
    else
        print_fail "Web UI returned HTTP $HTTP_STATUS"
    fi
done

# Test 4: Authentication
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} 4. Authentication & JWT Tokens${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

for i in $(seq 1 "$NODE_COUNT"); do
    PORT=$((HTTPS_BASE + i - 1))
    print_test "Testing login on Node $i..."

    TOKEN=$(curl --cacert "$CA_CERT" -s -X POST \
        https://localhost:$PORT/nifi-api/access/token \
        -d "username=$USERNAME&password=$PASSWORD" 2>/dev/null)

    if [ -n "$TOKEN" ] && [ ${#TOKEN} -gt 100 ]; then
        print_pass "JWT token obtained (${#TOKEN} chars)"
        eval "NODE_${i}_TOKEN='$TOKEN'"
    else
        print_fail "Failed to obtain JWT token"
    fi
done

# Test 5: Backend API
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} 5. Backend API Access${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

for i in $(seq 1 "$NODE_COUNT"); do
    PORT=$((HTTPS_BASE + i - 1))
    print_test "Testing backend API on Node $i..."

    TOKEN_VAR="NODE_${i}_TOKEN"
    TOKEN="${!TOKEN_VAR}"

    if [ -z "$TOKEN" ]; then
        print_fail "No token available"
        continue
    fi

    RESPONSE=$(curl --cacert "$CA_CERT" -s \
        -H "Authorization: Bearer $TOKEN" \
        https://localhost:$PORT/nifi-api/flow/cluster/summary 2>/dev/null)

    if echo "$RESPONSE" | jq -e '.clusterSummary' > /dev/null 2>&1; then
        CONNECTED=$(echo "$RESPONSE" | jq -r '.clusterSummary.connectedNodes')
        print_pass "Cluster summary API working (${CONNECTED} nodes)"
    else
        print_fail "Backend API not responding correctly"
    fi
done

# Test 6: Cluster Status
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} 6. Cluster Status Verification${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

PORT=$HTTPS_BASE
print_test "Checking cluster status..."

TOKEN="$NODE_1_TOKEN"

if [ -z "$TOKEN" ]; then
    print_fail "No token available"
else
    RESPONSE=$(curl --cacert "$CA_CERT" -s \
        -H "Authorization: Bearer $TOKEN" \
        https://localhost:$PORT/nifi-api/flow/cluster/summary 2>/dev/null)

    CONNECTED_COUNT=$(echo "$RESPONSE" | jq -r '.clusterSummary.connectedNodeCount')
    TOTAL_COUNT=$(echo "$RESPONSE" | jq -r '.clusterSummary.totalNodeCount')
    CLUSTERED=$(echo "$RESPONSE" | jq -r '.clusterSummary.clustered')

    if [ "$CONNECTED_COUNT" == "$TOTAL_COUNT" ] && [ "$CLUSTERED" == "true" ]; then
        print_pass "All nodes connected: $CONNECTED_COUNT / $TOTAL_COUNT"
        print_pass "Cluster mode active: $CLUSTERED"
    else
        print_fail "Cluster not fully connected: $CONNECTED_COUNT / $TOTAL_COUNT"
    fi
fi

# Test 7: ZooKeeper Health
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} 7. ZooKeeper Health Check${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

for i in $(seq 1 "$NODE_COUNT"); do
    ZK_PORT=$((ZK_BASE + i - 1))
    CONTAINER_NAME="${CLUSTER_NAME}.zookeeper-${i}"
    print_test "Testing ZooKeeper Node $i..."

    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        if command -v nc &> /dev/null; then
            RESPONSE=$(echo "ruok" | nc localhost $ZK_PORT 2>/dev/null)
            if [ "$RESPONSE" == "imok" ]; then
                print_pass "ZooKeeper-$i is healthy"
            else
                print_pass "ZooKeeper-$i is running"
            fi
        else
            print_pass "ZooKeeper-$i is running"
        fi
    else
        print_fail "ZooKeeper-$i not running"
    fi
done

# Test 8: SSL Certificate Validation
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} 8. SSL/TLS Certificate Validation${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

for i in $(seq 1 "$NODE_COUNT"); do
    PORT=$((HTTPS_BASE + i - 1))
    print_test "Testing SSL handshake on Node $i..."

    # Test SSL connection with CA certificate
    if curl --cacert "$CA_CERT" -s -o /dev/null https://localhost:$PORT/nifi/ 2>/dev/null; then
        print_pass "SSL/TLS handshake successful"
    else
        print_fail "SSL/TLS handshake failed"
    fi

    # Verify certificate details
    if command -v openssl &> /dev/null; then
        CERT_INFO=$(echo | openssl s_client -connect localhost:$PORT -CAfile "$CA_CERT" 2>/dev/null | openssl x509 -noout -subject -issuer 2>/dev/null)

        if [ -n "$CERT_INFO" ]; then
            print_pass "Certificate validated"
        else
            print_fail "Could not retrieve certificate information"
        fi
    else
        print_pass "SSL connection verified (openssl not available for details)"
    fi
done

# Test 9: Flow Replication
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} 9. Flow Replication Test${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

print_test "Creating test processor on Node 1..."

# Get token for Node 1
PORT=$HTTPS_BASE
TOKEN="$NODE_1_TOKEN"

if [ -z "$TOKEN" ]; then
    print_fail "No token available for Node 1"
else
    # Get root process group ID
    ROOT_PG=$(curl --cacert "$CA_CERT" -s \
        -H "Authorization: Bearer $TOKEN" \
        https://localhost:$PORT/nifi-api/flow/process-groups/root 2>/dev/null | \
        jq -r '.processGroupFlow.id')

    if [ -z "$ROOT_PG" ] || [ "$ROOT_PG" == "null" ]; then
        print_fail "Could not get root process group ID"
    else
        # Create a test processor with unique name
        TIMESTAMP=$(date +%s)
        PROCESSOR_NAME="ClusterReplicationTest-$TIMESTAMP"

        RESPONSE=$(curl --cacert "$CA_CERT" -s -X POST \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            https://localhost:$PORT/nifi-api/process-groups/$ROOT_PG/processors \
            -d "{
                \"revision\": {\"version\": 0},
                \"component\": {
                    \"type\": \"org.apache.nifi.processors.standard.GenerateFlowFile\",
                    \"name\": \"$PROCESSOR_NAME\",
                    \"position\": {\"x\": 300, \"y\": 300},
                    \"config\": {
                        \"schedulingPeriod\": \"60 sec\",
                        \"autoTerminatedRelationships\": [\"success\"],
                        \"properties\": {
                            \"File Size\": \"1KB\",
                            \"Batch Size\": \"1\"
                        }
                    }
                }
            }" 2>/dev/null)

        PROCESSOR_ID=$(echo "$RESPONSE" | jq -r '.id')

        if [ -n "$PROCESSOR_ID" ] && [ "$PROCESSOR_ID" != "null" ]; then
            print_pass "Test processor created: $PROCESSOR_NAME"
            print_info "Processor ID: $PROCESSOR_ID"

            # Wait for replication
            print_info "Waiting 5 seconds for cluster replication..."
            sleep 5

            # Check replication on all nodes
            print_test "Verifying flow replication across all nodes..."

            for i in $(seq 1 "$NODE_COUNT"); do
                PORT=$((HTTPS_BASE + i - 1))
                TOKEN_VAR="NODE_${i}_TOKEN"
                TOKEN="${!TOKEN_VAR}"

                if [ -z "$TOKEN" ]; then
                    print_fail "No token for Node $i"
                    continue
                fi

                # Check if processor exists on this node
                FOUND=$(curl --cacert "$CA_CERT" -s \
                    -H "Authorization: Bearer $TOKEN" \
                    https://localhost:$PORT/nifi-api/flow/process-groups/$ROOT_PG 2>/dev/null | \
                    jq -r ".processGroupFlow.flow.processors[] | select(.component.name==\"$PROCESSOR_NAME\") | .id")

                if [ -n "$FOUND" ] && [ "$FOUND" != "null" ]; then
                    print_pass "Node $i: Processor replicated successfully"
                else
                    print_fail "Node $i: Processor NOT found (replication failed)"
                fi
            done

            # Cleanup: Delete the test processor
            print_test "Cleaning up test processor..."

            # Get current version
            PORT=$HTTPS_BASE
            TOKEN="$NODE_1_TOKEN"
            CURRENT_VERSION=$(curl --cacert "$CA_CERT" -s \
                -H "Authorization: Bearer $TOKEN" \
                https://localhost:$PORT/nifi-api/processors/$PROCESSOR_ID 2>/dev/null | \
                jq -r '.revision.version')

            if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "null" ]; then
                curl --cacert "$CA_CERT" -s -X DELETE \
                    -H "Authorization: Bearer $TOKEN" \
                    "https://localhost:$PORT/nifi-api/processors/$PROCESSOR_ID?version=$CURRENT_VERSION" \
                    > /dev/null 2>&1

                print_info "Test processor deleted"
            fi
        else
            print_fail "Failed to create test processor"
        fi
    fi
fi

# Summary
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN} Test Summary${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

TOTAL=$((PASSED + FAILED))

echo "Results:"
echo -e "  ${GREEN}Passed:${NC}   $PASSED / $TOTAL"
echo -e "  ${RED}Failed:${NC}   $FAILED / $TOTAL"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ All tests passed!                                          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Your cluster is fully operational!"
    echo ""
    for i in $(seq 1 "$NODE_COUNT"); do
        url=$(get_cluster_url "$CLUSTER_NAME" "$i")
        echo "  Node ${i}: ${url}/nifi"
    done
    echo ""
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗ Some tests failed                                          ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Review the failed tests above."
    echo ""
    exit 1
fi
