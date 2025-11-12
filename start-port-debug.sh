#!/bin/bash

CLUSTER02_URL="https://localhost:31443"
PORT_ID="76b66c6e-019a-1000-ffff-ffffab669102"

# Get token
TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

# Get current port info to get revision
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${PORT_ID}")

VERSION=$(echo "$CURRENT" | jq -r '.revision.version')
echo "Current version: $VERSION"

# Start the port with full response
echo ""
echo "Full start response:"
curl -k -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${PORT_ID}/run-status" \
  -d "{
    \"revision\": {
      \"version\": ${VERSION}
    },
    \"state\": \"RUNNING\"
  }"

echo ""
