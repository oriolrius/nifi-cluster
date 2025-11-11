#!/bin/bash
# Comprehensive NiFi Cluster Testing Script
# Tests SSL/TLS, authentication, backend API, and cluster connectivity

# Don't exit on error - we want to collect all test results
set +e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CA_CERT="${SCRIPT_DIR}/certs/ca/ca-cert.pem"
USERNAME="${NIFI_USERNAME:-admin}"
PASSWORD="${NIFI_PASSWORD:-changeme123456}"
NODE_COUNT=3
BASE_PORT=30443

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

    print_test "Checking Docker Compose services..."

    if docker compose ps --format json > /dev/null 2>&1; then
        CONTAINERS=$(docker compose ps --format json | jq -r '.Name')

        for container in $CONTAINERS; do
            STATUS=$(docker compose ps --format json | jq -r "select(.Name==\"$container\") | .State")
            if [ "$STATUS" == "running" ]; then
                print_pass "$container is running"
            else
                print_fail "$container is $STATUS"
            fi
        done
    else
        print_fail "Could not query docker compose services"
    fi

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
        ZK_PORT=$((30180 + i))
        print_test "Testing ZooKeeper Node $i (port $ZK_PORT)..."

        if docker compose ps zookeeper-$i --format json 2>/dev/null | jq -e 'select(.State=="running")' > /dev/null 2>&1; then
            print_pass "ZooKeeper-$i is running"
        else
            print_fail "ZooKeeper-$i is not running"
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
    echo "  CA Certificate: $CA_CERT"
    echo "  Username:       $USERNAME"
    echo "  Node Count:     $NODE_COUNT"
    echo "  Base Port:      $BASE_PORT"
    echo ""

    test_prerequisites
    test_container_status
    test_web_ui_access
    test_authentication
    test_backend_api
    test_cluster_status
    test_zookeeper_health
    test_ssl_certificate_validation
    print_summary
}

# Run main
main
