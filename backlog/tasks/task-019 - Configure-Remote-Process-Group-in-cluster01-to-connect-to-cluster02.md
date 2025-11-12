---
id: task-019
title: Configure Remote Process Group in cluster01 to connect to cluster02
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 04:46'
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
## Prerequisites

**Dependencies:**
- ✅ task-017: Input Port 'From-Cluster01-Request' in cluster02 (running)
- ✅ task-018: Output Port 'To-Cluster01-Response' in cluster02 (running)

**Verify cluster02 Ports Ready:**
```bash
# Check both ports appear in S2S endpoint
TOKEN="<get-from-cluster02-ui>"
curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:31443/nifi-api/site-to-site \
  | jq '.controller.inputPorts, .controller.outputPorts'
```

**Manual Reference:** NiFi User Guide > Components > Remote Process Group

## Network Topology Understanding

**Critical Concept:** cluster01 connects to cluster02 using **localhost** from the host perspective:

```
Host Machine (your computer)
  ├─ cluster01 containers (ports 30443-30445)
  │   └─ cluster01-nifi-1 wants to connect to cluster02
  │       └─ Uses URL: https://localhost:31443/nifi
  │           └─ Docker port mapping: 31443 → cluster02-nifi-1:8443
  │
  └─ cluster02 containers (ports 31443-31445)
      └─ cluster02-nifi-1:8443 (HTTPS S2S endpoint)
```

**Why localhost works:**
- Both clusters use `network_mode: host` in docker-compose
- Host networking allows cluster01 to reach cluster02 via localhost:31443
- Alternative: Use Docker bridge network with service names (requires network config changes)

## Implementation Steps (Manual UI)

### Step 1: Access cluster01 NiFi UI

1. Open browser: `https://localhost:30443/nifi`
2. Accept SSL certificate warning
3. Login: `admin` / `changeme123456`
4. Ensure at root canvas (breadcrumb: **NiFi Flow**)

### Step 2: Add Remote Process Group (RPG)

1. From top toolbar, locate **Remote Process Group** icon (looks like a cloud with gears)
2. Click and drag to canvas
3. **Add Remote Process Group Dialog:**
   - **URLs:** `https://localhost:31443/nifi`
   - Click **ADD**

