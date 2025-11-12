---
id: task-018
title: Create Output Port and processing flow in cluster02 via REST API
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 04:59'
labels:
  - site-to-site
  - cluster02
  - output-port
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a root-level Output Port in cluster02 that will send response data back to cluster01 via Site-to-Site protocol. This completes the request-response pattern between clusters.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Output Port named 'To-Cluster01-Response' created at root canvas in cluster02
- [ ] #2 Port is in RUNNING state
- [ ] #3 Port appears in cluster02's site-to-site endpoint outputPorts list
- [ ] #4 Port has access policy allowing 'send data via site-to-site'
- [ ] #5 Internal flow connects Input Port → processing → Output Port
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Automated Implementation

**This task is automated via REST API. No manual UI interaction required.**

### Quick Start

```bash
# Full Site-to-Site setup (includes this task):
./automation/setup-site-to-site.sh cluster01 cluster02

# Execution time: ~15 seconds
```

This script automatically:
1. Creates Output Port
2. Creates UpdateAttribute processor with response metadata
3. Creates connections (Input Port → UpdateAttribute → Output Port)
4. Starts all components

## Manual API Implementation (Step-by-Step)

### Prerequisites

```bash
# From task-017: Input Port already created and started
TOKEN=$(curl -k -s -X POST https://localhost:31443/nifi-api/access/token \
  -d "username=admin&password=changeme123456")
```

### Step 1: Create Output Port

```bash
OUTPUT_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://localhost:31443/nifi-api/process-groups/root/output-ports" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "name": "To-Cluster01-Response",
      "comments": "Sends processed response back to cluster01"
    }
  }')

OUTPUT_PORT_ID=$(echo "$OUTPUT_RESPONSE" | jq -r '.component.id')
echo "Output Port ID: $OUTPUT_PORT_ID"
```

### Step 2: Create UpdateAttribute Processor

```bash
PROCESSOR_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://localhost:31443/nifi-api/process-groups/root/processors" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "type": "org.apache.nifi.processors.attributes.UpdateAttribute",
      "name": "Add-Response-Metadata"
    }
  }')

PROCESSOR_ID=$(echo "$PROCESSOR_RESPONSE" | jq -r '.component.id')
echo "Processor ID: $PROCESSOR_ID"
```

### Step 3: Configure Processor Properties

```bash
# Get current processor state
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "https://localhost:31443/nifi-api/processors/${PROCESSOR_ID}")

VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

# Update with custom properties
curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://localhost:31443/nifi-api/processors/${PROCESSOR_ID}" \
  -d "{
    \"revision\": {\"version\": ${VERSION}},
    \"component\": {
      \"id\": \"${PROCESSOR_ID}\",
      \"config\": {
        \"properties\": {
          \"processed.by\": \"cluster02\",
          \"processed.timestamp\": \"\${now()}\",
          \"response.status\": \"SUCCESS\",
          \"response.cluster\": \"cluster02\"
        }
      }
    }
  }"

echo "Processor properties configured"
```

### Step 4: Create Connections

**Connection 1: Input Port → UpdateAttribute**

```bash
CONN1_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://localhost:31443/nifi-api/process-groups/root/connections" \
  -d "{
    \"revision\": {\"version\": 0},
    \"component\": {
      \"source\": {
        \"id\": \"${INPUT_PORT_ID}\",
        \"type\": \"INPUT_PORT\"
      },
      \"destination\": {
        \"id\": \"${PROCESSOR_ID}\",
        \"type\": \"PROCESSOR\"
      },
      \"selectedRelationships\": []
    }
  }")

CONN1_ID=$(echo "$CONN1_RESPONSE" | jq -r '.component.id')
echo "Connection 1 ID: $CONN1_ID"
```

**Connection 2: UpdateAttribute → Output Port**

```bash
CONN2_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://localhost:31443/nifi-api/process-groups/root/connections" \
  -d "{
    \"revision\": {\"version\": 0},
    \"component\": {
      \"source\": {
        \"id\": \"${PROCESSOR_ID}\",
        \"type\": \"PROCESSOR\"
      },
      \"destination\": {
        \"id\": \"${OUTPUT_PORT_ID}\",
        \"type\": \"OUTPUT_PORT\"
      },
      \"selectedRelationships\": [\"success\"]
    }
  }")

CONN2_ID=$(echo "$CONN2_RESPONSE" | jq -r '.component.id')
echo "Connection 2 ID: $CONN2_ID"
```

### Step 5: Start Components

**Start Processor:**
```bash
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "https://localhost:31443/nifi-api/processors/${PROCESSOR_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://localhost:31443/nifi-api/processors/${PROCESSOR_ID}/run-status" \
  -d "{\"revision\": {\"version\": ${VERSION}}, \"state\": \"RUNNING\"}"

echo "UpdateAttribute started"
```

**Start Output Port:**
```bash
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "https://localhost:31443/nifi-api/output-ports/${OUTPUT_PORT_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "https://localhost:31443/nifi-api/output-ports/${OUTPUT_PORT_ID}/run-status" \
  -d "{\"revision\": {\"version\": ${VERSION}}, \"state\": \"RUNNING\"}"

echo "Output Port started"
```

