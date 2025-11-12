#!/bin/bash

CLUSTER02_URL="https://localhost:31443"
PORT_ID="76b66c6e-019a-1000-ffff-ffffab669102"

# Get token
TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

# Check port state
echo "Current state of Input Port:"
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/input-ports/${PORT_ID}" \
  | jq '{id: .component.id, name: .component.name, state: .component.state, transmitting: .component.transmitting}'