**Important URL Notes:**
- Must include `https://` protocol
- Must end with `/nifi` path
- Port: 31443 (cluster02's external port)
- DO NOT use: `http://`, container names, or IP addresses (unless network configured)

### Step 3: Wait for RPG Connection

**Automatic Connection Process:**
1. RPG immediately attempts to connect to cluster02
2. Performs mutual TLS handshake using cluster01's keystore
3. Retrieves site-to-site details from cluster02
4. Discovers available input/output ports

**Visual Indicators:**
- ⏳ **Gray icon**: Connecting...
- ⬤ **Green dot (top-right)**: Successfully connected
- ⚠️ **Red/Warning icon**: Connection failed (see troubleshooting)

**Wait 5-10 seconds** for initial connection.

### Step 4: Verify RPG Connection Status

1. **Hover over RPG** - Tooltip shows:
   ```
   Name: https://localhost:31443/nifi
   URLs: https://localhost:31443/nifi
   Transmitting: false
   ```

2. **Right-click RPG → View Status History**
   - Should show successful connection attempts
   - No errors in bulletin

If RPG shows **red/warning indicator**, see Troubleshooting section before continuing.

### Step 5: Configure RPG Settings

1. Right-click RPG → **Configure**

2. **SETTINGS Tab:**
   - **Name:** `cluster02-rpg` (optional, makes identification easier)
   - **Transport Protocol:** **HTTPS** (CRITICAL - must be HTTPS, not RAW)
   - **Communications Timeout:** `30 sec` (default)
   - **Yield Duration:** `10 sec` (default)
   - **Proxy Configuration:**
     - Local Network Interface: (leave blank)
     - HTTP Proxy Server Host: (leave blank)
     - HTTP Proxy Server Port: (leave blank)
     - HTTP Proxy User: (leave blank)

3. Click **APPLY**

**Transport Protocol Details:**
- **HTTPS**: Uses NiFi's web HTTPS port (8443 internal, 31443 external)
  - Property: `nifi.remote.input.http.enabled=true`
  - Benefit: Works through firewalls/proxies
  - Performance: Slightly slower (HTTP overhead)
  
- **RAW**: Uses dedicated socket port (10000)
  - Property: `nifi.remote.input.socket.port=10000`
  - Benefit: Better performance (raw socket)
  - Limitation: Requires opening additional port

**Our Configuration:** HTTPS (already enabled in nifi.properties)

### Step 6: Enable Remote Port Transmission

**This is the key step** - enabling data flow to/from cluster02 ports.

1. Right-click RPG → **Manage Remote Ports**

2. **Remote Ports Dialog** shows two sections:

   **Left Side - Input Ports (Send TO cluster02):**
   ```
   Port Name: From-Cluster01-Request
   Status: Valid
   Concurrent Tasks: 0 (disabled)
   Compressed: No
   Batch Count: -
   Batch Size: -
   Batch Duration: -
   ```

   **Right Side - Output Ports (Receive FROM cluster02):**
   ```
   Port Name: To-Cluster01-Response
   Status: Valid
   Concurrent Tasks: 0 (disabled)
   Compressed: No
   ```

3. **Enable Input Port (Send TO cluster02):**
   - Find `From-Cluster01-Request` in left column
   - Click **transmission icon (▶)** or **edit icon (pencil)**
   - **Edit Remote Port Configuration:**
     - **Concurrent Tasks:** `1` (start with 1, increase if needed)
     - **Use Compression:** `false` (uncheck - adds overhead for small data)
     - **Batch Settings:** (leave default for now)
       - Batch Count: (blank)
       - Batch Size: (blank)
       - Batch Duration: (blank)
   - Click **APPLY**
   - Concurrent Tasks changes to: `1`

4. **Enable Output Port (Receive FROM cluster02):**
   - Find `To-Cluster01-Response` in right column
   - Click **transmission icon (▶)** or **edit icon (pencil)**
   - **Edit Remote Port Configuration:**
     - **Concurrent Tasks:** `1`
     - **Use Compression:** `false`
   - Click **APPLY**

5. **Close** Remote Ports dialog

### Step 7: Verify RPG Ready State

**Visual Check:**
- RPG component now shows **two small port icons** on its sides:
  - **Left side:** Blue arrow OUT (sends to cluster02 input port)
  - **Right side:** Blue arrow IN (receives from cluster02 output port)
- Green connection indicator (top-right of RPG)
- Hover shows: `Transmitting: true`

**These port icons allow you to create connections in cluster01 flow**

## Verification Methods

### Method 1: RPG Status (UI)

Right-click RPG → **View status history**
- Should show active transmissions
- No error bulletins

### Method 2: RPG API (CLI)

```bash
# Get JWT token from cluster01 UI
TOKEN="<cluster01-token>"

# List all RPGs
curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:30443/nifi-api/flow/process-groups/root \
  | jq '.processGroupFlow.flow.remoteProcessGroups[]'
```

**Expected fields:**
```json
{
  "id": "<rpg-id>",
  "targetUri": "https://localhost:31443/nifi",
  "transmitting": true,
  "activeRemoteInputPortCount": 1,
  "inactiveRemoteInputPortCount": 0,
  "activeRemoteOutputPortCount": 1,
  "inactiveRemoteOutputPortCount": 0
}
```

### Method 3: Connection Test (next task)

Will verify in task-020 by sending actual data.

## Technical Details

### Mutual TLS Authentication

**Per NiFi Administration Guide:**
> "Site-to-Site connections will always REQUIRE two way SSL as the nodes will use their configured keystore/truststore for authentication."

**cluster01 → cluster02 TLS Handshake:**
1. cluster01 presents: `clusters/cluster01/conf/cluster01-nifi-1/keystore.p12`
2. cluster02 validates against: `clusters/cluster02/conf/cluster02-nifi-1/truststore.p12`
3. cluster02 presents: `clusters/cluster02/conf/cluster02-nifi-1/keystore.p12`
4. cluster01 validates against: `clusters/cluster01/conf/cluster01-nifi-1/truststore.p12`

**Both truststores contain same CA:** `certs/ca/ca-cert.pem` (shared CA)

**Verify certificate trust:**
```bash
# Verify cluster01 truststore contains shared CA
keytool -list -keystore clusters/cluster01/conf/cluster01-nifi-1/truststore.p12 \
  -storepass changeme123456

# Verify cluster02 truststore contains shared CA
keytool -list -keystore clusters/cluster02/conf/cluster02-nifi-1/truststore.p12 \
  -storepass changeme123456

# Both should show: ca-cert (or similar alias)
```

### Site-to-Site Properties (Reference)

**cluster01 nifi.properties:**
```properties
nifi.remote.input.secure=true
nifi.remote.input.http.enabled=true
nifi.web.https.port=8443
```

**cluster02 nifi.properties:**
```properties
nifi.remote.input.secure=true
nifi.remote.input.http.enabled=true
nifi.web.https.port=8443
```

Both clusters configured identically for bidirectional S2S.

## Expected Result

✅ **Success Indicators:**
1. RPG component visible in cluster01 canvas
2. RPG shows green indicator (connected)
3. RPG shows two port icons (input/output enabled)
4. Hover shows: `Transmitting: true`
5. "Manage Remote Ports" shows both ports with Concurrent Tasks: 1
6. No error bulletins
7. Ready to connect processors to RPG ports

## Troubleshooting

### Issue: RPG shows red/warning indicator

**Cause 1: cluster02 not running**
```bash
docker compose -f docker-compose-cluster02.yml ps
# All nifi containers should be Up
```

**Cause 2: Port 31443 not accessible**
```bash
curl -k https://localhost:31443/nifi-api/site-to-site
# Should return JSON (even if 401 without token)
```

**Cause 3: Certificate trust issue**
```bash
# Check cluster01 logs
docker compose -f docker-compose-cluster01.yml logs nifi-1 | grep -i "ssl\|certificate\|handshake"

# Look for errors like:
# - "unable to find valid certification path"
# - "SSLHandshakeException"
```

**Cause 4: Wrong URL**
- Verify URL: `https://localhost:31443/nifi` (not http, not without /nifi)
- Check port: 31443 (cluster02's external port)

### Issue: Ports not visible in "Manage Remote Ports"

**Cause:** cluster02 ports not at root canvas level or not running

**Solution:**
1. Open cluster02 UI: https://localhost:31443/nifi
2. Verify Input Port and Output Port at root canvas (not in Process Group)
3. Verify both ports RUNNING (green status)
4. In cluster01, right-click RPG → **Refresh Remote**

### Issue: "Transmitting: false" after enabling ports

**Normal:** Transmitting=true only when data actively flowing
**If ports enabled but showing 0 concurrent tasks:** Re-open "Manage Remote Ports" and verify settings saved

## Connection Preview (task-020)

Once RPG configured, you can create connections:
```
[Processor] → [RPG Input Port] → (network) → [cluster02 Input Port]
[cluster02 Output Port] → (network) → [RPG Output Port] → [Processor]
```

## Manual References

- **NiFi User Guide** > Components > Remote Process Group
- **NiFi Administration Guide** > System Properties > Site-to-Site Properties
- **NiFi REST API** > Remote Process Groups endpoints
<!-- SECTION:NOTES:END -->
