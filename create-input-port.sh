#!/bin/bash

CLUSTER02_URL="https://localhost:31443"

# Step 1: Get authentication token
echo "Getting authentication token..."
TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get authentication token"
  exit 1
fi

echo "Token obtained: ${TOKEN:0:50}..."

# Step 2: Create Input Port
echo ""
echo "Creating Input Port..."
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

if [ "$INPUT_PORT_ID" == "null" ] || [ -z "$INPUT_PORT_ID" ]; then
  echo "ERROR: Failed to create Input Port"
  echo "Response: $INPUT_PORT_RESPONSE" | jq '.'
  exit 1
fi

echo "Input Port Created: $INPUT_PORT_ID"
echo "$INPUT_PORT_RESPONSE" | jq '{id: .component.id, name: .component.name, state: .component.state, parentGroupId: .component.parentGroupId}'

# Step 3: Start the Input Port
echo ""
echo "Starting Input Port..."

# Get current revision
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${INPUT_PORT_ID}")

VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

# Start the port
START_RESPONSE=$(curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${INPUT_PORT_ID}/run-status" \
  -d "{
    \"revision\": {\"version\": ${VERSION}},
    \"state\": \"RUNNING\"
  }")

echo "Input Port Started"
echo "$START_RESPONSE" | jq '{id: .component.id, name: .component.name, state: .component.state}'

# Step 4: Verify port in root canvas
echo ""
echo "Verifying port in root canvas..."
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/flow/process-groups/root" \
  | jq '.processGroupFlow.flow.inputPorts[] | {name: .component.name, state: .component.state, id: .id}'

# Step 5: Verify port in site-to-site endpoint
echo ""
echo "Verifying port in site-to-site endpoint..."
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/site-to-site" \
  | jq '.controller.inputPorts[] | {name: .name, id: .id}'

echo ""
echo "SUCCESS: Input Port created and started!"
