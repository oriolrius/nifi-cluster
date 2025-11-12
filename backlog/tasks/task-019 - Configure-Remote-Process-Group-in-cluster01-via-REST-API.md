---
id: task-019
title: Configure Remote Process Group in cluster01 via REST API
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 05:00'
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
## Automated Implementation

**This task is automated via REST API. Manual RPG transmission configuration still required (see Known Limitations).**

### Quick Start

```bash
# Full Site-to-Site setup (includes this task):
./automation/setup-site-to-site.sh cluster01 cluster02

# Execution time: ~5 seconds + 10 seconds RPG connection wait
```

**What it automates:**
- Creates Remote Process Group pointing to cluster02
- Waits for automatic S2S connection
- RPG discovers available ports automatically

**Manual step required:**
- Enable transmission on remote ports (see Step 6)

## Manual API Implementation

### Step 1: Get Authentication Token

```bash
CLUSTER01_URL="https://localhost:30443"
CLUSTER02_URL="https://localhost:31443"

TOKEN=$(curl -k -s -X POST "${CLUSTER01_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")
```

### Step 2: Create Remote Process Group

```bash
RPG_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/process-groups/root/remote-process-groups" \
  -d "{
    \"revision\": {\"version\": 0},
    \"component\": {
      \"targetUri\": \"${CLUSTER02_URL}/nifi\",
      \"transportProtocol\": \"HTTP\",
      \"communicationsTimeout\": \"30 sec\",
      \"yieldDuration\": \"10 sec\"
    }
  }")

RPG_ID=$(echo "$RPG_RESPONSE" | jq -r '.component.id')
echo "RPG ID: $RPG_ID"
```

### Step 3: Wait for RPG Connection

```bash
echo "Waiting for RPG to connect to cluster02..."
sleep 10

# Check connection status
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}" \
  | jq '{
    targetUri: .component.targetUri,
    transmitting: .component.transmitting,
    activeRemoteInputPortCount: .component.activeRemoteInputPortCount,
    activeRemoteOutputPortCount: .component.activeRemoteOutputPortCount
  }'
```

**Expected:**
```json
{
  "targetUri": "https://localhost:31443/nifi",
  "transmitting": false,
  "activeRemoteInputPortCount": 0,
  "activeRemoteOutputPortCount": 0
}
```

RPG connected but transmission disabled (count = 0).

### Step 4: Discover Available Remote Ports

```bash
# List remote ports discovered by RPG
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}" \
  | jq '{
    inputPorts: .component.contents.inputPorts,
    outputPorts: .component.contents.outputPorts
  }'
```

**Expected:**
```json
{
  "inputPorts": [
    {
      "id": "<port-id>",
      "name": "From-Cluster01-Request",
      "connected": false,
      "targetRunning": true
    }
  ],
  "outputPorts": [
    {
      "id": "<port-id>",
      "name": "To-Cluster01-Response",
      "connected": false,
      "targetRunning": true
    }
  ]
}
```

### Step 5: Configure RPG Settings (Optional)

```bash
# Get current RPG state
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}")

VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

# Update RPG configuration
curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}" \
  -d "{
    \"revision\": {\"version\": ${VERSION}},
    \"component\": {
      \"id\": \"${RPG_ID}\",
      \"name\": \"cluster02-rpg\",
      \"transportProtocol\": \"HTTP\",
      \"communicationsTimeout\": \"30 sec\"
    }
  }"
```

### Step 6: Enable Port Transmission (MANUAL)

**Known Limitation:** NiFi REST API requires complex workflow to enable RPG port transmission:
1. Get remote port details
2. Update port configuration with concurrent tasks
3. Handle version conflicts

**Current workaround - Manual UI step:**

1. Open cluster01 NiFi UI: https://localhost:30443/nifi
2. Right-click RPG → **Manage Remote Ports**
3. **Input Ports section (left):**
   - Find: `From-Cluster01-Request`
   - Click transmission icon (▶) or pencil icon
   - Set **Concurrent Tasks:** `1`
   - Set **Use Compression:** `false`
   - Click **APPLY**
4. **Output Ports section (right):**
   - Find: `To-Cluster01-Response`
   - Click transmission icon (▶) or pencil icon
   - Set **Concurrent Tasks:** `1`
   - Set **Use Compression:** `false`
   - Click **APPLY**
5. Close dialog

**Alternative (API - Advanced):**

```bash
# Enable input port transmission
curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}/input-ports/${REMOTE_INPUT_PORT_ID}" \
  -d "{
    \"revision\": {\"version\": 1},
    \"remoteProcessGroupPort\": {
      \"id\": \"${REMOTE_INPUT_PORT_ID}\",
      \"groupId\": \"${RPG_ID}\",
      \"targetId\": \"<target-port-id>\",
      \"concurrentlySchedulableTaskCount\": 1,
      \"useCompression\": false
    }
  }"
```

Note: Requires exact port IDs from cluster02's S2S endpoint.

## Verification

### Check RPG Connection Status

```bash
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}" \
  | jq '{
    name: .component.name,
    targetUri: .component.targetUri,
    transmitting: .component.transmitting,
    connected: .component.flowRefreshed,
    activeInputPorts: .component.activeRemoteInputPortCount,
    activeOutputPorts: .component.activeRemoteOutputPortCount
  }'
```

**After enabling transmission:**
```json
{
  "name": "cluster02-rpg",
  "targetUri": "https://localhost:31443/nifi",
  "transmitting": true,
  "connected": "...",
  "activeInputPorts": 1,
  "activeOutputPorts": 1
}
```

