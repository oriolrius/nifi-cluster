---
id: task-high.01
title: Configure network access for inter-cluster Site-to-Site communication
status: In Progress
assignee: []
created_date: '2025-11-12 04:32'
updated_date: '2025-11-12 04:37'
labels:
  - site-to-site
  - networking
  - inter-cluster
dependencies: []
parent_task_id: task-high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enable network connectivity between cluster01 and cluster02 for NiFi Site-to-Site (S2S) protocol using HTTPS transport. Both clusters are already configured with nifi.remote.input.http.enabled=true and nifi.remote.input.secure=true in nifi.properties.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Verify cluster01 can reach cluster02's HTTPS endpoint (https://localhost:31443/nifi-api/site-to-site)
- [ ] #2 Verify cluster02 can reach cluster01's HTTPS endpoint (https://localhost:30443/nifi-api/site-to-site)
- [ ] #3 Confirm both clusters share the same CA certificate for TLS trust
- [ ] #4 Test S2S handshake using curl from host to both cluster endpoints
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Steps

### 1. Verify Current Configuration
Check that both clusters have Site-to-Site enabled:
```bash
# Cluster01
grep 'nifi.remote.input' clusters/cluster01/conf/cluster01-nifi-1/nifi.properties

# Cluster02
grep 'nifi.remote.input' clusters/cluster02/conf/cluster02-nifi-1/nifi.properties
```

Expected configuration:
- nifi.remote.input.http.enabled=true
- nifi.remote.input.secure=true
- nifi.web.https.port=8443

### 2. Test S2S Endpoint Connectivity
Test Site-to-Site API endpoint from host:
```bash
# Test cluster02 S2S endpoint (from host perspective)
curl -k https://localhost:31443/nifi-api/site-to-site

# Test cluster01 S2S endpoint
curl -k https://localhost:30443/nifi-api/site-to-site
```

Expected response: JSON with controller details and peers list

### 3. Verify Certificate Trust
Both clusters use shared CA at certs/ca/ca-cert.pem:
```bash
# Verify cluster01 trusts cluster02's certificate
openssl s_client -connect localhost:31443 -CAfile certs/ca/ca-cert.pem

# Verify cluster02 trusts cluster01's certificate  
openssl s_client -connect localhost:30443 -CAfile certs/ca/ca-cert.pem
```

### 4. Network Topology
- **Cluster01**: https://localhost:30443 (maps to cluster01-nifi-1:8443)
- **Cluster02**: https://localhost:31443 (maps to cluster02-nifi-1:8443)
- **Communication Path**: Host → Docker port mapping → Container network
- **Protocol**: HTTPS with mutual TLS using shared CA

### 5. Access Control
Ensure NiFi policies allow:
- Global policy: 'retrieve site-to-site details' 
- Port-specific: 'receive data via site-to-site'
- Port-specific: 'send data via site-to-site'

## Configuration References
- Site-to-Site properties: nifi.properties (already configured)
- CA Certificate: certs/ca/ca-cert.pem
- Transport Protocol: HTTPS (not RAW socket)
- Port: Uses web.https.port (8443 internal, 30443/31443 external)
<!-- SECTION:NOTES:END -->
