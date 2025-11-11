---
id: task-003
title: >-
  Create cluster-specific certificate generation script
  (generate-cluster-certs.sh)
status: Done
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 15:37'
labels:
  - pki
  - security
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement script to generate certificates for all nodes in a cluster using the shared CA.

Script should accept parameters:
- CLUSTER_NAME (e.g., cluster01)
- NODE_COUNT (default 3)

Generate certificates for:
- NiFi nodes: cluster01-nifi01, cluster01-nifi02, cluster01-nifi03
- ZooKeeper nodes: cluster01-zk01, cluster01-zk02, cluster01-zk03

Each cert should include proper SAN entries (DNS: node name, localhost; IP: 127.0.0.1)

Reference: Analysis report section 11.2 step 2
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Script generates node certificates signed by shared CA
- [x] #2 SAN entries include hostname and localhost
- [x] #3 PKCS12 keystores and truststores created
- [x] #4 Certificate validation passes (openssl verify)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Successfully implemented the cluster-specific certificate generation script (scripts/generate-cluster-certs.sh):

## Features Implemented

1. **Flexible Cluster Certificate Generation**:
   - Accepts cluster name parameter (format: clusterNN)
   - Optional node count parameter (default: 3, range: 1-9)
   - Validates cluster name format
   - Generates certificates for all NiFi and ZooKeeper nodes

2. **Node Naming Convention**:
   - NiFi nodes: `<cluster>-nifi01`, `<cluster>-nifi02`, `<cluster>-nifi03`, ...
   - ZooKeeper nodes: `<cluster>-zk01`, `<cluster>-zk02`, `<cluster>-zk03`, ...
   - Zero-padded numbering (01, 02, etc.)

3. **Certificate Generation per Node**:
   - 2048-bit RSA private key
   - X.509 certificate signed by shared CA
   - 10-year validity (3650 days)
   - Subject includes node name and type (NiFi or ZooKeeper)
   - All certificates stored in `clusters/<cluster>/certs/<node>/`

4. **Complete SAN Entries**:
   Each certificate includes:
   - DNS.1: `<node-name>` (e.g., cluster01-nifi01)
   - DNS.2: `<node-name>.<cluster>-nifi-net` (for Docker network)
   - DNS.3: `localhost`
   - IP.1: `127.0.0.1`

5. **Keystores and Truststores**:
   - PKCS12 keystore (keystore.p12) for each node
   - PKCS12 truststore copied from shared CA
   - Same password for keystore and truststore
   - Interactive or default password configuration

6. **Built-in Validation**:
   - Validates shared CA exists before generation
   - Verifies each generated certificate against CA using `openssl verify`
   - Reports validation status for all certificates
   - Fails if any certificate validation fails

7. **Security & Error Handling**:
   - Private keys: 600 permissions (owner only)
   - Certificates/keystores: 644 permissions
   - Color-coded logging
   - Confirms before overwriting existing certificates
   - Cleanup of temporary files (CSR, SAN config)

## Testing Results

Tested with cluster01 (3 nodes):
- ✅ Generated 6 certificates (3 NiFi + 3 ZooKeeper)
- ✅ All SAN entries correct
- ✅ All certificates validated against shared CA
- ✅ Keystores and truststores created properly
- ✅ File permissions set correctly

Verified:
```bash
# Certificate validation
openssl verify -CAfile shared/certs/ca/ca-cert.pem \
  clusters/cluster01/certs/cluster01-nifi01/server-cert.pem
# Result: OK

# SAN entries
DNS:cluster01-nifi01
DNS:cluster01-nifi01.cluster01-nifi-net
DNS:localhost
IP Address:127.0.0.1

# Truststore contains CA
subject=CN=NiFi Multi-Cluster Root CA
```

## Generated Structure

```
clusters/cluster01/certs/
├── cluster01-nifi01/
│   ├── keystore.p12
│   ├── server-cert.pem
│   ├── server-key.pem (600)
│   └── truststore.p12
├── cluster01-nifi02/
│   └── ... (same structure)
├── cluster01-nifi03/
│   └── ... (same structure)
├── cluster01-zk01/
│   └── ... (same structure)
├── cluster01-zk02/
│   └── ... (same structure)
└── cluster01-zk03/
    └── ... (same structure)
```

## Script Usage

```bash
# Generate certificates for 3-node cluster (default)
./scripts/generate-cluster-certs.sh cluster01

# Generate certificates for 5-node cluster
./scripts/generate-cluster-certs.sh cluster02 5

# Non-interactive with default password
echo "yes" | ./scripts/generate-cluster-certs.sh cluster01
```

The script is ready to generate certificates for any number of clusters with the shared CA.
<!-- SECTION:NOTES:END -->
