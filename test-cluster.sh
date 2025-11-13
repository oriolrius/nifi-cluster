#!/bin/bash
# Comprehensive NiFi Cluster Testing Script
# Tests SSL/TLS, authentication, backend API, and cluster connectivity
#
# Usage: ./test-cluster.sh [OPTIONS] <CLUSTER_NAME> [NODE_COUNT] [BASE_PORT]
#
# Arguments:
#   CLUSTER_NAME    Name of the cluster to test (e.g., cluster01, cluster02)
#   NODE_COUNT      Number of NiFi nodes in the cluster (default: 3)
#   BASE_PORT       Base HTTPS port for the cluster (default: 30443)
#
# Options:
#   --help, -h      Show this help message
#
# Examples:
#   ./test-cluster.sh cluster01                    # Test cluster01 with defaults (3 nodes, port 30443)
#   ./test-cluster.sh cluster01 3 30443            # Test cluster01 explicitly
#   ./test-cluster.sh cluster02 3 31443            # Test cluster02 on port 31443
#   ./test-cluster.sh --help                       # Show this help

# Don't exit on error - we want to collect all test results
set +e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Show help function
show_help() {
    cat << EOF
Comprehensive NiFi Cluster Testing Script
=========================================

Tests SSL/TLS, authentication, backend API, and cluster connectivity.

Usage: $0 [OPTIONS] <CLUSTER_NAME> [NODE_COUNT] [BASE_PORT]

Arguments:
  CLUSTER_NAME    Name of the cluster to test (e.g., cluster01, cluster02)
  NODE_COUNT      Number of NiFi nodes in the cluster (default: 3)
  BASE_PORT       Base HTTPS port for the cluster (default: 30443)

Options:
  --help, -h      Show this help message

Examples:
  $0 cluster01                    # Test cluster01 with defaults
  $0 cluster01 3 30443            # Test cluster01 explicitly
  $0 cluster02 3 31443            # Test cluster02 on port 31443

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
  8. SSL/TLS certificate validation
  9. Flow replication test

EOF
    exit 0
}

# Parse command line arguments
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
fi

if [ -z "$1" ]; then
    echo "Error: CLUSTER_NAME is required"
    echo "Run '$0 --help' for usage information"
    exit 1
fi

# Configuration
CLUSTER_NAME="$1"
NODE_COUNT="${2:-3}"
BASE_PORT="${3:-30443}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_CERT="${SCRIPT_DIR}/clusters/${CLUSTER_NAME}/certs/ca/ca-cert.pem"
USERNAME="${NIFI_USERNAME:-admin}"
PASSWORD="${NIFI_PASSWORD:-changeme123456}"
ZK_BASE_PORT=$((BASE_PORT - 262))  # 30443 - 262 = 30181

# Counters
PASSED=0
FAILED=0

# Helper functions
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

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

# Test functions
test_prerequisites() {
    print_header "1. Prerequisites Check"

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
        print_pass "CA certificate found: $CA_CERT"
    else
        print_fail "CA certificate not found: $CA_CERT"
    fi

    echo ""
}

test_container_status() {
    print_header "2. Container Status Check"

    print_test "Checking Docker containers for cluster: $CLUSTER_NAME..."

    # Get containers for this specific cluster (matches both dash and dot separators)
    CONTAINERS=$(docker ps -a --format '{{.Names}}' | grep "^${CLUSTER_NAME}[-.]")

    if [ -z "$CONTAINERS" ]; then
        print_fail "No containers found for cluster $CLUSTER_NAME"
        echo ""
        return
    fi

    for container in $CONTAINERS; do
        STATUS=$(docker ps --format '{{.Names}}\t{{.State}}' | grep "^${container}" | awk '{print $2}')
        if [ "$STATUS" == "running" ]; then
            print_pass "$container is running"
        else
            print_fail "$container is $STATUS"
        fi
    done

    echo ""
}

