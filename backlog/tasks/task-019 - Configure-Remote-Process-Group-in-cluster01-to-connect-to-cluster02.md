---
id: task-019
title: Configure Remote Process Group in cluster01 to connect to cluster02
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 04:34'
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
- [ ] #1 RPG component created in cluster01 pointing to https://localhost:31443/nifi
- [ ] #2 RPG successfully connects and retrieves cluster02 site-to-site details
- [ ] #3 RPG shows cluster02's input port 'From-Cluster01-Request' as available
- [ ] #4 RPG shows cluster02's output port 'To-Cluster01-Response' as available
- [ ] #5 Transport Protocol set to HTTPS (not RAW)
- [ ] #6 RPG shows green 'transmitting' indicator when active
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Steps

### 1. Access cluster01 NiFi UI
```bash
open https://localhost:30443/nifi
# Login: admin / changeme123456
```

### 2. Add Remote Process Group
- From toolbar, drag 'Remote Process Group' (RPG) to canvas
- In the dialog, enter cluster02 URL:
  ```
  https://localhost:31443/nifi
  ```
- Click 'ADD'

### 3. Configure RPG Transport Protocol
- Right-click RPG → Configure
- Settings tab:
  - Transport Protocol: **HTTPS** (important!)
  - Local Network Interface: (leave blank)
  - HTTP Proxy Server: (leave blank)
  - Communications Timeout: 30 sec (default)
  - Yield Duration: 10 sec (default)

### 4. Enable Transmission on Remote Ports
- Right-click RPG → 'Manage Remote Ports'
- You should see two sections:
  - **Input Ports** (left): cluster02's input ports for sending TO
  - **Output Ports** (right): cluster02's output ports for receiving FROM

**Enable Input Port:**
- Find 'From-Cluster01-Request' in Input Ports list
- Click the transmission icon (▶) to enable
- Set Concurrent Tasks: 1
- Set Compressed: false (or true for compression)

**Enable Output Port:**
- Find 'To-Cluster01-Response' in Output Ports list  
- Click transmission icon to enable
- Set Concurrent Tasks: 1

### 5. Verify RPG Connection
RPG should show:
- Small green indicator when successfully connected
- Hover over RPG to see connection details
- Should display: "Transmitting: 0 / 0" (when idle)

### 6. Test S2S Connectivity
```bash
# Verify RPG can retrieve cluster02 site-to-site details
curl -k -u admin:changeme123456 \
  https://localhost:30443/nifi-api/remote-process-groups/<rpg-id>
```

## Technical Details

### URL Configuration
- **Target URL**: https://localhost:31443/nifi
- **Protocol**: HTTPS (uses port 8443 internally via Site-to-Site)
- **From cluster01 perspective**: localhost:31443
- **Actual connection**: cluster01 containers can reach cluster02 via host networking

### Transport Protocol: HTTPS vs RAW
- **HTTPS**: Uses NiFi's web port (8443), better for firewalls
- **RAW**: Uses dedicated socket port (10000), better for performance
- **Our setup**: HTTPS (nifi.remote.input.http.enabled=true)

### Security
- **TLS**: Mutual TLS using shared CA certificate
- **Authentication**: Uses cluster01's keystore to authenticate to cluster02
- **Authorization**: cluster02 must allow cluster01's certificate

### Troubleshooting
If RPG shows red indicator:
1. Check cluster02 is running: `docker compose -f docker-compose-cluster02.yml ps`
2. Verify S2S endpoint: `curl -k https://localhost:31443/nifi-api/site-to-site`
3. Check ports are running in cluster02 NiFi UI
4. Review RPG configuration (HTTPS protocol selected)
5. Check logs: `docker compose -f docker-compose-cluster01.yml logs nifi-1`

## Expected Behavior
- RPG icon shows small green transmission indicator
- Hovering shows "Connected" status
- Input/Output ports appear in 'Manage Remote Ports'
- Can create connections to/from RPG
<!-- SECTION:NOTES:END -->