## Verification

### Complete Flow Check

```bash
# Get all components
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "https://localhost:31443/nifi-api/flow/process-groups/root" \
  | jq '{
    inputPorts: [.processGroupFlow.flow.inputPorts[] | {name: .component.name, state: .component.state}],
    processors: [.processGroupFlow.flow.processors[] | {name: .component.name, state: .component.state}],
    outputPorts: [.processGroupFlow.flow.outputPorts[] | {name: .component.name, state: .component.state}],
    connections: [.processGroupFlow.flow.connections[] | {source: .sourceId, dest: .destinationId}]
  }'
```

**Expected Output:**
```json
{
  "inputPorts": [
    {"name": "From-Cluster01-Request", "state": "RUNNING"}
  ],
  "processors": [
    {"name": "Add-Response-Metadata", "state": "RUNNING"}
  ],
  "outputPorts": [
    {"name": "To-Cluster01-Response", "state": "RUNNING"}
  ],
  "connections": [
    {"source": "<input-port-id>", "dest": "<processor-id>"},
    {"source": "<processor-id>", "dest": "<output-port-id>"}
  ]
}
```

### Site-to-Site Endpoint Check

```bash
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "https://localhost:31443/nifi-api/site-to-site" \
  | jq '{
    inputPorts: .controller.inputPorts,
    outputPorts: .controller.outputPorts
  }'
```

Both ports should appear in the S2S endpoint.

## Reusable Functions

From `automation/lib/nifi-api.sh`:

```bash
source automation/lib/nifi-api.sh

TOKEN=$(nifi_get_token "https://localhost:31443")

# Create components
OUTPUT_ID=$(nifi_create_output_port "$URL" "$TOKEN" "To-Cluster01-Response" "Response port")
PROC_ID=$(nifi_create_processor "$URL" "$TOKEN" "org.apache.nifi.processors.attributes.UpdateAttribute" "Add-Response-Metadata")

# Configure processor
nifi_update_processor_properties "$URL" "$TOKEN" "$PROC_ID" '{
  "processed.by": "cluster02",
  "processed.timestamp": "${now()}",
  "response.status": "SUCCESS"
}'

# Create connections
CONN1=$(nifi_create_connection "$URL" "$TOKEN" "$INPUT_ID" "INPUT_PORT" "$PROC_ID" "PROCESSOR" '[]')
CONN2=$(nifi_create_connection "$URL" "$TOKEN" "$PROC_ID" "PROCESSOR" "$OUTPUT_ID" "OUTPUT_PORT" '["success"]')

# Start components
nifi_start_component "$URL" "$TOKEN" "$PROC_ID" "processors"
nifi_start_component "$URL" "$TOKEN" "$OUTPUT_ID" "output-ports"
```

## Flow Architecture

```
┌─────────────────────────────────────────────────────────┐
│ cluster02 (Response Processing Flow)                   │
│                                                           │
│  [From-Cluster01-Request]  ← Input Port (task-017)     │
│           │                                               │
│           ↓                                               │
│  [Add-Response-Metadata]   ← UpdateAttribute           │
│   Properties:                                            │
│   - processed.by = "cluster02"                          │
│   - processed.timestamp = "${now()}"                    │
│   - response.status = "SUCCESS"                         │
│   - response.cluster = "cluster02"                      │
│           │                                               │
│           ↓                                               │
│  [To-Cluster01-Response]   ← Output Port                │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Technical Details

### UpdateAttribute Properties

NiFi Expression Language (EL) functions:
- `${now()}`: Current timestamp in milliseconds (Long)
- Returns: Unix epoch time (e.g., `1736653650456`)

### Connection Relationships

- **Input Port → Processor**: No relationships (empty array `[]`)
- **Processor → Output Port**: `["success"]` relationship required

### Component States

- `STOPPED`: Component exists but not running
- `RUNNING`: Component actively processing data
- `DISABLED`: Component cannot be started

## Troubleshooting

### Error: Cannot create connection - "source or destination not found"

**Cause:** Component IDs incorrect or components don't exist
**Solution:** Verify IDs with:
```bash
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "https://localhost:31443/nifi-api/flow/process-groups/root" \
  | jq '.processGroupFlow.flow | {inputPorts: [.inputPorts[].id], processors: [.processors[].id]}'
```

### Error: "Processor has unconnected relationships"

**Cause:** UpdateAttribute has `failure` relationship unconnected
**Solution:** This is acceptable - processor will error if attribute update fails

### Error: Output Port not in Site-to-Site endpoint

**Cause:** Port created in Process Group (not root)
**Solution:** Verify endpoint includes `/process-groups/root/output-ports`

## References

- **API Library:** `automation/lib/nifi-api.sh`  
- **Automation Script:** `automation/setup-site-to-site.sh`
- **Previous Task:** task-017 (Input Port creation)
- **Next Task:** task-019 (RPG configuration)
- **Architecture:** `backlog/docs/doc-005 - NiFi-REST-API-Automation-Strategy.md`
<!-- SECTION:NOTES:END -->