### Visual Verification (UI)

Open https://localhost:30443/nifi:
- RPG component visible
- Green indicator (top-right) = connected
- Two port icons visible (left/right) = ports enabled
- Hover shows: `Transmitting: true`

## Network Topology

```
┌────────────────────────────────────────────────────────┐
│ cluster01 (localhost:30443)                           │
│                                                          │
│  [Remote Process Group]                               │
│   Target: https://localhost:31443/nifi                │
│   Transport: HTTPS                                      │
│   Status: Connected                                     │
│                                                          │
│   Ports:                                                │
│   → To cluster02: From-Cluster01-Request              │
│   ← From cluster02: To-Cluster01-Response             │
│                                                          │
└──────────────────┬─────────────────────────────────────┘
                   │
                   │ HTTPS Site-to-Site (Mutual TLS)
                   │ Port: 31443 → container 8443
                   │
┌──────────────────┴─────────────────────────────────────┐
│ cluster02 (localhost:31443)                           │
│                                                          │
│  [Input Port: From-Cluster01-Request]                 │
│  [Output Port: To-Cluster01-Response]                 │
│                                                          │
└────────────────────────────────────────────────────────┘
```

**Host Networking:**
- Both clusters use `network_mode: host`
- cluster01 reaches cluster02 via `localhost:31443`
- Docker maps 31443 → cluster02-nifi-1:8443

## Mutual TLS Configuration

**Automatic Certificate Exchange:**

1. RPG uses cluster01's keystore to authenticate:
   - Keystore: `clusters/cluster01/conf/cluster01-nifi-1/keystore.p12`

2. cluster02 validates against truststore:
   - Truststore: `clusters/cluster02/conf/cluster02-nifi-1/truststore.p12`

3. cluster02 presents its certificate:
   - Keystore: `clusters/cluster02/conf/cluster02-nifi-1/keystore.p12`

4. cluster01 validates against truststore:
   - Truststore: `clusters/cluster01/conf/cluster01-nifi-1/truststore.p12`

**Shared CA:** `certs/ca/ca-cert.pem` (both truststores contain this CA)

**Verification:**
```bash
# Both clusters trust the same CA
keytool -list -keystore clusters/cluster01/conf/cluster01-nifi-1/truststore.p12 \
  -storepass changeme123456 | grep "ca-cert"

keytool -list -keystore clusters/cluster02/conf/cluster02-nifi-1/truststore.p12 \
  -storepass changeme123456 | grep "ca-cert"
```

## Reusable Function

From `automation/lib/nifi-api.sh`:

```bash
source automation/lib/nifi-api.sh

TOKEN=$(nifi_get_token "https://localhost:30443")

# Create RPG
RPG_ID=$(nifi_create_rpg \
    "https://localhost:30443" \
    "$TOKEN" \
    "https://localhost:31443/nifi")

echo "RPG created: $RPG_ID"
echo "Wait 10 seconds for connection..."
sleep 10
```

## Known Limitations

### RPG Port Transmission Requires Manual Step

**Why:** NiFi REST API for enabling RPG transmission is complex:
- Requires exact remote port IDs from target cluster
- Version conflict handling needed
- Port discovery must complete first

**Future Improvement:** Implement full API automation for port enablement.

**Current Workaround:** Manual UI configuration (Step 6 above) - takes 30 seconds.

## Transport Protocol: HTTP vs RAW

### HTTP (HTTPS) - Current Setup
- **Uses:** Web HTTPS port (8443 internal, 31443 external)
- **Property:** `nifi.remote.input.http.enabled=true`
- **Pros:** Works through firewalls/proxies
- **Cons:** Slight performance overhead

### RAW
- **Uses:** Dedicated socket port (10000)
- **Property:** `nifi.remote.input.socket.port=10000`
- **Pros:** Better performance (raw socket)
- **Cons:** Requires opening additional port

**Our Configuration:** HTTP/HTTPS (already enabled in both clusters)

## Troubleshooting

### RPG Shows Red/Warning Indicator

**Cause 1:** cluster02 not running
```bash
docker compose -f docker-compose-cluster02.yml ps
```

**Cause 2:** Network connectivity issue
```bash
curl -k https://localhost:31443/nifi-api/site-to-site
# Should return JSON (even without token)
```

**Cause 3:** Certificate trust issue
```bash
docker compose -f docker-compose-cluster01.yml logs nifi-1 \
  | grep -i "ssl\|certificate\|handshake" | tail -20
```

### RPG Connected but Ports Not Visible

**Cause:** cluster02 ports not at root level or not running
**Solution:** Verify in cluster02:
```bash
curl -k -s -H "Authorization: Bearer ${CLUSTER02_TOKEN}" \
  "https://localhost:31443/nifi-api/site-to-site" \
  | jq '{inputPorts: .controller.inputPorts, outputPorts: .controller.outputPorts}'
```

## References

- **API Library:** `automation/lib/nifi-api.sh`
- **Automation Script:** `automation/setup-site-to-site.sh`
- **Previous Tasks:** task-017 (Input Port), task-018 (Output Port + Flow)
- **Next Task:** task-020 (Complete test flow)
- **Architecture:** `backlog/docs/doc-005 - NiFi-REST-API-Automation-Strategy.md`
- **NiFi Admin Guide:** Site-to-Site Properties section
<!-- SECTION:NOTES:END -->
