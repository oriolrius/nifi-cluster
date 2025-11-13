#!/bin/bash
echo "Node Status Report (checking all log files)"
echo "============================================"
echo ""

for cluster in cluster01 cluster02; do
  echo "=== ${cluster} ==="
  for node in nifi-1 nifi-2 nifi-3; do
    container="${cluster}-${node}"
    echo -n "${container}: "
    
    # Check all log files
    result=$(docker exec ${container} grep "Started Application" /opt/nifi/nifi-current/logs/nifi-app*.log 2>/dev/null | tail -1 | grep -o "Started Application.*")
    
    if [ -n "$result" ]; then
      echo "✓ $result"
    else
      echo "✗ NOT STARTED"
    fi
  done
  echo ""
done
