#!/bin/bash

set -e  # Exit on any error

CLUSTER02_URL="https://localhost:31443"
INPUT_PORT_ID="76b66c6e-019a-1000-ffff-ffffab669102"  # From task 17

echo "=========================================="
echo "Creating cluster02 Processing Flow"
echo "=========================================="
echo ""

# Step 1: Get authentication token
echo "[1/9] Getting authentication token..."
TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get authentication token"
  exit 1
fi
echo "✓ Token obtained"

# Step 2: Create Output Port
echo ""
echo "[2/9] Creating Output Port 'To-Cluster01-Response'..."
OUTPUT_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/process-groups/root/output-ports" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "name": "To-Cluster01-Response",
      "comments": "Sends processed response back to cluster01 via Site-to-Site"
    }
  }')

OUTPUT_PORT_ID=$(echo "$OUTPUT_RESPONSE" | jq -r '.component.id')

if [ "$OUTPUT_PORT_ID" == "null" ] || [ -z "$OUTPUT_PORT_ID" ]; then
  echo "ERROR: Failed to create Output Port"
  echo "$OUTPUT_RESPONSE" | jq '.'
  exit 1
fi
echo "✓ Output Port created: $OUTPUT_PORT_ID"

# Step 3: Create UpdateAttribute Processor
echo ""
echo "[3/9] Creating UpdateAttribute processor..."
PROCESSOR_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/process-groups/root/processors" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "type": "org.apache.nifi.processors.attributes.UpdateAttribute",
      "name": "Add-Response-Metadata",
      "config": {
        "schedulingPeriod": "0 sec",
        "schedulingStrategy": "TIMER_DRIVEN",
        "executionNode": "ALL",
        "concurrentlySchedulableTaskCount": "1"
      }
    }
  }')

PROCESSOR_ID=$(echo "$PROCESSOR_RESPONSE" | jq -r '.component.id')

if [ "$PROCESSOR_ID" == "null" ] || [ -z "$PROCESSOR_ID" ]; then
  echo "ERROR: Failed to create processor"
  echo "$PROCESSOR_RESPONSE" | jq '.'
  exit 1
fi
echo "✓ Processor created: $PROCESSOR_ID"

# Step 4: Configure Processor Properties
echo ""
echo "[4/9] Configuring processor properties..."
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/processors/${PROCESSOR_ID}")

VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

CONFIG_RESPONSE=$(curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/processors/${PROCESSOR_ID}" \
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
  }")

echo "✓ Processor properties configured"

# Step 5: Create Connection 1 (Input Port → Processor)
echo ""
echo "[5/9] Creating connection: Input Port → UpdateAttribute..."
CONN1_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/process-groups/root/connections" \
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

CONN1_ID=$(echo "$CONN1_RESPONSE" | jq -r '.id')

if [ "$CONN1_ID" == "null" ] || [ -z "$CONN1_ID" ]; then
  echo "ERROR: Failed to create connection 1"
  echo "$CONN1_RESPONSE" | jq '.'
  exit 1
fi
echo "✓ Connection 1 created: $CONN1_ID"

# Step 6: Create Connection 2 (Processor → Output Port)
echo ""
echo "[6/9] Creating connection: UpdateAttribute → Output Port..."
CONN2_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/process-groups/root/connections" \
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

CONN2_ID=$(echo "$CONN2_RESPONSE" | jq -r '.id')

if [ "$CONN2_ID" == "null" ] || [ -z "$CONN2_ID" ]; then
  echo "ERROR: Failed to create connection 2"
  echo "$CONN2_RESPONSE" | jq '.'
  exit 1
fi
echo "✓ Connection 2 created: $CONN2_ID"

# Step 7: Start Input Port (if not already running)
echo ""
echo "[7/9] Starting Input Port..."
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${INPUT_PORT_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')
STATE=$(echo "$CURRENT" | jq -r '.component.state')

if [ "$STATE" != "RUNNING" ]; then
  curl -k -s -X PUT \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "${CLUSTER02_URL}/nifi-api/input-ports/${INPUT_PORT_ID}/run-status" \
    -d "{\"revision\": {\"version\": ${VERSION}}, \"state\": \"RUNNING\"}" > /dev/null
  echo "✓ Input Port started"
else
  echo "✓ Input Port already running"
fi

# Step 8: Start Processor
echo ""
echo "[8/9] Starting UpdateAttribute processor..."
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/processors/${PROCESSOR_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/processors/${PROCESSOR_ID}/run-status" \
  -d "{\"revision\": {\"version\": ${VERSION}}, \"state\": \"RUNNING\"}" > /dev/null

echo "✓ Processor started"

# Step 9: Start Output Port
echo ""
echo "[9/9] Starting Output Port..."
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/output-ports/${OUTPUT_PORT_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/output-ports/${OUTPUT_PORT_ID}/run-status" \
  -d "{\"revision\": {\"version\": ${VERSION}}, \"state\": \"RUNNING\"}" > /dev/null

echo "✓ Output Port started"

# Summary
echo ""
echo "=========================================="
echo "Flow Creation Complete!"
echo "=========================================="
echo ""
echo "Component IDs:"
echo "  Input Port:  $INPUT_PORT_ID"
echo "  Processor:   $PROCESSOR_ID"
echo "  Output Port: $OUTPUT_PORT_ID"
echo ""
echo "Connection IDs:"
echo "  Conn 1:      $CONN1_ID"
echo "  Conn 2:      $CONN2_ID"
echo ""
echo "Flow: [From-Cluster01-Request] → [Add-Response-Metadata] → [To-Cluster01-Response]"
echo ""

# Save IDs for later use
cat > cluster02-flow-ids.txt <<EOF
INPUT_PORT_ID=${INPUT_PORT_ID}
PROCESSOR_ID=${PROCESSOR_ID}
OUTPUT_PORT_ID=${OUTPUT_PORT_ID}
CONN1_ID=${CONN1_ID}
CONN2_ID=${CONN2_ID}
EOF

echo "Component IDs saved to: cluster02-flow-ids.txt"
