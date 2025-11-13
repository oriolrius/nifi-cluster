#!/bin/bash
for cluster in cluster01 cluster02; do
  echo "=== ${cluster} ==="
  for node in nifi-1 nifi-2 nifi-3; do
    echo -n "${cluster}.${node}: "
    docker exec ${cluster}.${node} grep "Started Application" /opt/nifi/nifi-current/logs/nifi-app.log 2>/dev/null | tail -1 | grep -o "Started Application.*" || echo "NOT STARTED"
  done
  echo ""
done
