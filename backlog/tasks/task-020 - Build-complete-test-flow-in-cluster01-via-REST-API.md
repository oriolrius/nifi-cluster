---
id: task-020
title: Build complete test flow in cluster01 via REST API
status: To Do
assignee: []
created_date: '2025-11-12 04:34'
updated_date: '2025-11-12 05:02'
labels:
  - site-to-site
  - cluster01
  - end-to-end-flow
  - demo
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a complete end-to-end flow in cluster01 that: (1) generates sample data, (2) sends it to cluster02 via RPG, (3) receives the processed response back from cluster02, and (4) logs the result. This demonstrates bidirectional inter-cluster communication using Site-to-Site protocol.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GenerateFlowFile processor creates test data in cluster01
- [ ] #2 Data flows through RPG to cluster02 input port
- [ ] #3 cluster02 processes data and sends response to output port
- [ ] #4 RPG receives response from cluster02 output port
- [ ] #5 LogAttribute processor in cluster01 displays the response with cluster02 metadata
- [ ] #6 Complete flow verified with test data showing round-trip timestamps
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Automated Implementation

**This task is ~80% automated via REST API. Some manual connection steps required (see Known Limitations).**

### Quick Start

```bash
# Full Site-to-Site setup (includes this task):
./automation/setup-site-to-site.sh cluster01 cluster02

# Execution time: ~20 seconds
```

**What it automates:**
- Creates GenerateFlowFile processor
- Creates UpdateAttribute processor (request metadata)
- Creates LogAttribute processor
- Configures all processor properties
- Creates connection: GenerateFlowFile → UpdateAttribute
- Starts processors (except GenerateFlowFile)

**Manual steps required:**
- Connect UpdateAttribute → RPG input port
- Connect RPG output port → LogAttribute
- Connect LogAttribute → Terminate/Funnel
- Start GenerateFlowFile processor

## Manual API Implementation

### Prerequisites

```bash
CLUSTER01_URL="https://localhost:30443"

TOKEN=$(curl -k -s -X POST "${CLUSTER01_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

# From task-019: RPG already created
RPG_ID="<rpg-id-from-task-019>"
```

### Step 1: Create GenerateFlowFile Processor

```bash
GEN_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/process-groups/root/processors" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "type": "org.apache.nifi.processors.standard.GenerateFlowFile",
      "name": "Generate-Test-Data"
    }
  }')

GEN_ID=$(echo "$GEN_RESPONSE" | jq -r '.component.id')
echo "GenerateFlowFile ID: $GEN_ID"
```

### Step 2: Configure GenerateFlowFile Properties

```bash
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/processors/${GEN_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/processors/${GEN_ID}" \
  -d "{
    \"revision\": {\"version\": ${VERSION}},
    \"component\": {
      \"id\": \"${GEN_ID}\",
      \"config\": {
        \"properties\": {
          \"File Size\": \"0B\",
          \"Batch Size\": \"1\",
          \"Data Format\": \"Text\",
          \"Custom Text\": \"{\\\"message\\\": \\\"Hello from cluster01\\\", \\\"timestamp\\\": \\\"\${now()}\\\", \\\"test\\\": \\\"inter-cluster-s2s\\\"}\"
        },
        \"schedulingPeriod\": \"30 sec\"
      }
    }
  }"

echo "GenerateFlowFile configured"
```

### Step 3: Create UpdateAttribute Processor (Request Metadata)

```bash
UPDATE_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/process-groups/root/processors" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "type": "org.apache.nifi.processors.attributes.UpdateAttribute",
      "name": "Add-Request-Metadata"
    }
  }')

UPDATE_ID=$(echo "$UPDATE_RESPONSE" | jq -r '.component.id')
echo "UpdateAttribute ID: $UPDATE_ID"
```

### Step 4: Configure UpdateAttribute Properties

```bash
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/processors/${UPDATE_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/processors/${UPDATE_ID}" \
  -d "{
    \"revision\": {\"version\": ${VERSION}},
    \"component\": {
      \"id\": \"${UPDATE_ID}\",
      \"config\": {
        \"properties\": {
          \"request.id\": \"\${UUID()}\",
          \"request.timestamp\": \"\${now()}\",
          \"source.cluster\": \"cluster01\",
          \"request.type\": \"test-s2s\"
        }
      }
    }
  }"

echo "UpdateAttribute configured"
```

### Step 5: Create LogAttribute Processor

```bash
LOG_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/process-groups/root/processors" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "type": "org.apache.nifi.processors.standard.LogAttribute",
      "name": "Log-Response"
    }
  }')

LOG_ID=$(echo "$LOG_RESPONSE" | jq -r '.component.id')
echo "LogAttribute ID: $LOG_ID"
```

### Step 6: Configure LogAttribute Properties

