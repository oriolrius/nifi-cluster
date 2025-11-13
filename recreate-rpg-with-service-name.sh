#!/bin/bash

set -e

CLUSTER01_URL="https://localhost:30443"
CLUSTER02_SERVICE="cluster02.nifi-1"
CLUSTER02_PORT="8443"
OLD_RPG_ID="76ccef2c-019a-1000-ffff-ffff809a40c9"

echo "=========================================="
echo "Recreating RPG with Docker Service Name"
echo "=========================================="
echo ""

# Get token
echo "[1/4] Getting authentication token..."
TOKEN=$(curl -k -s -X POST "${CLUSTER01_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

# Check if old RPG exists and delete it
echo ""
echo "[2/4] Checking for old RPG..."
OLD_RPG=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${OLD_RPG_ID}" 2>/dev/null || echo "null")

if echo "$OLD_RPG" | jq -e '.component.id' > /dev/null 2>&1; then
  echo "  Found old RPG, deleting..."
  VERSION=$(echo "$OLD_RPG" | jq -r '.revision.version')
  curl -k -s -X DELETE -H "Authorization: Bearer ${TOKEN}" \
    "${CLUSTER01_URL}/nifi-api/remote-process-groups/${OLD_RPG_ID}?version=${VERSION}&clientId=automated-script" \
    > /dev/null
  echo "  ✓ Old RPG deleted"
else
  echo "  No old RPG found (expected after restart)"
fi

# Create new RPG with Docker service name
echo ""
echo "[3/4] Creating new RPG with inter-cluster-network service name..."
NEW_TARGET="https://${CLUSTER02_SERVICE}:${CLUSTER02_PORT}/nifi"
echo "  Target: $NEW_TARGET"
echo "  Note: Using Docker service name from inter-cluster-network"

RPG_RESPONSE=$(curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/process-groups/root/remote-process-groups" \
  -d "{
    \"revision\": {\"version\": 0},
    \"component\": {
      \"targetUri\": \"${NEW_TARGET}\",
      \"transportProtocol\": \"HTTP\",
      \"communicationsTimeout\": \"30 sec\",
      \"yieldDuration\": \"10 sec\",
      \"name\": \"cluster02-rpg\",
      \"comments\": \"Remote Process Group connecting to cluster02 via inter-cluster-network for Site-to-Site\"
    }
  }")

NEW_RPG_ID=$(echo "$RPG_RESPONSE" | jq -r '.component.id')

if [ "$NEW_RPG_ID" == "null" ] || [ -z "$NEW_RPG_ID" ]; then
  echo "ERROR: Failed to create RPG"
  echo "$RPG_RESPONSE" | jq '.'
  exit 1
fi

echo "  ✓ RPG created: $NEW_RPG_ID"
echo ""
echo "Waiting 15 seconds for RPG to connect..."
sleep 15

# Verify connection
echo ""
echo "[4/4] Verifying RPG connection and port discovery..."
RPG_STATUS=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${NEW_RPG_ID}")

INPUT_COUNT=$(echo "$RPG_STATUS" | jq -r '.component.contents.inputPorts | length')
OUTPUT_COUNT=$(echo "$RPG_STATUS" | jq -r '.component.contents.outputPorts | length')

echo "Discovered Ports:"
echo "  Input Ports: $INPUT_COUNT"
echo "  Output Ports: $OUTPUT_COUNT"

if [ "$INPUT_COUNT" -gt 0 ] && [ "$OUTPUT_COUNT" -gt 0 ]; then
  echo ""
  echo "✓ SUCCESS! RPG connected and discovered ports via inter-cluster-network"
  echo ""
  echo "$RPG_STATUS" | jq '{
    inputPorts: [.component.contents.inputPorts[] | {name: .name, targetRunning: .targetRunning}],
    outputPorts: [.component.contents.outputPorts[] | {name: .name, targetRunning: .targetRunning}]
  }'
else
  echo ""
  echo "⚠ RPG created but ports not discovered yet (may need more time)"
  echo ""
  echo "Connection status:"
  echo "$RPG_STATUS" | jq '{
    targetUri: .component.targetUri,
    transmitting: .component.transmitting,
    validationErrors: .component.validationErrors
  }'
fi

# Save new RPG ID
cat > cluster01-rpg-id.txt <<IDEOF
RPG_ID=${NEW_RPG_ID}
CLUSTER01_URL=${CLUSTER01_URL}
TARGET_URI=${NEW_TARGET}
IDEOF

echo ""
echo "New RPG ID saved to: cluster01-rpg-id.txt"
