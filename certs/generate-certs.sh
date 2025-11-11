#!/bin/bash
# NiFi Cluster PKI Certificate Generation Script
# Generates Root CA and server certificates for NiFi and ZooKeeper nodes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
CA_SUBJECT="/C=US/ST=California/L=San Francisco/O=NiFi Cluster/OU=Certificate Authority/CN=NiFi Cluster Root CA"
VALIDITY_DAYS=3650
KEY_SIZE=2048
KEYSTORE_PASS="changeme123456"
TRUSTSTORE_PASS="changeme123456"

echo "==============================================="
echo "NiFi Cluster PKI Generation"
echo "==============================================="
echo ""

# Create directories if they don't exist
mkdir -p ca
mkdir -p nifi-1 nifi-2 nifi-3
mkdir -p zookeeper-1 zookeeper-2 zookeeper-3

# Clean up existing certificates
echo "Cleaning up old certificates..."
rm -f ca/*.pem ca/*.key ca/*.srl ca/*.jks ca/*.p12
rm -f nifi-*/*.{pem,key,csr,p12,jks,cnf}
rm -f zookeeper-*/*.{pem,key,csr,p12,jks,cnf}

echo ""
echo "Step 1: Creating Root CA"
echo "---------------------------------------"

# Generate Root CA private key
openssl genrsa -out ca/ca-key.pem $KEY_SIZE
echo "✓ Generated Root CA private key"

# Generate Root CA certificate
openssl req -new -x509 -days $VALIDITY_DAYS \
    -key ca/ca-key.pem \
    -out ca/ca-cert.pem \
    -subj "$CA_SUBJECT"
echo "✓ Generated Root CA certificate"

# Convert CA cert to JKS truststore
keytool -import -noprompt \
    -alias ca-cert \
    -file ca/ca-cert.pem \
    -keystore ca/truststore.jks \
    -storepass "$TRUSTSTORE_PASS"
echo "✓ Created JKS truststore"

# Convert JKS truststore to PKCS12
keytool -importkeystore -noprompt \
    -srckeystore ca/truststore.jks \
    -srcstoretype JKS \
    -srcstorepass "$TRUSTSTORE_PASS" \
    -destkeystore ca/truststore.p12 \
    -deststoretype PKCS12 \
    -deststorepass "$TRUSTSTORE_PASS"
echo "✓ Created PKCS12 truststore"

echo ""
echo "Step 2: Generating NiFi Node Certificates"
echo "---------------------------------------"

for node in nifi-1 nifi-2 nifi-3; do
    echo "Generating certificates for $node..."

    NODE_DIR="$node"
    SUBJECT="/C=US/ST=California/L=San Francisco/O=NiFi Cluster/OU=NiFi Nodes/CN=$node"

    # Generate private key
    openssl genrsa -out "$NODE_DIR/server-key.pem" $KEY_SIZE

    # Generate certificate signing request
    openssl req -new \
        -key "$NODE_DIR/server-key.pem" \
        -out "$NODE_DIR/server.csr" \
        -subj "$SUBJECT"

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
O = NiFi Cluster
OU = NiFi Nodes
CN = $node

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $node
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

    # Sign certificate with CA
    openssl x509 -req -days $VALIDITY_DAYS \
        -in "$NODE_DIR/server.csr" \
        -CA ca/ca-cert.pem \
        -CAkey ca/ca-key.pem \
        -CAcreateserial \
        -out "$NODE_DIR/server-cert.pem" \
        -extensions v3_req \
        -extfile "$NODE_DIR/san.cnf"

    # Create PKCS12 keystore
    openssl pkcs12 -export \
        -in "$NODE_DIR/server-cert.pem" \
        -inkey "$NODE_DIR/server-key.pem" \
        -out "$NODE_DIR/keystore.p12" \
        -name "$node" \
        -CAfile ca/ca-cert.pem \
        -caname root \
        -password "pass:$KEYSTORE_PASS"

    # Convert PKCS12 to JKS keystore
    keytool -importkeystore -noprompt \
        -srckeystore "$NODE_DIR/keystore.p12" \
        -srcstoretype PKCS12 \
        -srcstorepass "$KEYSTORE_PASS" \
        -destkeystore "$NODE_DIR/keystore.jks" \
        -deststoretype JKS \
        -deststorepass "$KEYSTORE_PASS" \
        -destkeypass "$KEYSTORE_PASS"

    # Copy truststores to node directory
    cp ca/truststore.jks "$NODE_DIR/truststore.jks"
    cp ca/truststore.p12 "$NODE_DIR/truststore.p12"

    # Set permissions
    chmod 644 "$NODE_DIR"/*.jks
    chmod 600 "$NODE_DIR"/*.p12

    echo "✓ Generated certificates for $node"
done

echo ""
echo "Step 3: Generating ZooKeeper Node Certificates"
echo "---------------------------------------"

for node in zookeeper-1 zookeeper-2 zookeeper-3; do
    echo "Generating certificates for $node..."

    NODE_DIR="$node"
    SUBJECT="/C=US/ST=California/L=San Francisco/O=NiFi Cluster/OU=ZooKeeper Nodes/CN=$node"

    # Generate private key
    openssl genrsa -out "$NODE_DIR/server-key.pem" $KEY_SIZE

    # Generate certificate signing request
    openssl req -new \
        -key "$NODE_DIR/server-key.pem" \
        -out "$NODE_DIR/server.csr" \
        -subj "$SUBJECT"

    # Create SAN configuration
    cat > "$NODE_DIR/san.cnf" <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = NiFi Cluster
OU = ZooKeeper Nodes
CN = $node

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $node
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

    # Sign certificate with CA
    openssl x509 -req -days $VALIDITY_DAYS \
        -in "$NODE_DIR/server.csr" \
        -CA ca/ca-cert.pem \
        -CAkey ca/ca-key.pem \
        -CAcreateserial \
        -out "$NODE_DIR/server-cert.pem" \
        -extensions v3_req \
        -extfile "$NODE_DIR/san.cnf"

    # Create PKCS12 keystore
    openssl pkcs12 -export \
        -in "$NODE_DIR/server-cert.pem" \
        -inkey "$NODE_DIR/server-key.pem" \
        -out "$NODE_DIR/keystore.p12" \
        -name "$node" \
        -CAfile ca/ca-cert.pem \
        -caname root \
        -password "pass:$KEYSTORE_PASS"

    # Convert PKCS12 to JKS keystore
    keytool -importkeystore -noprompt \
        -srckeystore "$NODE_DIR/keystore.p12" \
        -srcstoretype PKCS12 \
        -srcstorepass "$KEYSTORE_PASS" \
        -destkeystore "$NODE_DIR/keystore.jks" \
        -deststoretype JKS \
        -deststorepass "$KEYSTORE_PASS" \
        -destkeypass "$KEYSTORE_PASS"

    # Copy truststores
    cp ca/truststore.jks "$NODE_DIR/truststore.jks"
    cp ca/truststore.p12 "$NODE_DIR/truststore.p12"

    # Set permissions
    chmod 644 "$NODE_DIR"/*.jks
    chmod 600 "$NODE_DIR"/*.p12

    echo "✓ Generated certificates for $node"
done

echo ""
echo "==============================================="
echo "Certificate Generation Complete!"
echo "==============================================="
echo ""
echo "Summary:"
echo "  - Root CA: ca/ca-cert.pem"
echo "  - Truststore: ca/truststore.jks and ca/truststore.p12 (PKCS12)"
echo "  - NiFi node keystores: nifi-*/keystore.p12 (PKCS12) and nifi-*/keystore.jks"
echo "  - NiFi node truststores: nifi-*/truststore.p12 (PKCS12) and nifi-*/truststore.jks"
echo "  - ZooKeeper node keystores: zookeeper-*/keystore.p12 and zookeeper-*/keystore.jks"
echo "  - ZooKeeper node truststores: zookeeper-*/truststore.p12 and zookeeper-*/truststore.jks"
echo ""
echo "Passwords:"
echo "  - Keystore password: $KEYSTORE_PASS"
echo "  - Truststore password: $TRUSTSTORE_PASS"
echo ""
echo "Next steps:"
echo "  1. Update docker-compose.yml to mount certificates"
echo "  2. Configure NiFi to use SSL with these certificates"
echo "  3. Restart the cluster"
echo ""
