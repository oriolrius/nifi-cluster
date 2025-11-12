#!/bin/bash

set -e

CLUSTER01_URL="https://localhost:30443"
HOST_IP="172.25.245.23"
CLUSTER02_PORT="31443"
RPG_ID="76ca555f-019a-1000-0000-00006d947e3e"

echo "=========================================="
echo "Recreating RPG with Host IP Address"
echo "=========================================="
echo ""

# Get token
echo "[1/3] Getting authentication token..."
TOKEN=$(curl -k -s -X POST "${CLUSTER01_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

# Delete old RPG
echo ""
echo "[2/3] Deleting old RPG (incorrect localhost URI)..."
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}")

VERSION=$(echo "$CURRENT" | jq -r '.revision.version')

curl -k -s -X DELETE -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}?version=${VERSION}&clientId=automated-script" \
  > /dev/null

echo "✓ Old RPG deleted"

# Create new RPG with host IP
echo ""
echo "[3/3] Creating new RPG with host IP address..."
NEW_TARGET="https://${HOST_IP}:${CLUSTER02_PORT}/nifi"
echo "  Target: $NEW_TARGET"

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
      \"comments\": \"Remote Process Group connecting to cluster02 for Site-to-Site\"
    }
  }")

NEW_RPG_ID=$(echo "$RPG_RESPONSE" | jq -r '.component.id')

if [ "$NEW_RPG_ID" == "null" ] || [ -z "$NEW_RPG_ID" ]; then
  echo "ERROR: Failed to create RPG"
  echo "$RPG_RESPONSE" | jq '.'
  exit 1
fi

echo "✓ RPG created: $NEW_RPG_ID"
echo ""
echo "Waiting 10 seconds for RPG to connect..."
sleep 10

# Verify connection
echo ""
echo "Verifying RPG connection..."
RPG_STATUS=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${NEW_RPG_ID}")

INPUT_COUNT=$(echo "$RPG_STATUS" | jq -r '.component.contents.inputPorts | length')
OUTPUT_COUNT=$(echo "$RPG_STATUS" | jq -r '.component.contents.outputPorts | length')

echo "Discovered Ports:"
echo "  Input Ports: $INPUT_COUNT"
echo "  Output Ports: $OUTPUT_COUNT"

if [ "$INPUT_COUNT" -gt 0 ] && [ "$OUTPUT_COUNT" -gt 0 ]; then
  echo ""
  echo "✓ SUCCESS! RPG connected and discovered ports"
  echo ""
  echo "$RPG_STATUS" | jq '{
    inputPorts: [.component.contents.inputPorts[] | {name: .name, targetRunning: .targetRunning}],
    outputPorts: [.component.contents.outputPorts[] | {name: .name, targetRunning: .targetRunning}]
  }'
else
  echo ""
  echo "⚠ RPG created but ports not discovered yet"
fi

# Save new RPG ID
cat > cluster01-rpg-id.txt <<EOF
RPG_ID=${NEW_RPG_ID}
CLUSTER01_URL=${CLUSTER01_URL}
TARGET_URI=https://${HOST_IP}:${CLUSTER02_PORT}/nifi
EOF

echo ""
echo "New RPG ID saved to: cluster01-rpg-id.txt"
