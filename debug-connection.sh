#!/bin/bash

CLUSTER02_URL="https://localhost:31443"
INPUT_PORT_ID="76b66c6e-019a-1000-ffff-ffffab669102"
PROCESSOR_ID="76bc577d-019a-1000-0000-0000769ce412"

# Get token
TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

echo "Creating connection: Input Port → Processor"
echo "Input Port ID: $INPUT_PORT_ID"
echo "Processor ID: $PROCESSOR_ID"
echo ""

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

echo "Raw response:"
echo "$CONN1_RESPONSE"
echo ""

echo "Parsed ID:"
echo "$CONN1_RESPONSE" | jq -r '.id' 2>&1 || echo "Failed to parse"
