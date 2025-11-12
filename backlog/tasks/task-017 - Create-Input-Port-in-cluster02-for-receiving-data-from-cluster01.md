---
id: task-017
title: Create Input Port in cluster02 for receiving data from cluster01
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 04:44'
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
## Prerequisites

**Verify cluster02 Site-to-Site Configuration:**
```bash
grep -E 'nifi.remote.input|nifi.web.https.port' \
  clusters/cluster02/conf/cluster02-nifi-1/nifi.properties
```

Expected properties:
- `nifi.remote.input.http.enabled=true`
- `nifi.remote.input.secure=true`
- `nifi.remote.input.socket.port=10000` (RAW protocol, not used)
- `nifi.web.https.port=8443` (HTTPS protocol, used for S2S)

**Manual Reference:** NiFi Administration Guide > System Properties > Site-to-Site Properties

## Implementation Steps (Manual UI)

### Step 1: Access cluster02 Web UI

1. Open browser (Chrome/Firefox recommended)
2. Navigate to: `https://localhost:31443/nifi`
3. Accept SSL certificate warning (self-signed CA)
4. Login credentials:
   - Username: `admin`
   - Password: `changeme123456`

### Step 2: Verify Root Canvas Level

**CRITICAL:** Input Ports must be at root canvas level to be remotely accessible.

1. Check breadcrumb trail at bottom of UI shows: **NiFi Flow** (not inside any Process Group)
2. If inside a Process Group, click breadcrumb to navigate to root

### Step 3: Create Input Port Component

1. From top toolbar, locate the **Input Port** icon (blue circle with arrow pointing in)
2. Click and drag to canvas
3. **Add Port Dialog** appears:
   - **Port Name:** `From-Cluster01-Request`
   - **Allow remote access:** ☑ **CHECKED** (enabled by default for root-level ports)
4. Click **ADD**

### Step 4: Configure Input Port (Optional Settings)

1. Right-click Input Port → **Configure**
2. **SETTINGS Tab:**
   - **Name:** `From-Cluster01-Request` (confirm)
   - **Concurrent tasks:** `1` (default, increase for high throughput)
   - **Comments:** `Receives data from cluster01 via Site-to-Site HTTPS protocol`
3. Click **APPLY**

**Note:** "Allow remote access" setting is NOT visible in Configure dialog for root-level ports (always enabled).

### Step 5: Start Input Port

1. Right-click Input Port → **Start**
2. Verify status indicator changes:
   - ⬤ **Red (stopped)** → ⬤ **Green (running)**
3. Port should display: **IN: 0** (no data received yet)

### Step 6: Verify Port ID (for API verification)

1. Right-click Input Port → **View configuration**
2. Note the **Port ID** (UUID format): e.g., `a1b2c3d4-5678-90ef-ghij-klmnopqrstuv`
3. Keep this ID for API verification

## Verification Methods

### Method 1: Visual Verification (UI)

✓ Input Port visible on root canvas
✓ Port name: `From-Cluster01-Request`
✓ Status: Green (running)
✓ Located at root level (breadcrumb shows "NiFi Flow")

### Method 2: Site-to-Site API Endpoint

**Command** (requires token authentication - see note below):
```bash
# Get JWT token first (manual step via UI)
# NiFi UI → User menu (top right) → Generate Token → Copy

TOKEN="<paste-token-here>"

curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:31443/nifi-api/site-to-site
```

**Expected Response Structure:**
```json
{
  "revision": {...},
  "controller": {
    "id": "<controller-id>",
    "name": "NiFi Flow",
    "remoteSiteListeningPort": 8443,
    "remoteSiteHttpListeningPort": 8443,
    "siteToSiteSecure": true,
    "inputPorts": [
      {
        "id": "<port-id>",
        "name": "From-Cluster01-Request",
        "type": "INPUT_PORT",
        "comments": "Receives data from cluster01 via Site-to-Site HTTPS protocol"
      }
    ],
    "outputPorts": []
  }
}
```

**Key Fields:**
- `remoteSiteHttpListeningPort: 8443` - confirms HTTPS S2S enabled
- `siteToSiteSecure: true` - confirms mutual TLS required
- `inputPorts[].name` - must include your port name

### Method 3: Process Group API

```bash
curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:31443/nifi-api/flow/process-groups/root
```

Look for `inputPorts` array containing your port.

## Getting JWT Token (Manual)

NiFi single-user authentication uses JWT tokens, not basic auth:

1. In NiFi UI (cluster02)
2. Click **User icon** (top right corner) → **admin**
3. Click **Generate Token**
4. Copy token to clipboard
5. Token valid for 1 hour (configurable via `nifi.security.user.jws.key.rotation.period`)

## Access Policies (Single-User Mode)

In single-user mode, the `admin` user has all permissions by default:
- ✓ retrieve site-to-site details
- ✓ receive data via site-to-site (all input ports)
- ✓ send data via site-to-site (all output ports)

**No additional policy configuration needed** for this setup.

## Security Notes

**Mutual TLS Requirement:**
Per NiFi Administration Guide: "Site-to-Site connections will always REQUIRE two way SSL as the nodes will use their configured keystore/truststore for authentication."

**cluster02 Certificates:**
- Keystore: `clusters/cluster02/conf/cluster02-nifi-1/keystore.p12`
- Truststore: `clusters/cluster02/conf/cluster02-nifi-1/truststore.p12`
- CA Certificate: `certs/ca/ca-cert.pem` (shared across all clusters)

**Verification:**
```bash
# Verify truststore contains shared CA
keytool -list -keystore clusters/cluster02/conf/cluster02-nifi-1/truststore.p12 \
  -storepass changeme123456
```

## Expected Result

✅ **Success Indicators:**
1. Input Port visible on cluster02 root canvas
2. Port status: Green (running)
3. Port appears in `GET /nifi-api/site-to-site` response
4. Port ID retrievable via API
5. Ready to receive data from cluster01 RPG

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Port not in S2S endpoint | Created inside Process Group | Move to root canvas |
| "Allow remote access" option missing | Port at root level (expected) | Option auto-enabled for root ports |
| API returns 401 | Using basic auth | Use JWT token from UI |
| Token expired | Token > 1 hour old | Generate new token |

## Manual Reference

- **NiFi User Guide** > Components > Input Port
- **NiFi Administration Guide** > System Properties > Site-to-Site Properties
- **NiFi REST API** > `/site-to-site` endpoint documentation
<!-- SECTION:NOTES:END -->