```bash
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/processors/${LOG_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/processors/${LOG_ID}" \
  -d "{
    \"revision\": {\"version\": ${VERSION}},
    \"component\": {
      \"id\": \"${LOG_ID}\",
      \"config\": {
        \"properties\": {
          \"Log Level\": \"info\",
          \"Log Payload\": \"true\",
          \"Attributes to Log\": \"\",
          \"Attributes to Log by Regular Expression\": \".*\",
          \"Log prefix\": \"[RESPONSE FROM CLUSTER02]\"
        }
      }
    }
  }"

echo "LogAttribute configured"
```

### Step 7: Create Automated Connection

**GenerateFlowFile → UpdateAttribute:**

```bash
CONN_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/process-groups/root/connections" \
  -d "{
    \"revision\": {\"version\": 0},
    \"component\": {
      \"source\": {
        \"id\": \"${GEN_ID}\",
        \"type\": \"PROCESSOR\"
      },
      \"destination\": {
        \"id\": \"${UPDATE_ID}\",
        \"type\": \"PROCESSOR\"
      },
      \"selectedRelationships\": [\"success\"]
    }
  }")

CONN_ID=$(echo "$CONN_RESPONSE" | jq -r '.component.id')
echo "Connection created: $CONN_ID"
```

### Step 8: Manual Connections to/from RPG

**Known Limitation:** Connections to/from RPG require remote port IDs which are complex to retrieve programmatically.

**Manual steps required (via UI):**

1. Open cluster01 NiFi UI: https://localhost:30443/nifi

2. **Connection: UpdateAttribute → RPG Input Port**
   - Hover over UpdateAttribute processor
   - Drag connection arrow to RPG component
   - In dialog, select:
     - Relationship: `success`
     - Connect to Remote Input Port: `From-Cluster01-Request`
   - Click ADD

3. **Connection: RPG Output Port → LogAttribute**
   - Hover over RPG component (right-side port icon)
   - Drag connection from RPG to LogAttribute
   - In dialog:
     - From Remote Output Port: `To-Cluster01-Response`
   - Click ADD

4. **Connection: LogAttribute → Terminate**
   - Create Funnel or TerminateFlowFile processor
   - Connect LogAttribute → Terminate
   - Relationship: `success`

### Step 9: Start Processors

```bash
# Start UpdateAttribute
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/processors/${UPDATE_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/processors/${UPDATE_ID}/run-status" \
  -d "{\"revision\": {\"version\": ${VERSION}}, \"state\": \"RUNNING\"}"

# Start LogAttribute
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/processors/${LOG_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/processors/${LOG_ID}/run-status" \
  -d "{\"revision\": {\"version\": ${VERSION}}, \"state\": \"RUNNING\"}"

# DO NOT start GenerateFlowFile yet (wait for RPG connections)
echo "UpdateAttribute and LogAttribute started"
echo "GenerateFlowFile NOT started (prevents data flow until connections complete)"
```

### Step 10: Start Data Generation (After Manual Connections)

Once manual RPG connections are complete:

```bash
# Start GenerateFlowFile
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/processors/${GEN_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/processors/${GEN_ID}/run-status" \
  -d "{\"revision\": {\"version\": ${VERSION}}, \"state\": \"RUNNING\"}"

echo "GenerateFlowFile started - data flow active"
```

## Complete Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ cluster01 (Request/Response Flow)                          │
│                                                               │
│  [GenerateFlowFile] → [UpdateAttribute] → [RPG:Input]      │
│   Generate test        Add request         Send to          │
│   data every 30s       metadata            cluster02        │
│                                                ↓              │
│                                          (HTTPS S2S)         │
│                                                ↓              │
└────────────────────────────────────────────────┬─────────────┘
                                                 │
                    ┌────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────┐
│ cluster02 (Remote Processing)                              │
│  [Input] → [UpdateAttribute] → [Output]                    │
│           Add response metadata                             │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────┘
              ↓
┌─────────────────────────────────────────────────────────────┐
│ cluster01 (Response Handling)                              │
│                                                               │
│  [RPG:Output] → [LogAttribute] → [Terminate]               │
│   Receive        Display          Delete                    │
│   response       combined         flowfile                  │
│                  metadata                                    │
└─────────────────────────────────────────────────────────────┘
```

## Verification

### Watch Logs for Response

```bash
# Monitor LogAttribute output
docker compose -f docker-compose-cluster01.yml logs -f nifi-1 \
  | grep -A 20 "RESPONSE FROM CLUSTER02"
```

**Expected output every 30 seconds:**
```
[RESPONSE FROM CLUSTER02]
Standard FlowFile Attributes
Key: 'filename'
  Value: '...'

Additional FlowFile Attributes:
Key: 'request.id'
  Value: 'a1b2c3d4-...'
Key: 'request.timestamp'
  Value: '1736653650123'
Key: 'source.cluster'
  Value: 'cluster01'
Key: 'processed.by'
  Value: 'cluster02'
Key: 'processed.timestamp'
  Value: '1736653650456'
Key: 'response.status'
  Value: 'SUCCESS'

