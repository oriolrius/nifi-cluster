#!/bin/bash
# Multi-Cluster NiFi - Shared CA Generation Script
#
# This script generates a shared Certificate Authority (CA) that will be used
# by all NiFi clusters. It creates the CA key, certificate, and truststores.
#
# The CA is stored in shared/certs/ca/ and is reused across all clusters.

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

# Determine script and project root directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CA_DIR="$PROJECT_ROOT/shared/certs/ca"

# Configuration
CA_SUBJECT="/C=US/ST=California/L=San Francisco/O=Multi-Cluster NiFi/OU=Certificate Authority/CN=NiFi Multi-Cluster Root CA"
VALIDITY_DAYS=3650  # 10 years
KEY_SIZE=2048
DEFAULT_PASSWORD="changeme123456"

# Files
CA_KEY="$CA_DIR/ca-key.pem"
CA_CERT="$CA_DIR/ca-cert.pem"
TRUSTSTORE_JKS="$CA_DIR/truststore.jks"
TRUSTSTORE_P12="$CA_DIR/truststore.p12"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate existing CA
validate_ca() {
    log_info "Validating existing CA..."

    # Check if CA key exists and is readable
    if [ ! -f "$CA_KEY" ]; then
        log_error "CA private key not found: $CA_KEY"
        return 1
    fi

    if [ ! -r "$CA_KEY" ]; then
        log_error "CA private key is not readable: $CA_KEY"
        return 1
    fi

    # Check if CA certificate exists and is readable
    if [ ! -f "$CA_CERT" ]; then
        log_error "CA certificate not found: $CA_CERT"
        return 1
    fi

    if [ ! -r "$CA_CERT" ]; then
        log_error "CA certificate is not readable: $CA_CERT"
        return 1
    fi

    # Validate certificate format
    if ! openssl x509 -in "$CA_CERT" -noout -text >/dev/null 2>&1; then
        log_error "CA certificate is invalid or corrupted: $CA_CERT"
        return 1
    fi

    # Check certificate validity period
    if ! openssl x509 -in "$CA_CERT" -noout -checkend 0 >/dev/null 2>&1; then
        log_warning "CA certificate has expired!"
        return 1
    fi

    # Verify key and certificate match
    KEY_MODULUS=$(openssl rsa -in "$CA_KEY" -noout -modulus 2>/dev/null | openssl md5)
    CERT_MODULUS=$(openssl x509 -in "$CA_CERT" -noout -modulus 2>/dev/null | openssl md5)

    if [ "$KEY_MODULUS" != "$CERT_MODULUS" ]; then
        log_error "CA private key and certificate do not match!"
        return 1
    fi

    log_success "CA validation passed"
    return 0
}

# Function to display CA information
display_ca_info() {
    echo ""
    echo "=================================================="
    echo "Certificate Authority Information"
    echo "=================================================="
    echo ""
    openssl x509 -in "$CA_CERT" -noout -text | grep -E "(Subject:|Issuer:|Not Before|Not After)"
    echo ""
}

# Main script
echo ""
echo "=================================================="
echo "Multi-Cluster NiFi - Shared CA Generation"
echo "=================================================="
echo ""

log_info "Project root: $PROJECT_ROOT"
log_info "CA directory: $CA_DIR"
echo ""

# Check required commands
log_info "Checking required commands..."
MISSING_COMMANDS=()

if ! command_exists openssl; then
    MISSING_COMMANDS+=("openssl")
fi

if ! command_exists keytool; then
    MISSING_COMMANDS+=("keytool (Java JDK)")
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

# Create CA directory if it doesn't exist
if [ ! -d "$CA_DIR" ]; then
    log_info "Creating CA directory: $CA_DIR"
    mkdir -p "$CA_DIR"
    log_success "CA directory created"
else
    log_info "CA directory already exists: $CA_DIR"
fi
echo ""

# Check if CA already exists
if [ -f "$CA_KEY" ] && [ -f "$CA_CERT" ]; then
    log_warning "Certificate Authority already exists!"
    echo ""

    # Validate existing CA
    if validate_ca; then
        display_ca_info

        echo ""
        log_info "The existing CA is valid and will be preserved."
        log_info "To regenerate the CA, delete the following files first:"
        echo "  - $CA_KEY"
        echo "  - $CA_CERT"
        echo "  - $TRUSTSTORE_JKS (if exists)"
        echo "  - $TRUSTSTORE_P12 (if exists)"
        echo ""
        log_warning "WARNING: Regenerating the CA will invalidate all cluster certificates!"
        echo ""
        exit 0
    else
        log_error "Existing CA is invalid or corrupted!"
        echo ""
        read -p "Do you want to regenerate the CA? This will require regenerating all cluster certificates. (yes/no): " -r
        echo ""

        if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            log_info "CA generation cancelled by user"
            exit 0
        fi

        log_warning "Removing invalid CA files..."
        rm -f "$CA_KEY" "$CA_CERT" "$TRUSTSTORE_JKS" "$TRUSTSTORE_P12"
        log_success "Invalid CA files removed"
        echo ""
    fi
