#!/bin/bash

CLUSTER02_URL="https://localhost:31443"

# Get token
TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

echo "=========================================="
echo "Verifying cluster02 Components"
echo "=========================================="
echo ""

echo "Input Ports:"
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/flow/process-groups/root" \
  | jq '.processGroupFlow.flow.inputPorts[] | {id: .id, name: .component.name, state: .component.state}'

echo ""
echo "Processors:"
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/flow/process-groups/root" \
  | jq '.processGroupFlow.flow.processors[] | {id: .id, name: .component.name, state: .component.state, type: .component.type}'

echo ""
echo "Output Ports:"
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/flow/process-groups/root" \
  | jq '.processGroupFlow.flow.outputPorts[] | {id: .id, name: .component.name, state: .component.state}'

echo ""
echo "Connections:"
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/flow/process-groups/root" \
  | jq '.processGroupFlow.flow.connections[] | {id: .id, sourceId: .sourceId, destinationId: .destinationId}'
