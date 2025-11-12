#!/bin/bash

CLUSTER02_URL="https://localhost:31443"
PORT_ID="76b66c6e-019a-1000-ffff-ffffab669102"

# Get token
echo "Getting token..."
TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

echo "Token: ${TOKEN:0:50}..."

# Get current port info to get revision
echo ""
echo "Getting current port info..."
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${PORT_ID}")

VERSION=$(echo "$CURRENT" | jq -r '.revision.version')
echo "Current version: $VERSION"
echo "Current state: $(echo "$CURRENT" | jq -r '.component.state')"

# Start the port
echo ""
echo "Starting port..."
START_RESPONSE=$(curl -k -s -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${PORT_ID}/run-status" \
  -d "{
    \"revision\": {
      \"version\": ${VERSION}
    },
    \"state\": \"RUNNING\"
  }")

echo ""
echo "Response:"
echo "$START_RESPONSE" | jq '{id: .component.id, name: .component.name, state: .component.state}'

# Verify final state
echo ""
echo "Final verification:"
sleep 2
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${PORT_ID}" \
  | jq '{id: .component.id, name: .component.name, state: .component.state, transmitting: .component.transmitting}'
