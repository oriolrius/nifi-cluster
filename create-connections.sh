#!/bin/bash

set -e

CLUSTER02_URL="https://localhost:31443"
INPUT_PORT_ID="76b66c6e-019a-1000-ffff-ffffab669102"
PROCESSOR_ID="76bc577d-019a-1000-0000-0000769ce412"
OUTPUT_PORT_ID="76bc5724-019a-1000-ffff-ffffdc2c4902"

# Get token
TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

echo "Creating connections for cluster02 flow..."
echo ""

# Connection 1: Input Port → Processor
echo "[1/2] Creating: Input Port → UpdateAttribute..."

CONN1_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/process-groups/root/connections" \
  -d "{
    \"revision\": {
      \"version\": 0
    },
    \"component\": {
      \"source\": {
        \"id\": \"${INPUT_PORT_ID}\",
        \"groupId\": \"root\",
        \"type\": \"INPUT_PORT\"
      },
      \"destination\": {
        \"id\": \"${PROCESSOR_ID}\",
        \"groupId\": \"root\",
        \"type\": \"PROCESSOR\"
      },
      \"selectedRelationships\": [],
      \"backPressureDataSizeThreshold\": \"1 GB\",
      \"backPressureObjectThreshold\": 10000,
      \"flowFileExpiration\": \"0 sec\",
      \"prioritizers\": []
    }
  }")

HTTP_CODE=$(echo "$CONN1_RESPONSE" | tail -n1)
BODY=$(echo "$CONN1_RESPONSE" | sed '$ d')

if [ "$HTTP_CODE" != "201" ]; then
  echo "ERROR: Failed to create connection 1 (HTTP $HTTP_CODE)"
  echo "Response: $BODY"
  exit 1
fi

CONN1_ID=$(echo "$BODY" | jq -r '.id')
echo "✓ Connection 1 created: $CONN1_ID"

# Connection 2: Processor → Output Port
echo ""
echo "[2/2] Creating: UpdateAttribute → Output Port..."

CONN2_RESPONSE=$(curl -k -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER02_URL}/nifi-api/process-groups/root/connections" \
  -d "{
    \"revision\": {
      \"version\": 0
    },
    \"component\": {
      \"source\": {
        \"id\": \"${PROCESSOR_ID}\",
        \"groupId\": \"root\",
        \"type\": \"PROCESSOR\"
      },
      \"destination\": {
        \"id\": \"${OUTPUT_PORT_ID}\",
        \"groupId\": \"root\",
        \"type\": \"OUTPUT_PORT\"
      },
      \"selectedRelationships\": [\"success\"],
      \"backPressureDataSizeThreshold\": \"1 GB\",
      \"backPressureObjectThreshold\": 10000,
      \"flowFileExpiration\": \"0 sec\",
      \"prioritizers\": []
    }
  }")

HTTP_CODE=$(echo "$CONN2_RESPONSE" | tail -n1)
BODY=$(echo "$CONN2_RESPONSE" | sed '$ d')

if [ "$HTTP_CODE" != "201" ]; then
  echo "ERROR: Failed to create connection 2 (HTTP $HTTP_CODE)"
  echo "Response: $BODY"
  exit 1
fi

CONN2_ID=$(echo "$BODY" | jq -r '.id')
echo "✓ Connection 2 created: $CONN2_ID"

echo ""
echo "Success! Both connections created."
echo "  Connection 1: $CONN1_ID"
echo "  Connection 2: $CONN2_ID"
