#!/bin/bash
echo "=== Cluster01 ==="
for node in nifi-1 nifi-2 nifi-3; do
  echo -n "cluster01.${node}: "
  docker exec cluster01.${node} sh -c 'grep "Started Application" /opt/nifi/nifi-current/logs/nifi-app*.log 2>/dev/null | tail -1' | grep -o "Started Application.*" || echo "NOT STARTED"
done

echo ""
echo "=== Cluster02 ==="
for node in nifi-1 nifi-2 nifi-3; do
  echo -n "cluster02.${node}: "
  docker exec cluster02.${node} sh -c 'grep "Started Application" /opt/nifi/nifi-current/logs/nifi-app*.log 2>/dev/null | tail -1' | grep -o "Started Application.*" || echo "NOT STARTED"
done
