---
id: task-017
title: Create Input Port in cluster02 via REST API
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 04:58'
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
## Automated Implementation

**This task is automated via REST API. No manual UI interaction required.**

### Quick Start

```bash
# Full Site-to-Site setup (includes this task):
./automation/setup-site-to-site.sh cluster01 cluster02

# Or run individual API commands (see below)
```

**Execution time:** ~5 seconds

## Manual API Implementation (If Needed)

### Step 1: Get Authentication Token

```bash
CLUSTER02_URL="https://localhost:31443"

TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

echo "Token: ${TOKEN:0:50}..."
```

### Step 2: Create Input Port

```bash
INPUT_PORT_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/process-groups/root/input-ports" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "name": "From-Cluster01-Request",
      "comments": "Receives data from cluster01 via Site-to-Site HTTPS protocol"
    }
  }')

INPUT_PORT_ID=$(echo "$INPUT_PORT_RESPONSE" | jq -r '.component.id')
echo "Input Port Created: $INPUT_PORT_ID"
```

### Step 3: Start Input Port

```bash
# Get current revision
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${INPUT_PORT_ID}")

VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

# Start the port
curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${INPUT_PORT_ID}/run-status" \
  -d "{
    \"revision\": {\"version\": ${VERSION}},
    \"state\": \"RUNNING\"
  }"

echo "Input Port Started"
```

## Verification

### Method 1: API Query

```bash
# Verify port exists and is running
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/flow/process-groups/root" \
  | jq '.processGroupFlow.flow.inputPorts[] | {name: .component.name, state: .component.state, id: .id}'
```

**Expected output:**
```json
{
  "name": "From-Cluster01-Request",
  "state": "RUNNING",
  "id": "<port-uuid>"
}
```

### Method 2: Site-to-Site Endpoint

```bash
# Verify port appears in S2S endpoint
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/site-to-site" \
  | jq '.controller.inputPorts[] | {name: .name, id: .id}'
```

**Expected:** Port appears in `inputPorts` array with correct name.

### Method 3: Visual Verification (UI)

Open https://localhost:31443/nifi in browser:
- Should see Input Port component on root canvas
- Port name: `From-Cluster01-Request`
- Status indicator: ⬤ Green (RUNNING)

## Technical Details

### API Endpoint
- **Method:** POST
- **URL:** `/nifi-api/process-groups/root/input-ports`
- **Auth:** Bearer token (JWT)
- **Content-Type:** application/json

### Request Body
```json
{
  "revision": {"version": 0},
  "component": {
    "name": "From-Cluster01-Request",
    "comments": "Receives data from cluster01 via Site-to-Site HTTPS protocol"
  }
}
```

### Response Body
```json
{
  "revision": {...},
  "id": "<port-uuid>",
  "uri": "https://localhost:31443/nifi-api/input-ports/<port-uuid>",
  "component": {
    "id": "<port-uuid>",
    "parentGroupId": "root",
    "name": "From-Cluster01-Request",
    "comments": "Receives data from cluster01 via Site-to-Site HTTPS protocol",
    "state": "STOPPED",
    "type": "INPUT_PORT",
    "transmitting": false,
    "concurrentlySchedulableTaskCount": 1,
    "portFunction": "STANDARD"
  }
}
```

### Root Canvas Requirement

**CRITICAL:** Input Ports must be created at root level (`process-groups/root`) to be accessible via Site-to-Site.

Ports created inside Process Groups are NOT exposed to Remote Process Groups.

### Security Configuration

**Authentication:** Single-user mode (admin/changeme123456)
- Token expires after 1 hour
- Renewable via `/access/token` endpoint

**Authorization:** Single-user mode grants all permissions
- No additional policy configuration needed
- Port automatically allows `receive data via site-to-site`

### Certificate Trust

**Mutual TLS Required:**
- cluster02 keystore: `clusters/cluster02/conf/cluster02-nifi-1/keystore.p12`
- cluster02 truststore: `clusters/cluster02/conf/cluster02-nifi-1/truststore.p12`
- Shared CA: `certs/ca/ca-cert.pem`

Both cluster01 and cluster02 must trust the same CA for Site-to-Site to work.

## Reusable Function (API Library)

From `automation/lib/nifi-api.sh`:

```bash
source automation/lib/nifi-api.sh

# Automated creation
TOKEN=$(nifi_get_token "https://localhost:31443")
PORT_ID=$(nifi_create_input_port \
    "https://localhost:31443" \
    "$TOKEN" \
    "From-Cluster01-Request" \
    "Receives data from cluster01")
nifi_start_component "https://localhost:31443" "$TOKEN" "$PORT_ID" "input-ports"
```

## Troubleshooting

### Error: "Unauthorized" (401)

**Cause:** Token expired or invalid
**Solution:**
```bash
# Regenerate token
TOKEN=$(curl -k -s -X POST https://localhost:31443/nifi-api/access/token \
  -d "username=admin&password=changeme123456")
```

### Error: "Public port name must be unique" (409)

**Cause:** Port with same name already exists
**Solution:** Delete existing port or use different name

### Error: Port created but not in Site-to-Site endpoint

**Cause:** Port created inside Process Group (not root)
**Solution:** Ensure endpoint is `/process-groups/root/input-ports`

## References

- **API Library:** `automation/lib/nifi-api.sh`
- **Automation Script:** `automation/setup-site-to-site.sh`
- **NiFi REST API Docs:** https://nifi.apache.org/docs/nifi-docs/rest-api/
- **Architecture Decision:** `backlog/docs/doc-005 - NiFi-REST-API-Automation-Strategy.md`
<!-- SECTION:NOTES:END -->
