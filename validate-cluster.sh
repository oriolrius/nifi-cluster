#!/bin/bash
# Cluster validation script for NiFi cluster configuration
# Usage: ./validate-cluster.sh [NODE_COUNT]
#
# Validates:
# - Directory structure
# - Certificate chain
# - Configuration files
# - Node addresses in nifi.properties
# - docker-compose.yml syntax
# - Port conflicts

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Function to print check header
print_check() {
    echo -n "  [$1] $2... "
}

# Function to print pass
print_pass() {
    echo -e "${GREEN}✓ PASS${NC}"
    ((PASSED++))
}

# Function to print fail
print_fail() {
    echo -e "${RED}✗ FAIL${NC}"
    if [ -n "$1" ]; then
        echo -e "      ${RED}└─${NC} $1"
    fi
    ((FAILED++))
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ WARNING${NC}"
    if [ -n "$1" ]; then
        echo -e "      ${YELLOW}└─${NC} $1"
    fi
    ((WARNINGS++))
}

# Function to print section header
print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Detect node count
if [ -n "$1" ]; then
    NODE_COUNT="$1"
else
    # Try to detect from docker-compose.yml
    if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        NODE_COUNT=$(grep -c "container_name:.*nifi-" "$SCRIPT_DIR/docker-compose.yml" || echo "3")
    else
        NODE_COUNT=3
    fi
fi

print_header "NiFi Cluster Configuration Validator"

echo "Validation Configuration:"
echo "  Node Count:    $NODE_COUNT"
echo "  Working Dir:   $SCRIPT_DIR"
echo ""

# 1. Directory Structure Validation
print_header "1. Directory Structure Validation"

# Check main directories
for dir in certs conf volumes; do
    print_check "DIR" "Checking $dir/ directory"
    if [ -d "$SCRIPT_DIR/$dir" ]; then
        print_pass
    else
        print_fail "Directory $dir/ not found"
    fi
done

# Check ZooKeeper volume directories
for i in $(seq 1 "$NODE_COUNT"); do
    print_check "ZK$i" "Checking ZooKeeper-$i volumes"
    if [ -d "$SCRIPT_DIR/volumes/zookeeper-$i/data" ] && \
       [ -d "$SCRIPT_DIR/volumes/zookeeper-$i/datalog" ] && \
       [ -d "$SCRIPT_DIR/volumes/zookeeper-$i/logs" ]; then
        print_pass
    else
        print_fail "ZooKeeper-$i volume directories incomplete"
    fi
done

# Check NiFi volume directories
for i in $(seq 1 "$NODE_COUNT"); do
    print_check "NFI$i" "Checking NiFi-$i volumes"
    if [ -d "$SCRIPT_DIR/volumes/nifi-$i/content_repository" ] && \
       [ -d "$SCRIPT_DIR/volumes/nifi-$i/database_repository" ] && \
       [ -d "$SCRIPT_DIR/volumes/nifi-$i/flowfile_repository" ] && \
       [ -d "$SCRIPT_DIR/volumes/nifi-$i/provenance_repository" ] && \
       [ -d "$SCRIPT_DIR/volumes/nifi-$i/state" ] && \
       [ -d "$SCRIPT_DIR/volumes/nifi-$i/logs" ]; then
        print_pass
    else
        print_fail "NiFi-$i volume directories incomplete"
    fi
done

# 2. Certificate Validation
print_header "2. Certificate Validation"

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    print_check "SSL" "OpenSSL availability"
    print_warning "OpenSSL not found - skipping certificate validation"
