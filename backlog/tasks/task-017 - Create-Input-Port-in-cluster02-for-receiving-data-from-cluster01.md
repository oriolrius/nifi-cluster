---
id: task-017
title: Create Input Port in cluster02 for receiving data from cluster01
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 04:41'
labels:
  - site-to-site
  - cluster02
  - input-port
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a root-level Input Port in cluster02 that will receive data from cluster01 via Site-to-Site protocol. The port must be at the root canvas level (not in a process group) to be accessible via Remote Process Group.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Input Port named 'From-Cluster01-Request' created at root canvas in cluster02
- [ ] #2 Port is in RUNNING state and visible in NiFi UI
- [ ] #3 Port appears in cluster02's site-to-site endpoint: GET https://localhost:31443/nifi-api/site-to-site
- [ ] #4 Port has access policy allowing 'receive data via site-to-site' for all nodes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Steps

### 1. Access cluster02 NiFi UI
```bash
# Open cluster02 in browser
open https://localhost:31443/nifi
# Login: admin / changeme123456
```

### 2. Create Input Port at Root Canvas
- Ensure you are at the root canvas (not inside any process group)
- Drag 'Input Port' component from toolbar to canvas
- Name it: 'From-Cluster01-Request'
- Click 'ADD'

### 3. Configure Input Port
- Right-click the Input Port → Configure
- Settings tab:
  - Concurrent tasks: 1 (default)
  - Keep 'Allow Remote Access' ENABLED (critical for S2S)
- Comments: 'Receives data from cluster01 via Site-to-Site'

### 4. Start the Input Port
- Right-click → Start
- Verify status shows green 'Running' indicator

### 5. Verify S2S Availability
Test that the port is exposed via Site-to-Site API:
```bash
curl -k -u admin:changeme123456 https://localhost:31443/nifi-api/site-to-site | jq '.controller.inputPorts'
```

Expected output should include:
```json
{
  "id": "<port-id>",
  "name": "From-Cluster01-Request",
  "type": "INPUT_PORT"
}
```

### 6. Access Policy (if needed)
If using authorization policies:
- Access 'Policies' menu (top right)
- Select policy: 'receive data via site-to-site'
- Add users/groups as needed
- Or use global 'retrieve site-to-site details' policy

## Technical Details
- **Port Level**: Must be at root canvas (Process Group ID = root)
- **Remote Access**: Enabled by default for root-level ports
- **Protocol**: HTTPS Site-to-Site (nifi.remote.input.http.enabled=true)
- **Security**: Mutual TLS using shared CA certificate
- **Concurrency**: Default 1, can increase for higher throughput

## Verification Commands
```bash
# List all available S2S input ports
curl -k -u admin:changeme123456 \
  https://localhost:31443/nifi-api/site-to-site \
  | jq '.controller.inputPorts[].name'

# Check port status via API
curl -k -u admin:changeme123456 \
  https://localhost:31443/nifi-api/flow/process-groups/root/input-ports \
  | jq '.inputPorts[] | {name: .component.name, state: .component.state}'
```

## Current Status

**Clusters are running but showing 'unhealthy' status:**
```
cluster01-nifi-1: Up 10 hours (unhealthy)
cluster02-nifi-1: Up 10 hours (unhealthy)
```

**Authentication Issue:**
- API returns 401 Unauthorized with basic auth
- NiFi single-user auth requires token-based authentication
- Cannot test S2S endpoints via curl without proper token

**Implementation Approach:**
This task requires **manual UI interaction**:
1. Open https://localhost:31443/nifi in browser
2. Login with admin/changeme123456
3. Create Input Port at root canvas
4. Enable 'Allow Remote Access'
5. Start the port

**Why Not Automated:**
- MCP NiFi server doesn't exist in this project (mcp-servers/nifi/ directory not found)
- NiFi REST API requires token authentication (not basic auth)
- Tasks 017-020 are designed as manual UI workflows

**Next Steps:**
- User must perform manual UI configuration
- OR: Build NiFi MCP server for programmatic access
- OR: Implement token-based API authentication script
<!-- SECTION:NOTES:END -->
