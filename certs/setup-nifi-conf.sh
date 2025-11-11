#!/bin/bash
# Setup NiFi configuration directories with our PKI certificates

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "Setting up NiFi configuration directories with custom certificates..."

# Create conf directories for each NiFi node
for node in nifi-1 nifi-2 nifi-3; do
    echo "Configuring $node..."

    CONF_DIR="volumes/$node/conf"
    mkdir -p "$CONF_DIR"

    # Copy PKCS12 keystores to conf directory with expected names
    cp "certs/$node/keystore.p12" "$CONF_DIR/keystore.p12"
    cp "certs/$node/truststore.jks" "$CONF_DIR/truststore.p12"  # NiFi expects .p12 extension

    # Convert JKS truststore to PKCS12 if needed
    keytool -importkeystore -noprompt \
        -srckeystore "certs/$node/truststore.jks" \
        -srcstoretype JKS \
        -srcstorepass changeme123456 \
        -destkeystore "$CONF_DIR/truststore.p12" \
        -deststoretype PKCS12 \
        -deststorepass changeme123456 2>/dev/null || true

    # Set permissions
    chmod 644 "$CONF_DIR"/*.p12

    echo "✓ Configured $node"
done

echo ""
echo "Configuration complete!"
echo "NiFi nodes will use the custom PKI certificates."
echo ""
echo "Next: Start the cluster with 'docker compose up -d'"