else
    # Check CA certificate
    print_check "CA" "Checking CA certificate"
    if [ -f "$SCRIPT_DIR/certs/ca/ca-cert.pem" ]; then
        if openssl x509 -in "$SCRIPT_DIR/certs/ca/ca-cert.pem" -noout -text &>/dev/null; then
            print_pass
        else
            print_fail "CA certificate is invalid"
        fi
    else
        print_fail "CA certificate not found"
    fi

    # Check node certificates
    for i in $(seq 1 "$NODE_COUNT"); do
        print_check "CRT$i" "Checking NiFi-$i certificates"

        if [ -f "$SCRIPT_DIR/conf/nifi-$i/keystore.p12" ] && \
           [ -f "$SCRIPT_DIR/conf/nifi-$i/truststore.p12" ]; then
            # Verify keystore is readable (basic check)
            if openssl pkcs12 -in "$SCRIPT_DIR/conf/nifi-$i/keystore.p12" -nokeys -passin pass:changeme123456 &>/dev/null; then
                print_pass
            else
                print_fail "Keystore for nifi-$i is invalid or password incorrect"
            fi
        else
            print_fail "Certificates missing for nifi-$i"
        fi
    done
fi

# 3. Configuration Files Validation
print_header "3. Configuration Files Validation"

# Check NiFi configuration files
for i in $(seq 1 "$NODE_COUNT"); do
    print_check "CFG$i" "Checking NiFi-$i config files"

    if [ -f "$SCRIPT_DIR/conf/nifi-$i/nifi.properties" ] && \
       [ -f "$SCRIPT_DIR/conf/nifi-$i/state-management.xml" ] && \
       [ -f "$SCRIPT_DIR/conf/nifi-$i/authorizers.xml" ] && \
       [ -f "$SCRIPT_DIR/conf/nifi-$i/bootstrap.conf" ]; then
        print_pass
    else
        print_fail "Configuration files incomplete for nifi-$i"
    fi
done

# 4. Node Address Validation
print_header "4. Node Address Validation"

for i in $(seq 1 "$NODE_COUNT"); do
    print_check "ADR$i" "Checking NiFi-$i node address"

    if [ -f "$SCRIPT_DIR/conf/nifi-$i/nifi.properties" ]; then
        NODE_ADDR=$(grep "^nifi.cluster.node.address=" "$SCRIPT_DIR/conf/nifi-$i/nifi.properties" | cut -d'=' -f2 | tr -d ' ')
        EXPECTED_ADDR="nifi-$i"

        if [ "$NODE_ADDR" == "$EXPECTED_ADDR" ]; then
            print_pass
        else
            print_fail "Expected '$EXPECTED_ADDR' but found '$NODE_ADDR'"
        fi
    else
        print_fail "nifi.properties not found"
    fi
done

# Check remote input host
for i in $(seq 1 "$NODE_COUNT"); do
    print_check "RMT$i" "Checking NiFi-$i remote input host"

    if [ -f "$SCRIPT_DIR/conf/nifi-$i/nifi.properties" ]; then
        REMOTE_HOST=$(grep "^nifi.remote.input.host=" "$SCRIPT_DIR/conf/nifi-$i/nifi.properties" | cut -d'=' -f2 | tr -d ' ')
        EXPECTED_HOST="nifi-$i"

        if [ "$REMOTE_HOST" == "$EXPECTED_HOST" ]; then
            print_pass
        else
            print_fail "Expected '$EXPECTED_HOST' but found '$REMOTE_HOST'"
        fi
    else
        print_fail "nifi.properties not found"
    fi
done

# 5. ZooKeeper Configuration Validation
print_header "5. ZooKeeper Configuration Validation"

# Build expected ZK connect string
EXPECTED_ZK=""
for i in $(seq 1 "$NODE_COUNT"); do
    if [ $i -eq 1 ]; then
        EXPECTED_ZK="zookeeper-${i}:2181"
    else
        EXPECTED_ZK="${EXPECTED_ZK},zookeeper-${i}:2181"
    fi
done

for i in $(seq 1 "$NODE_COUNT"); do
    print_check "ZKC$i" "Checking NiFi-$i ZooKeeper connect string"

    if [ -f "$SCRIPT_DIR/conf/nifi-$i/nifi.properties" ]; then
        ZK_CONNECT=$(grep "^nifi.zookeeper.connect.string=" "$SCRIPT_DIR/conf/nifi-$i/nifi.properties" | cut -d'=' -f2 | tr -d ' ')

        if [ "$ZK_CONNECT" == "$EXPECTED_ZK" ]; then
            print_pass
        else
            print_fail "Expected '$EXPECTED_ZK' but found '$ZK_CONNECT'"
        fi
    else
        print_fail "nifi.properties not found"
    fi
