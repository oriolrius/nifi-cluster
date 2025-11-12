#!/bin/bash

set -e

CLUSTER02_URL="https://localhost:31443"
INPUT_PORT_ID="76b66c6e-019a-1000-ffff-ffffab669102"
PROCESSOR_ID="76bc577d-019a-1000-0000-0000769ce412"
OUTPUT_PORT_ID="76bc5724-019a-1000-ffff-ffffdc2c4902"

# Get token
TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

echo "Starting cluster02 flow components..."
echo ""

# Start Input Port
echo "[1/3] Starting Input Port..."
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

# Start Processor
echo ""
echo "[2/3] Starting UpdateAttribute processor..."
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/processors/${PROCESSOR_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')
STATE=$(echo "$CURRENT" | jq -r '.component.state')

if [ "$STATE" != "RUNNING" ]; then
  curl -k -s -X PUT \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "${CLUSTER02_URL}/nifi-api/processors/${PROCESSOR_ID}/run-status" \
    -d "{\"revision\": {\"version\": ${VERSION}}, \"state\": \"RUNNING\"}" > /dev/null
  echo "✓ Processor started"
else
  echo "✓ Processor already running"
fi

# Start Output Port
echo ""
echo "[3/3] Starting Output Port..."
CURRENT=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/output-ports/${OUTPUT_PORT_ID}")
VERSION=$(echo "$CURRENT" | jq -r '.revision.version')
STATE=$(echo "$CURRENT" | jq -r '.component.state')

if [ "$STATE" != "RUNNING" ]; then
  curl -k -s -X PUT \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    "${CLUSTER02_URL}/nifi-api/output-ports/${OUTPUT_PORT_ID}/run-status" \
    -d "{\"revision\": {\"version\": ${VERSION}}, \"state\": \"RUNNING\"}" > /dev/null
  echo "✓ Output Port started"
else
  echo "✓ Output Port already running"
fi

echo ""
echo "All components started successfully!"