fi

# Get password from user or use default
echo ""
log_info "Truststore password configuration"
echo ""
echo "The truststore password will be used for JKS and PKCS12 truststores."
echo "Default password: $DEFAULT_PASSWORD"
echo ""
read -p "Use default password? (yes/no): " -r
echo ""

if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    TRUSTSTORE_PASS="$DEFAULT_PASSWORD"
    log_info "Using default password"
else
    read -sp "Enter truststore password: " TRUSTSTORE_PASS
    echo ""
    read -sp "Confirm truststore password: " TRUSTSTORE_PASS_CONFIRM
    echo ""

    if [ "$TRUSTSTORE_PASS" != "$TRUSTSTORE_PASS_CONFIRM" ]; then
        log_error "Passwords do not match!"
        exit 1
    fi

    if [ -z "$TRUSTSTORE_PASS" ]; then
        log_error "Password cannot be empty!"
        exit 1
    fi

    log_success "Password set"
fi

echo ""
log_info "Starting CA generation..."
echo ""

# Step 1: Generate CA private key
log_info "Step 1/4: Generating CA private key (${KEY_SIZE}-bit RSA)..."
if openssl genrsa -out "$CA_KEY" $KEY_SIZE >/dev/null 2>&1; then
    chmod 600 "$CA_KEY"  # Secure the private key
    log_success "CA private key generated: $CA_KEY"
else
    log_error "Failed to generate CA private key"
    exit 1
fi

# Step 2: Generate CA certificate
log_info "Step 2/4: Generating CA certificate (${VALIDITY_DAYS}-day validity)..."
if openssl req -new -x509 -days $VALIDITY_DAYS \
    -key "$CA_KEY" \
    -out "$CA_CERT" \
    -subj "$CA_SUBJECT" >/dev/null 2>&1; then
    chmod 644 "$CA_CERT"
    log_success "CA certificate generated: $CA_CERT"
else
    log_error "Failed to generate CA certificate"
    rm -f "$CA_KEY"  # Clean up private key
    exit 1
fi

# Step 3: Create JKS truststore
log_info "Step 3/4: Creating JKS truststore..."
if keytool -import -noprompt \
    -alias ca-cert \
    -file "$CA_CERT" \
    -keystore "$TRUSTSTORE_JKS" \
    -storepass "$TRUSTSTORE_PASS" >/dev/null 2>&1; then
    chmod 644 "$TRUSTSTORE_JKS"
    log_success "JKS truststore created: $TRUSTSTORE_JKS"
else
    log_error "Failed to create JKS truststore"
    rm -f "$CA_KEY" "$CA_CERT"  # Clean up
    exit 1
fi

# Step 4: Create PKCS12 truststore
log_info "Step 4/4: Creating PKCS12 truststore..."
# Create a temporary PKCS12 file with the CA cert
TEMP_P12="$CA_DIR/.temp_ca.p12"
if openssl pkcs12 -export \
    -in "$CA_CERT" \
    -nokeys \
    -out "$TEMP_P12" \
    -name ca-cert \
    -password "pass:$TRUSTSTORE_PASS" >/dev/null 2>&1; then
    mv "$TEMP_P12" "$TRUSTSTORE_P12"
    chmod 644 "$TRUSTSTORE_P12"
    log_success "PKCS12 truststore created: $TRUSTSTORE_P12"
else
    log_error "Failed to create PKCS12 truststore"
    rm -f "$TEMP_P12"
    # Don't clean up other files as JKS already exists
    log_warning "JKS truststore was created successfully, but PKCS12 truststore failed"
    log_warning "You can continue with JKS truststore or manually create PKCS12 truststore"
fi

# Display completion summary
echo ""
echo "=================================================="
echo "Certificate Authority Generation Complete!"
echo "=================================================="
echo ""

display_ca_info

echo "Generated Files:"
echo "  - CA Private Key: $CA_KEY"
echo "  - CA Certificate: $CA_CERT"
echo "  - JKS Truststore:  $TRUSTSTORE_JKS"
echo "  - PKCS12 Truststore: $TRUSTSTORE_P12"
echo ""

echo "Truststore Configuration:"
echo "  - Password: $TRUSTSTORE_PASS"
echo ""

echo "Security Notes:"
echo "  ⚠️  The CA private key is highly sensitive - protect it carefully!"
echo "  ⚠️  Backup the CA files securely offline"
echo "  ⚠️  Do not commit CA private key to version control"
echo ""

echo "Next Steps:"
echo "  1. Generate cluster certificates using: ./scripts/generate-cluster-certs.sh <cluster-name>"
echo "  2. The CA truststore will be copied to each cluster's nodes"
echo "  3. All clusters will trust certificates signed by this CA"
echo ""

log_success "Shared CA is ready for multi-cluster deployment!"
echo ""
