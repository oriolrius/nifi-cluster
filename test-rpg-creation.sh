#!/bin/bash
CLUSTER01_URL="https://localhost:30443"
TOKEN=$(curl -k -s -X POST "${CLUSTER01_URL}/nifi-api/access/token" -d "username=admin&password=changeme123456")
echo "Token obtained"

echo "Creating RPG..."
curl -k -s -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  "${CLUSTER01_URL}/nifi-api/process-groups/root/remote-process-groups" \
  -d '{
    "revision": {"version": 0},
    "component": {
      "targetUri": "https://cluster02.nifi-1:8443/nifi",
      "transportProtocol": "HTTP",
      "communicationsTimeout": "30 sec",
      "yieldDuration": "10 sec",
      "name": "cluster02-rpg",
      "comments": "Remote Process Group connecting to cluster02 via inter-cluster-network for Site-to-Site"
    }
  }'
