---
id: task-019
title: Configure Remote Process Group in cluster01 via REST API
status: In Progress
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 06:43'
labels:
  - site-to-site
  - cluster01
  - remote-process-group
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create and configure a Remote Process Group (RPG) in cluster01 that connects to cluster02 using HTTPS Site-to-Site protocol. The RPG will enable cluster01 to send data to cluster02's input port and receive responses from cluster02's output port.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 RPG component created in cluster01 pointing to https://localhost:31443/nifi
- [ ] #2 RPG successfully connects and retrieves cluster02 site-to-site details
- [ ] #3 RPG shows cluster02's input port 'From-Cluster01-Request' as available
- [ ] #4 RPG shows cluster02's output port 'To-Cluster01-Response' as available
- [x] #5 Transport Protocol set to HTTPS (not RAW)
- [ ] #6 RPG shows green 'transmitting' indicator when active
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Task implemented with critical networking discovery.

RPG Created:
- ID: 76ccef2c-019a-1000-ffff-ffff809a40c9
- Target URI attempted: https://172.25.245.23:31443/nifi (host IP)

CRITICAL FINDING - Network Architecture Limitation:

The multi-cluster setup uses SEPARATE Docker bridge networks:
- cluster01: cluster01-network
- cluster02: cluster02-network

This creates two issues:

1. localhost Connection Failure:
   - From inside cluster01 containers, localhost:31443 is NOT accessible
   - Port 31443 is only exposed on the host, not within cluster01 network
   - Error: "Connection refused"

2. Certificate Hostname Mismatch:
   - When using host IP (172.25.245.23), TLS fails
   - cluster02 certificate SANs: [cluster02-nifi-1, nifi-1, localhost, 127.0.0.1]
   - Does NOT include host IP address
   - Error: "Certificate doesnt match any of the subject alternative names"

SOLUTIONS (not implemented in this task):

Option 1: Shared Docker Network
- Create inter-cluster-network bridge
- Add both clusters to this shared network
- Use service names: cluster02-nifi-1:8443

Option 2: Certificate Regeneration
- Add host IP to certificate SANs
- Regenerate certs/cluster02-nifi-1 certificates
- Update keystore.p12

Option 3: Host Network Mode
- Change network_mode from bridge to host
- Both clusters access localhost directly
- May cause port conflicts

RECOMMENDATION:
For production multi-cluster S2S, use shared Docker network (Option 1).
This requires updating docker-compose files to add external network.

Scripts created:
- create-rpg-cluster01.sh (initial attempt with localhost)
- recreate-rpg-with-host-ip.sh (discovered certificate issue)
- verify-rpg-connection.sh (connection testing)

Acceptance Criteria Status:
- AC#1 ✓ RPG component created successfully
- AC#2 ✗ Cannot connect (network isolation + cert mismatch)
- AC#3 ✗ Cannot discover ports (blocked by AC#2)
- AC#4 ✗ Cannot discover ports (blocked by AC#2)
- AC#5 ✓ Transport protocol set to HTTP (HTTPS)
- AC#6 ✗ Cannot transmit (blocked by AC#2)

TASK STATUS: Partially Complete
BLOCKER: Network architecture requires changes for inter-cluster S2S

NEXT STEPS:
1. Decide on solution approach (shared network recommended)
2. Update docker-compose files
3. Re-test RPG connection
4. Complete remaining ACs
<!-- SECTION:NOTES:END -->
