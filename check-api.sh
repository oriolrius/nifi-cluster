#!/bin/bash
TOKEN=$(curl --cacert clusters/cluster01/certs/ca/ca-cert.pem -s -X POST https://localhost:30443/nifi-api/access/token -d "username=admin&password=changeme123456")

echo "=== Checking cluster status ==="
curl --cacert clusters/cluster01/certs/ca/ca-cert.pem -s \
  -H "Authorization: Bearer $TOKEN" \
  https://localhost:30443/nifi-api/controller/cluster 2>&1

echo ""
echo ""
echo "=== Checking root process group ==="
curl --cacert clusters/cluster01/certs/ca/ca-cert.pem -s \
  -H "Authorization: Bearer $TOKEN" \
  https://localhost:30443/nifi-api/flow/process-groups/root 2>&1
