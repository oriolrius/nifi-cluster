#!/bin/bash

CLUSTER02_URL="https://localhost:31443"

# Get token
TOKEN=$(curl -k -s -X POST "${CLUSTER02_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

echo "=========================================="
echo "cluster02 Flow Verification"
echo "=========================================="
echo ""

echo "1. Complete Flow Status:"
echo "----------------------------------------"
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/flow/process-groups/root" \
  | jq '{
    inputPorts: [.processGroupFlow.flow.inputPorts[] | select(.component.name == "From-Cluster01-Request") | {name: .component.name, state: .component.state, id: .id}],
    processors: [.processGroupFlow.flow.processors[] | select(.component.name == "Add-Response-Metadata") | {name: .component.name, state: .component.state, id: .id}],
    outputPorts: [.processGroupFlow.flow.outputPorts[] | select(.component.name == "To-Cluster01-Response") | {name: .component.name, state: .component.state, id: .id}],
    connections: [.processGroupFlow.flow.connections[] | {source: .sourceId, dest: .destinationId, relationships: .component.selectedRelationships}]
  }'

echo ""
echo "2. Site-to-Site Endpoint:"
echo "----------------------------------------"
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/site-to-site" \
  | jq '{
    inputPorts: [.controller.inputPorts[] | select(.name == "From-Cluster01-Request") | {name: .name, id: .id}],
    outputPorts: [.controller.outputPorts[] | select(.name == "To-Cluster01-Response") | {name: .name, id: .id}]
  }'

echo ""
echo "3. Processor Configuration:"
echo "----------------------------------------"
curl -k -s -H "Authorization: Bearer ${TOKEN}" \
  "${CLUSTER02_URL}/nifi-api/processors/76bc577d-019a-1000-0000-0000769ce412" \
  | jq '{
    name: .component.name,
    state: .component.state,
    properties: .component.config.properties
  }'

echo ""
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo ""
echo "Flow: [From-Cluster01-Request] → [Add-Response-Metadata] → [To-Cluster01-Response]"
echo ""
echo "Expected States:"
echo "  - Input Port:  RUNNING ✓"
echo "  - Processor:   RUNNING ✓"
echo "  - Output Port: RUNNING ✓"
echo ""
echo "Expected S2S Ports:"
echo "  - Input:  From-Cluster01-Request ✓"
echo "  - Output: To-Cluster01-Response ✓"
echo ""
echo "Visit: https://localhost:31443/nifi"