FlowFile Content:
{"message": "Hello from cluster01", "timestamp": "1736653650123", "test": "inter-cluster-s2s"}
```

**Key verification:**
- ✓ `source.cluster: cluster01` (added by cluster01)
- ✓ `processed.by: cluster02` (added by cluster02)
- ✓ Both timestamps present (request + processed)
- ✓ Round-trip time < 1 second

### Check RPG Statistics

```bash
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/flow/process-groups/root" \
  | jq '.processGroupFlow.flow.remoteProcessGroups[] | {
    sent: .status.aggregateSnapshot.sent,
    received: .status.aggregateSnapshot.received,
    transmitting: .component.transmitting
  }'
```

**Expected:**
```json
{
  "sent": "10 (2.0 KB)",
  "received": "10 (2.2 KB)",
  "transmitting": true
}
```

### Visual Monitoring (UI)

Open https://localhost:30443/nifi:
- GenerateFlowFile: Creating data every 30 seconds
- Connections briefly show `1 / 1` then clear to `0 / 0`
- RPG shows: `Sent: X / Received: X` (incrementing)
- No data stuck in queues

## Reusable Functions

From `automation/lib/nifi-api.sh`:

```bash
source automation/lib/nifi-api.sh

TOKEN=$(nifi_get_token "https://localhost:30443")

# Create processors
GEN_ID=$(nifi_create_processor "$URL" "$TOKEN" \
    "org.apache.nifi.processors.standard.GenerateFlowFile" "Generate-Test-Data")

UPDATE_ID=$(nifi_create_processor "$URL" "$TOKEN" \
    "org.apache.nifi.processors.attributes.UpdateAttribute" "Add-Request-Metadata")

LOG_ID=$(nifi_create_processor "$URL" "$TOKEN" \
    "org.apache.nifi.processors.standard.LogAttribute" "Log-Response")

# Configure properties
nifi_update_processor_properties "$URL" "$TOKEN" "$GEN_ID" '{
  "File Size": "0B",
  "Custom Text": "{\"message\": \"Hello\", \"test\": \"s2s\"}"
}'

# Create connection
CONN=$(nifi_create_connection "$URL" "$TOKEN" \
    "$GEN_ID" "PROCESSOR" "$UPDATE_ID" "PROCESSOR" '["success"]')

# Start (except GenerateFlowFile)
nifi_start_component "$URL" "$TOKEN" "$UPDATE_ID" "processors"
nifi_start_component "$URL" "$TOKEN" "$LOG_ID" "processors"
```

## Known Limitations

### Manual RPG Connections Required

**Why:** NiFi REST API requires:
- Remote port IDs from RPG's discovered ports
- Complex connection type: `REMOTE_INPUT_PORT` / `REMOTE_OUTPUT_PORT`
- Port mapping between local and remote IDs

**Current workaround:** Manual UI connections (Steps 2-4 in Step 8) - takes ~2 minutes.

**Future improvement:** Full API automation with port ID discovery.

## Performance Expectations

- **Data generation:** 2 files/minute (30-second interval)
- **Round-trip time:** 100-300ms (typically < 1 second)
- **Queue buildup:** None (0 / 0 on all connections)
- **Memory usage:** Minimal (~200 bytes per flowfile)

## Troubleshooting

### No Data Flowing to cluster02

**Check:**
1. GenerateFlowFile started? (should be green)
2. UpdateAttribute started?
3. Connection to RPG created?
4. RPG transmission enabled? (task-019)

**Debug:**
```bash
# Check processor states
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/flow/process-groups/root" \
  | jq '.processGroupFlow.flow.processors[] | {name: .component.name, state: .component.state}'
```

### No Response from cluster02

**Check:**
1. cluster02 flow running? (task-018)
2. RPG output port enabled? (task-019)
3. Connection from RPG to LogAttribute created?

**Debug:**
```bash
# Check RPG status
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}" \
  | jq '{transmitting: .component.transmitting, sent: .status.aggregateSnapshot.sent}'
```

### Data Stuck in Queues

**Check back-pressure:**
- Right-click connection → View configuration
- Increase thresholds if needed

**Monitor:**
```bash
# Check queue sizes
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/flow/process-groups/root" \
  | jq '.processGroupFlow.flow.connections[] | {
    source: .sourceId,
    dest: .destinationId,
    queued: .status.aggregateSnapshot.queued
  }'
```

### LogAttribute Not Showing Attributes

**Check configuration:**
- Log Payload: must be `true`
- Attributes to Log by Regular Expression: must be `.*`
- Log Level: must be `info` or lower

## References

- **API Library:** `automation/lib/nifi-api.sh`
- **Automation Script:** `automation/setup-site-to-site.sh`
- **Previous Tasks:** task-017, task-018, task-019
- **Architecture:** `backlog/docs/doc-005 - NiFi-REST-API-Automation-Strategy.md`
- **Evidence:** `API-AUTOMATION-EVIDENCE.md`
<!-- SECTION:NOTES:END -->
