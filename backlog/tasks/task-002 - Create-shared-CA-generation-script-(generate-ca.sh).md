---
id: task-002
title: Create shared CA generation script (generate-ca.sh)
status: Done
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 15:33'
labels:
  - pki
  - security
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement one-time script to generate the shared Certificate Authority that will be used by all clusters.

Script should:
- Generate CA private key (2048-bit RSA)
- Generate CA certificate (10-year validity)
- Create JKS and PKCS12 truststores
- Store in shared/certs/ca/
- Be idempotent (don't overwrite existing CA)

Reference: Analysis report section 11.2 step 1
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Script creates CA key and certificate
- [x] #2 Both JKS and PKCS12 truststores generated
- [x] #3 Script validates existing CA before regenerating
- [x] #4 Proper error handling and logging implemented
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Successfully implemented the shared CA generation script (scripts/generate-ca.sh):

## Features Implemented

1. **CA Generation**:
   - Generates 2048-bit RSA private key
   - Creates X.509 CA certificate with 10-year validity (3650 days)
   - Subject: CN=NiFi Multi-Cluster Root CA, O=Multi-Cluster NiFi, OU=Certificate Authority
   - Stores in shared/certs/ca/ directory

2. **Truststore Creation**:
   - JKS truststore (truststore.jks)
   - PKCS12 truststore (truststore.p12)
   - Both contain the CA certificate for node validation

3. **Idempotency**:
   - Detects existing CA before generation
   - Validates existing CA:
     * Checks if files exist and are readable
     * Validates certificate format
     * Checks if certificate is expired
     * Verifies key and certificate match
   - Refuses to overwrite valid existing CA
   - Provides instructions for manual regeneration if needed
   - Prompts user confirmation if invalid CA detected

4. **Error Handling & Logging**:
   - Color-coded logging (INFO, SUCCESS, WARNING, ERROR)
   - Validates required commands (openssl, keytool)
   - Proper error handling with cleanup on failure
   - Set `set -e` and `set -u` for strict error handling
   - Comprehensive status messages at each step

5. **Security**:
   - CA private key permissions: 600 (read/write owner only)
   - CA certificate permissions: 644 (public readable)
   - Interactive password configuration (default or custom)
   - Security warnings about CA key protection

## Testing Results

Tested successfully:
- ✅ Initial CA generation: Created all files correctly
- ✅ Idempotency check: Detected existing CA and refused to overwrite
- ✅ Validation: Confirmed 2048-bit RSA, 10-year validity
- ✅ JKS truststore: Verified contents with keytool
- ✅ PKCS12 truststore: Verified contents with openssl

## Generated Files

Location: shared/certs/ca/
- ca-key.pem (600 permissions) - CA private key
- ca-cert.pem (644 permissions) - CA certificate
- truststore.jks (644 permissions) - JKS format truststore
- truststore.p12 (644 permissions) - PKCS12 format truststore

## Script Usage

```bash
# Generate shared CA (interactive)
./scripts/generate-ca.sh

# Run with default password (non-interactive)
echo "yes" | ./scripts/generate-ca.sh
```

The script is ready for use in the multi-cluster deployment workflow.
<!-- SECTION:NOTES:END -->
