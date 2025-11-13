#!/bin/bash
# Debug script for NiFi API

CA_CERT="./clusters/cluster01/certs/ca/ca-cert.pem"
PORT=30443
USERNAME="admin"
PASSWORD="changeme123456"

echo "Step 1: Getting authentication token..."
TOKEN=$(curl -s --cacert "$CA_CERT" -X POST "https://localhost:$PORT/nifi-api/access/token" -d "username=$USERNAME&password=$PASSWORD")

if [ -z "$TOKEN" ]; then
    echo "ERROR: Failed to get token (empty response)"
    exit 1
fi

echo "Token received: ${#TOKEN} characters"
echo "First 50 chars: ${TOKEN:0:50}..."
echo ""

echo "Step 2: Testing /nifi-api/flow/process-groups/root endpoint..."
RESPONSE=$(curl -s --cacert "$CA_CERT" -H "Authorization: Bearer $TOKEN" "https://localhost:$PORT/nifi-api/flow/process-groups/root")

echo "Response (first 500 chars):"
echo "$RESPONSE" | head -c 500
echo ""
echo ""

echo "Step 3: Parsing with jq..."
ROOT_PG=$(echo "$RESPONSE" | jq -r '.processGroupFlow.id' 2>&1)

if [ $? -ne 0 ]; then
    echo "ERROR: jq failed to parse response"
    echo "jq error: $ROOT_PG"
    echo ""
    echo "Full response:"
    echo "$RESPONSE"
else
    echo "Root process group ID: $ROOT_PG"
fi
