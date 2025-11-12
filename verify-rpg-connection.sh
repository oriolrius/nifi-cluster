#!/bin/bash

CLUSTER01_URL="https://localhost:30443"
RPG_ID="76ca555f-019a-1000-0000-00006d947e3e"

# Get token
TOKEN=$(curl -k -s -X POST "${CLUSTER01_URL}/nifi-api/access/token" \
  -d "username=admin&password=changeme123456")

echo "Checking RPG connection status..."
echo ""

for i in {1..6}; do
  echo "Attempt $i/6:"

  RPG_STATUS=$(curl -k -s -H "Authorization: Bearer ${TOKEN}" \
    "${CLUSTER01_URL}/nifi-api/remote-process-groups/${RPG_ID}")

  FLOW_REFRESHED=$(echo "$RPG_STATUS" | jq -r '.component.flowRefreshed')
  INPUT_PORTS=$(echo "$RPG_STATUS" | jq -r '.component.contents.inputPorts | length')
  OUTPUT_PORTS=$(echo "$RPG_STATUS" | jq -r '.component.contents.outputPorts | length')

  echo "  Flow Refreshed: $FLOW_REFRESHED"
  echo "  Input Ports: $INPUT_PORTS"
  echo "  Output Ports: $OUTPUT_PORTS"

  if [ "$INPUT_PORTS" != "0" ] && [ "$OUTPUT_PORTS" != "0" ]; then
    echo ""
    echo "✓ RPG successfully discovered remote ports!"
    echo ""
    echo "Discovered ports:"
    echo "$RPG_STATUS" | jq '{
      inputPorts: [.component.contents.inputPorts[] | {name: .name, targetRunning: .targetRunning}],
      outputPorts: [.component.contents.outputPorts[] | {name: .name, targetRunning: .targetRunning}]
    }'
    exit 0
  fi

  if [ $i -lt 6 ]; then
    echo "  Waiting 5 more seconds..."
    echo ""
    sleep 5
  fi
done

echo ""
echo "⚠ RPG created but hasn't discovered ports yet."
echo "This may indicate a connection issue."
echo ""
echo "Check cluster02 status:"
echo "  docker compose -f docker-compose-cluster02.yml ps"
echo ""
echo "Check cluster02 ports:"
echo "  curl -k https://localhost:31443/nifi-api/site-to-site"
