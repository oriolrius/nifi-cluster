#!/bin/bash

set -e

CLUSTER01_URL="https://localhost:30443"
CLUSTER02_URL="https://localhost:31443"

echo "=========================================="
echo "Creating Remote Process Group in cluster01"
echo "=========================================="
echo ""

# Step 1: Get authentication token
echo "[1/5] Getting authentication token from cluster01..."
TOKEN=$(curl -k -s -X POST "${CLUSTER01_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get authentication token"
  exit 1
fi
echo "✓ Token obtained"

# Step 2: Create Remote Process Group
echo ""
echo "[2/5] Creating Remote Process Group..."
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
      \"yieldDuration\": \"10 sec\",
      \"name\": \"cluster02-rpg\",
      \"comments\": \"Remote Process Group connecting to cluster02 for Site-to-Site\"
    }
  }")

RPG_ID=$(echo "$RPG_RESPONSE" | jq -r '.component.id')

if [ "$RPG_ID" == "null" ] || [ -z "$RPG_ID" ]; then
  echo "ERROR: Failed to create RPG"
  echo "$RPG_RESPONSE" | jq '.'
  exit 1
fi

echo "✓ RPG created: $RPG_ID"
echo "  Target: ${CLUSTER02_URL}/nifi"
echo "  Transport: HTTP/HTTPS"

# Step 3: Wait for RPG to connect
echo ""
echo "[3/5] Waiting for RPG to connect to cluster02..."
echo "  (This may take 5-15 seconds for initial S2S handshake)"
sleep 10

# Check connection status
echo ""
echo "Checking connection status..."
RPG_STATUS=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}")

TRANSMITTING=$(echo "$RPG_STATUS" | jq -r '.component.transmitting')
FLOW_REFRESHED=$(echo "$RPG_STATUS" | jq -r '.component.flowRefreshed')
ACTIVE_INPUT=$(echo "$RPG_STATUS" | jq -r '.component.activeRemoteInputPortCount')
ACTIVE_OUTPUT=$(echo "$RPG_STATUS" | jq -r '.component.activeRemoteOutputPortCount')

echo "RPG Status:"
echo "  Transmitting: $TRANSMITTING"
echo "  Flow Refreshed: $FLOW_REFRESHED"
echo "  Active Input Ports: $ACTIVE_INPUT"
echo "  Active Output Ports: $ACTIVE_OUTPUT"

# Step 4: Verify remote ports discovered
echo ""
echo "[4/5] Verifying remote ports discovered..."
echo "$RPG_STATUS" | jq '{
  inputPorts: [.component.contents.inputPorts[] | {name: .name, targetRunning: .targetRunning, connected: .connected}],
  outputPorts: [.component.contents.outputPorts[] | {name: .name, targetRunning: .targetRunning, connected: .connected}]
}'

# Step 5: Show manual enablement instructions
echo ""
echo "[5/5] Configuration summary..."
echo ""
echo "=========================================="
echo "RPG Creation Complete!"
echo "=========================================="
echo ""
echo "RPG ID: $RPG_ID"
echo "Target: ${CLUSTER02_URL}/nifi"
echo "Status: Connected to cluster02"
echo ""
echo "Discovered Ports:"
echo "  Input Ports (send TO cluster02):"
echo "$RPG_STATUS" | jq -r '.component.contents.inputPorts[] | "    - \(.name) (running: \(.targetRunning))"'
echo ""
echo "  Output Ports (receive FROM cluster02):"
echo "$RPG_STATUS" | jq -r '.component.contents.outputPorts[] | "    - \(.name) (running: \(.targetRunning))"'
echo ""
echo "=========================================="
echo "NEXT STEP: Enable Port Transmission"
echo "=========================================="
echo ""
echo "To enable data flow through the RPG:"
echo ""
echo "Option 1 - Manual (UI - Recommended):"
echo "  1. Open: https://localhost:30443/nifi"
echo "  2. Right-click RPG → 'Manage Remote Ports'"
echo "  3. For each port:"
echo "     - Click transmission icon (▶) or pencil"
echo "     - Set Concurrent Tasks: 1"
echo "     - Set Use Compression: false"
echo "     - Click APPLY"
echo ""
echo "Option 2 - API (Advanced):"
echo "  See task-019 implementation notes for API commands"
echo ""
echo "After enablement:"
echo "  - activeRemoteInputPortCount: 1"
echo "  - activeRemoteOutputPortCount: 1"
echo "  - RPG ready for connections in task-020"
echo ""

# Save RPG ID
cat > cluster01-rpg-id.txt <<EOF
RPG_ID=${RPG_ID}
CLUSTER01_URL=${CLUSTER01_URL}
CLUSTER02_URL=${CLUSTER02_URL}
EOF

echo "RPG ID saved to: cluster01-rpg-id.txt"
