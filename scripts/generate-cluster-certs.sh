#!/bin/bash
# Multi-Cluster NiFi - Cluster Certificate Generation Script
#
# This script generates certificates for all nodes in a specific cluster
# using the shared Certificate Authority (CA).
#
# Usage: ./generate-cluster-certs.sh <cluster-name> [node-count]
#   cluster-name: Name of the cluster (e.g., cluster01, cluster02)
#   node-count:   Number of nodes (default: 3)

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to display usage
usage() {
    echo "Usage: $0 <cluster-name> [node-count]"
    echo ""
    echo "Arguments:"
    echo "  cluster-name   Name of the cluster (e.g., cluster01, cluster02)"
    echo "  node-count     Number of nodes (default: 3)"
    echo ""
    echo "Example:"
    echo "  $0 cluster01        # Creates 3-node cluster (default)"
    echo "  $0 cluster02 5      # Creates 5-node cluster"
    echo ""
    exit 1
}

# Determine script and project root directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
if [ $# -lt 1 ]; then
    log_error "Missing required argument: cluster-name"
    echo ""
    usage
fi

CLUSTER_NAME="$1"
NODE_COUNT="${2:-3}"  # Default to 3 nodes

# Validate cluster name format (cluster01, cluster02, etc.)
if ! [[ "$CLUSTER_NAME" =~ ^cluster[0-9]{2}$ ]]; then
    log_error "Invalid cluster name format: $CLUSTER_NAME"
    log_error "Cluster name must be in format: clusterNN (e.g., cluster01, cluster02)"
    exit 1
fi

# Validate node count
if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -lt 1 ] || [ "$NODE_COUNT" -gt 9 ]; then
    log_error "Invalid node count: $NODE_COUNT"
    log_error "Node count must be a number between 1 and 9"
    exit 1
fi

# Directories
CA_DIR="$PROJECT_ROOT/shared/certs/ca"
CLUSTER_CERTS_DIR="$PROJECT_ROOT/clusters/$CLUSTER_NAME/certs"

# CA files
CA_KEY="$CA_DIR/ca-key.pem"
CA_CERT="$CA_DIR/ca-cert.pem"
TRUSTSTORE_P12="$CA_DIR/truststore.p12"

# Configuration
VALIDITY_DAYS=3650  # 10 years
KEY_SIZE=2048
DEFAULT_PASSWORD="changeme123456"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate CA
validate_ca() {
    if [ ! -f "$CA_KEY" ] || [ ! -f "$CA_CERT" ]; then
        log_error "Shared CA not found!"
        log_error "Expected CA files:"
        echo "  - $CA_KEY"
        echo "  - $CA_CERT"
        echo ""
        log_error "Please run ./scripts/generate-ca.sh first to create the shared CA"
        return 1
    fi

    if ! openssl x509 -in "$CA_CERT" -noout -text >/dev/null 2>&1; then
        log_error "CA certificate is invalid: $CA_CERT"
        return 1
    fi

    return 0
}

# Function to generate node certificate
generate_node_cert() {
    local NODE_NAME="$1"
    local NODE_TYPE="$2"  # "NiFi" or "ZooKeeper"
    local NODE_DIR="$CLUSTER_CERTS_DIR/$NODE_NAME"

    log_info "Generating certificate for $NODE_NAME..."

    # Create node directory
    mkdir -p "$NODE_DIR"

    # Certificate subject
    local SUBJECT="/C=US/ST=California/L=San Francisco/O=Multi-Cluster NiFi/OU=$NODE_TYPE Nodes/CN=$NODE_NAME"

    # Generate private key
    openssl genrsa -out "$NODE_DIR/server-key.pem" $KEY_SIZE 2>/dev/null

    # Generate certificate signing request
    openssl req -new \
        -key "$NODE_DIR/server-key.pem" \
        -out "$NODE_DIR/server.csr" \
        -subj "$SUBJECT" 2>/dev/null

    # Create SAN configuration for this node
    cat > "$NODE_DIR/san.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = Multi-Cluster NiFi
OU = $NODE_TYPE Nodes
CN = $NODE_NAME

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $NODE_NAME
DNS.2 = ${NODE_NAME}.${CLUSTER_NAME}-nifi-net
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

    # Sign certificate with CA
    openssl x509 -req -days $VALIDITY_DAYS \
        -in "$NODE_DIR/server.csr" \
        -CA "$CA_CERT" \
        -CAkey "$CA_KEY" \
        -CAcreateserial \
        -out "$NODE_DIR/server-cert.pem" \
        -extensions v3_req \
        -extfile "$NODE_DIR/san.cnf" 2>/dev/null

    # Create PKCS12 keystore
    openssl pkcs12 -export \
        -in "$NODE_DIR/server-cert.pem" \
        -inkey "$NODE_DIR/server-key.pem" \
        -out "$NODE_DIR/keystore.p12" \
        -name "$NODE_NAME" \
        -CAfile "$CA_CERT" \
        -caname root \
        -password "pass:$KEYSTORE_PASS" 2>/dev/null

    # Copy truststore from shared CA
    if [ -f "$TRUSTSTORE_P12" ]; then
        cp "$TRUSTSTORE_P12" "$NODE_DIR/truststore.p12"
    else
        log_warning "PKCS12 truststore not found, skipping copy"
    fi

    # Set permissions
    chmod 600 "$NODE_DIR/server-key.pem"  # Private key - owner only
    chmod 644 "$NODE_DIR/server-cert.pem" "$NODE_DIR/keystore.p12" "$NODE_DIR/truststore.p12" 2>/dev/null || true

    # Clean up temporary files
    rm -f "$NODE_DIR/server.csr" "$NODE_DIR/san.cnf"

    log_success "Certificate generated: $NODE_NAME"
}