done

# 6. Docker Compose Validation
print_header "6. Docker Compose Validation"

print_check "YML" "Checking docker-compose.yml exists"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    print_pass
else
    print_fail "docker-compose.yml not found"
fi

print_check "SYN" "Validating docker-compose.yml syntax"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    if docker compose -f "$SCRIPT_DIR/docker-compose.yml" config --quiet 2>&1; then
        print_pass
    else
        print_fail "docker-compose.yml has syntax errors"
    fi
else
    print_fail "docker-compose.yml not found"
fi

# Check service count
print_check "SVC" "Checking service count in docker-compose.yml"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    ZK_SERVICES=$(grep -c "zookeeper-" "$SCRIPT_DIR/docker-compose.yml" | grep "container_name" || echo "0")
    NIFI_SERVICES=$(grep -c "container_name:.*nifi-" "$SCRIPT_DIR/docker-compose.yml" || echo "0")

    if [ "$NIFI_SERVICES" -eq "$NODE_COUNT" ]; then
        print_pass
    else
        print_fail "Expected $NODE_COUNT NiFi services, found $NIFI_SERVICES"
    fi
fi

# 7. Port Conflict Check
print_header "7. Port Conflict Check"

if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    # Extract all port mappings
    PORTS=$(grep -E '^\s+- "[0-9]+:[0-9]+"' "$SCRIPT_DIR/docker-compose.yml" | sed 's/.*"\([0-9]*\):.*/\1/' | sort)

    print_check "DUP" "Checking for duplicate port mappings"
    DUPLICATES=$(echo "$PORTS" | uniq -d)
    if [ -z "$DUPLICATES" ]; then
        print_pass
    else
        print_fail "Duplicate ports found: $(echo $DUPLICATES | tr '\n' ' ')"
    fi

    # Check if ports are in use (only if not running in container)
    if [ ! -f "/.dockerenv" ]; then
        print_check "USE" "Checking if ports are available"
        PORTS_IN_USE=""

        for PORT in $PORTS; do
            if command -v lsof &> /dev/null; then
                if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
                    PORTS_IN_USE="$PORTS_IN_USE $PORT"
                fi
            elif command -v ss &> /dev/null; then
                if ss -tlnH | grep -q ":$PORT "; then
                    PORTS_IN_USE="$PORTS_IN_USE $PORT"
                fi
            elif command -v netstat &> /dev/null; then
                if netstat -tln | grep -q ":$PORT "; then
                    PORTS_IN_USE="$PORTS_IN_USE $PORT"
                fi
            fi
        done

        if [ -z "$PORTS_IN_USE" ]; then
            print_pass
        else
            print_warning "Ports already in use:$PORTS_IN_USE (may conflict if not from this cluster)"
        fi
    else
        print_warning "Running in container - skipping port availability check"
    fi
fi

# Summary
print_header "Validation Summary"

TOTAL=$((PASSED + FAILED + WARNINGS))

echo "Results:"
echo -e "  ${GREEN}Passed:${NC}   $PASSED / $TOTAL"
echo -e "  ${RED}Failed:${NC}   $FAILED / $TOTAL"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS / $TOTAL"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ All validations passed!                                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}Note: There are $WARNINGS warning(s) - review them above${NC}"
        echo ""
    fi

    echo "Your cluster configuration is valid and ready to deploy."
    echo ""
    echo "Next steps:"
    echo "  1. Start the cluster: docker compose up -d"
    echo "  2. Monitor startup: docker compose logs -f"
    echo "  3. Wait 2-3 minutes for cluster initialization"
    echo ""
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗ Validation failed - please fix the errors above            ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Please review and fix the failed checks before deploying the cluster."
    echo ""
    exit 1
fi