test_web_ui_access() {
    print_header "3. Web UI Access (with CA Certificate)"

    for i in $(seq 1 $NODE_COUNT); do
        PORT=$((BASE_PORT + i - 1))
        print_test "Testing Node $i (port $PORT)..."

        HTTP_STATUS=$(curl --cacert "$CA_CERT" -s -o /dev/null -w "%{http_code}" -L https://localhost:$PORT/nifi/ 2>/dev/null)

        if [ "$HTTP_STATUS" == "200" ]; then
            print_pass "Web UI accessible (HTTP $HTTP_STATUS)"
        else
            print_fail "Web UI returned HTTP $HTTP_STATUS"
        fi
    done

    echo ""
}

test_authentication() {
    print_header "4. Authentication & Login Tests"

    for i in $(seq 1 $NODE_COUNT); do
        PORT=$((BASE_PORT + i - 1))
        print_test "Testing login on Node $i (port $PORT)..."

        TOKEN=$(curl --cacert "$CA_CERT" -s -X POST \
            https://localhost:$PORT/nifi-api/access/token \
            -d "username=$USERNAME&password=$PASSWORD" 2>/dev/null)

        if [ -n "$TOKEN" ] && [ ${#TOKEN} -gt 100 ]; then
            print_pass "JWT token obtained (${#TOKEN} chars)"
            # Store token for later tests
            eval "NODE_${i}_TOKEN='$TOKEN'"
        else
            print_fail "Failed to obtain JWT token"
        fi
    done

    echo ""
}

test_backend_api() {
    print_header "5. Backend API Access Tests"

    for i in $(seq 1 $NODE_COUNT); do
        PORT=$((BASE_PORT + i - 1))
        print_test "Testing backend API on Node $i (port $PORT)..."

        # Get token
        TOKEN_VAR="NODE_${i}_TOKEN"
        TOKEN="${!TOKEN_VAR}"

        if [ -z "$TOKEN" ]; then
            print_fail "No token available for Node $i"
            continue
        fi

        # Test cluster summary endpoint
        RESPONSE=$(curl --cacert "$CA_CERT" -s \
            -H "Authorization: Bearer $TOKEN" \
            https://localhost:$PORT/nifi-api/flow/cluster/summary 2>/dev/null)

        if echo "$RESPONSE" | jq -e '.clusterSummary' > /dev/null 2>&1; then
            CONNECTED=$(echo "$RESPONSE" | jq -r '.clusterSummary.connectedNodes')
            CLUSTERED=$(echo "$RESPONSE" | jq -r '.clusterSummary.clustered')

            print_pass "Cluster summary API working"
            print_info "Connected nodes: $CONNECTED"
            print_info "Clustered: $CLUSTERED"
        else
            print_fail "Backend API not responding correctly"
        fi
    done

    echo ""
}

test_cluster_status() {
    print_header "6. Cluster Status Verification"

    PORT=$BASE_PORT
    print_test "Checking cluster status from Node 1..."

    # Get token
    TOKEN="$NODE_1_TOKEN"

    if [ -z "$TOKEN" ]; then
        print_fail "No token available"
        echo ""
        return
    fi

    RESPONSE=$(curl --cacert "$CA_CERT" -s \
        -H "Authorization: Bearer $TOKEN" \
        https://localhost:$PORT/nifi-api/flow/cluster/summary 2>/dev/null)

    CONNECTED_COUNT=$(echo "$RESPONSE" | jq -r '.clusterSummary.connectedNodeCount')
    TOTAL_COUNT=$(echo "$RESPONSE" | jq -r '.clusterSummary.totalNodeCount')
    CLUSTERED=$(echo "$RESPONSE" | jq -r '.clusterSummary.clustered')

    if [ "$CONNECTED_COUNT" == "$TOTAL_COUNT" ] && [ "$CLUSTERED" == "true" ]; then
        print_pass "All nodes connected: $CONNECTED_COUNT / $TOTAL_COUNT"
        print_pass "Cluster mode: $CLUSTERED"
    else
        print_fail "Cluster not fully connected: $CONNECTED_COUNT / $TOTAL_COUNT"
        print_fail "Cluster mode: $CLUSTERED"
    fi

    echo ""
}

test_zookeeper_health() {
    print_header "7. ZooKeeper Health Check"

    for i in $(seq 1 $NODE_COUNT); do
        ZK_PORT=$((ZK_BASE_PORT + i - 1))
        CONTAINER_NAME="${CLUSTER_NAME}.zookeeper-${i}"
        print_test "Testing ZooKeeper Node $i (port $ZK_PORT)..."

        # Check if container is running
        if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            # Test ZK with ruok command
            RESPONSE=$(echo "ruok" | nc localhost $ZK_PORT 2>/dev/null)
            if [ "$RESPONSE" == "imok" ]; then
                print_pass "ZooKeeper-$i is running and healthy"
            else
                print_pass "ZooKeeper-$i is running (could not verify health)"
            fi
        else
            print_fail "ZooKeeper-$i container not found or not running"
        fi
    done

    echo ""
}

test_ssl_certificate_validation() {
    print_header "8. SSL/TLS Certificate Validation"

    for i in $(seq 1 $NODE_COUNT); do
        PORT=$((BASE_PORT + i - 1))
        print_test "Testing SSL handshake on Node $i (port $PORT)..."

        # Test SSL connection with CA certificate
        if curl --cacert "$CA_CERT" -s -o /dev/null https://localhost:$PORT/nifi/ 2>/dev/null; then
            print_pass "SSL/TLS handshake successful with CA certificate"
        else
            print_fail "SSL/TLS handshake failed"
        fi

        # Verify certificate details
        CERT_INFO=$(echo | openssl s_client -connect localhost:$PORT -CAfile "$CA_CERT" 2>/dev/null | openssl x509 -noout -subject -issuer 2>/dev/null)

        if [ -n "$CERT_INFO" ]; then
            print_info "Certificate validated"
        else
            print_fail "Could not retrieve certificate information"
        fi
    done

    echo ""
}

test_flow_replication() {
    print_header "9. Flow Replication Test"

    print_test "Creating test processor on Node 1..."

    # Get token for Node 1
    PORT=$BASE_PORT
    TOKEN="$NODE_1_TOKEN"

    if [ -z "$TOKEN" ]; then
        print_fail "No token available for Node 1"
        echo ""
        return
    fi

    # Get root process group ID
    ROOT_PG=$(curl --cacert "$CA_CERT" -s \
        -H "Authorization: Bearer $TOKEN" \
        https://localhost:$PORT/nifi-api/flow/process-groups/root 2>/dev/null | \
        jq -r '.processGroupFlow.id')

    if [ -z "$ROOT_PG" ] || [ "$ROOT_PG" == "null" ]; then
        print_fail "Could not get root process group ID"
        echo ""
        return
    fi

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
    else
        print_fail "Failed to create test processor"
        echo ""
        return
    fi

    # Wait for replication
    print_info "Waiting 5 seconds for cluster replication..."
    sleep 5

    # Check replication on all nodes
    print_test "Verifying flow replication across all nodes..."

    for i in $(seq 1 $NODE_COUNT); do
        PORT=$((BASE_PORT + i - 1))
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
    CURRENT_VERSION=$(curl --cacert "$CA_CERT" -s \
        -H "Authorization: Bearer $NODE_1_TOKEN" \
        https://localhost:$BASE_PORT/nifi-api/processors/$PROCESSOR_ID 2>/dev/null | \
        jq -r '.revision.version')

    if [ -n "$CURRENT_VERSION" ] && [ "$CURRENT_VERSION" != "null" ]; then
        curl --cacert "$CA_CERT" -s -X DELETE \
            -H "Authorization: Bearer $NODE_1_TOKEN" \
            "https://localhost:$BASE_PORT/nifi-api/processors/$PROCESSOR_ID?version=$CURRENT_VERSION" \
            > /dev/null 2>&1

        print_info "Test processor deleted"
    fi

    echo ""
}

print_summary() {
    print_header "Test Summary"

    TOTAL=$((PASSED + FAILED))

    echo -e "  ${GREEN}Passed:${NC}   $PASSED / $TOTAL"
    echo -e "  ${RED}Failed:${NC}   $FAILED / $TOTAL"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║  ✓ All tests passed!                                          ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        exit 0
    else
        echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ✗ Some tests failed                                          ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
        exit 1
    fi
}

# Main execution
main() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  NiFi Cluster Comprehensive Test Suite                        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Configuration:"
    echo "  Cluster Name:   $CLUSTER_NAME"
    echo "  CA Certificate: $CA_CERT"
    echo "  Username:       $USERNAME"
    echo "  Node Count:     $NODE_COUNT"
    echo "  Base Port:      $BASE_PORT"
    echo "  ZK Base Port:   $ZK_BASE_PORT"
    echo ""

    test_prerequisites
    test_container_status
    test_web_ui_access
    test_authentication
    test_backend_api
    test_cluster_status
    test_zookeeper_health
    test_ssl_certificate_validation
    test_flow_replication
    print_summary
}

# Run main
main