# Function to validate certificate
validate_certificate() {
    local CERT_FILE="$1"
    local NODE_NAME="$2"

    # Verify certificate against CA
    if openssl verify -CAfile "$CA_CERT" "$CERT_FILE" >/dev/null 2>&1; then
        log_success "Certificate validation passed: $NODE_NAME"
        return 0
    else
        log_error "Certificate validation failed: $NODE_NAME"
        return 1
    fi
}

# Main script
echo ""
echo "=================================================="
echo "Multi-Cluster NiFi - Certificate Generation"
echo "=================================================="
echo ""

log_info "Cluster: $CLUSTER_NAME"
log_info "Node count: $NODE_COUNT"
log_info "Project root: $PROJECT_ROOT"
log_info "Certificate directory: $CLUSTER_CERTS_DIR"
echo ""

# Check required commands
log_info "Checking required commands..."
MISSING_COMMANDS=()

if ! command_exists openssl; then
    MISSING_COMMANDS+=("openssl")
fi

if [ ${#MISSING_COMMANDS[@]} -gt 0 ]; then
    log_error "Missing required commands:"
    for cmd in "${MISSING_COMMANDS[@]}"; do
        echo "  - $cmd"
    done
    echo ""
    log_error "Please install missing dependencies and try again"
    exit 1
fi

log_success "All required commands found"
echo ""

# Validate shared CA
log_info "Validating shared CA..."
if ! validate_ca; then
    exit 1
fi
log_success "Shared CA is valid"
echo ""

# Check if certificates already exist
if [ -d "$CLUSTER_CERTS_DIR" ] && [ "$(ls -A "$CLUSTER_CERTS_DIR" 2>/dev/null)" ]; then
    log_warning "Certificates already exist for cluster: $CLUSTER_NAME"
    echo ""
    read -p "Do you want to regenerate certificates? This will overwrite existing files. (yes/no): " -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Certificate generation cancelled by user"
        exit 0
    fi

    log_warning "Removing existing certificates..."
    rm -rf "$CLUSTER_CERTS_DIR"
    log_success "Existing certificates removed"
    echo ""
fi

# Create cluster certificate directory
log_info "Creating certificate directory..."
mkdir -p "$CLUSTER_CERTS_DIR"
log_success "Certificate directory created"
echo ""

# Get keystore password
echo "Keystore password configuration"
echo ""
echo "The keystore password will be used for all node keystores."
echo "Default password: $DEFAULT_PASSWORD"
echo ""
read -p "Use default password? (yes/no): " -r
echo ""

if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    KEYSTORE_PASS="$DEFAULT_PASSWORD"
    log_info "Using default password"
else
    read -sp "Enter keystore password: " KEYSTORE_PASS
    echo ""
    read -sp "Confirm keystore password: " KEYSTORE_PASS_CONFIRM
    echo ""

    if [ "$KEYSTORE_PASS" != "$KEYSTORE_PASS_CONFIRM" ]; then
        log_error "Passwords do not match!"
        exit 1
    fi

    if [ -z "$KEYSTORE_PASS" ]; then
        log_error "Password cannot be empty!"
        exit 1
    fi

    log_success "Password set"
fi

echo ""
log_info "Starting certificate generation..."
echo ""

# Generate NiFi node certificates
log_info "Step 1/2: Generating NiFi node certificates..."
echo ""

for i in $(seq 1 $NODE_COUNT); do
    NODE_NAME="${CLUSTER_NAME}-nifi$(printf "%02d" $i)"
    generate_node_cert "$NODE_NAME" "NiFi"
done

echo ""
log_success "All NiFi node certificates generated"
echo ""

# Generate ZooKeeper node certificates
log_info "Step 2/2: Generating ZooKeeper node certificates..."
echo ""

for i in $(seq 1 $NODE_COUNT); do
    NODE_NAME="${CLUSTER_NAME}-zk$(printf "%02d" $i)"
    generate_node_cert "$NODE_NAME" "ZooKeeper"
done

echo ""
log_success "All ZooKeeper node certificates generated"
echo ""

# Validate all certificates
log_info "Validating generated certificates..."
echo ""

VALIDATION_FAILED=0

for i in $(seq 1 $NODE_COUNT); do
    # Validate NiFi certificate
    NIFI_NODE="${CLUSTER_NAME}-nifi$(printf "%02d" $i)"
    NIFI_CERT="$CLUSTER_CERTS_DIR/$NIFI_NODE/server-cert.pem"
    if ! validate_certificate "$NIFI_CERT" "$NIFI_NODE"; then
        VALIDATION_FAILED=1
    fi

    # Validate ZooKeeper certificate
    ZK_NODE="${CLUSTER_NAME}-zk$(printf "%02d" $i)"
    ZK_CERT="$CLUSTER_CERTS_DIR/$ZK_NODE/server-cert.pem"
    if ! validate_certificate "$ZK_CERT" "$ZK_NODE"; then
        VALIDATION_FAILED=1
    fi
done

echo ""

if [ $VALIDATION_FAILED -eq 1 ]; then
    log_error "Some certificates failed validation!"
    exit 1
fi

log_success "All certificates validated successfully"
echo ""

# Display completion summary
echo "=================================================="
echo "Certificate Generation Complete!"
echo "=================================================="
echo ""

echo "Cluster: $CLUSTER_NAME"
echo "Nodes: $NODE_COUNT"
echo ""

echo "Generated Certificates:"
echo ""
echo "NiFi Nodes:"
for i in $(seq 1 $NODE_COUNT); do
    NODE_NAME="${CLUSTER_NAME}-nifi$(printf "%02d" $i)"
    echo "  - $NODE_NAME"
    echo "    Keystore:   $CLUSTER_CERTS_DIR/$NODE_NAME/keystore.p12"
    echo "    Truststore: $CLUSTER_CERTS_DIR/$NODE_NAME/truststore.p12"
done

echo ""
echo "ZooKeeper Nodes:"
for i in $(seq 1 $NODE_COUNT); do
    NODE_NAME="${CLUSTER_NAME}-zk$(printf "%02d" $i)"
    echo "  - $NODE_NAME"
    echo "    Keystore:   $CLUSTER_CERTS_DIR/$NODE_NAME/keystore.p12"
    echo "    Truststore: $CLUSTER_CERTS_DIR/$NODE_NAME/truststore.p12"
done

echo ""
echo "Configuration:"
echo "  - Keystore password: $KEYSTORE_PASS"
echo "  - Truststore password: $KEYSTORE_PASS"
echo "  - Certificate validity: $VALIDITY_DAYS days (10 years)"
echo ""

echo "SAN Entries per certificate:"
echo "  - DNS: <node-name>"
echo "  - DNS: <node-name>.$CLUSTER_NAME-nifi-net"
echo "  - DNS: localhost"
echo "  - IP: 127.0.0.1"
echo ""

echo "Next Steps:"
echo "  1. Generate cluster configuration: ./scripts/generate-cluster-configs.sh $CLUSTER_NAME"
echo "  2. Initialize cluster volumes: ./scripts/init-cluster-volumes.sh $CLUSTER_NAME"
echo "  3. Generate docker-compose.yml: ./scripts/generate-docker-compose.sh $CLUSTER_NAME"
echo ""

log_success "Certificates are ready for $CLUSTER_NAME deployment!"
echo ""
