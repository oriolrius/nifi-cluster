#!/bin/bash
# Generate docker-compose.yml for NiFi cluster
# Usage: ./generate-docker-compose.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
#
# Example: ./generate-docker-compose.sh production 1 3
#   - Creates docker-compose.yml for 3-node cluster
#   - Base port: 29000 + (1 * 1000) = 30000
#   - External ports: 30443-30445 (HTTPS), 30181-30183 (ZK), 30100-30102 (S2S)

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate input parameters
if [ $# -ne 3 ]; then
    echo -e "${RED}Error: Invalid number of arguments${NC}"
    echo "Usage: $0 <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>"
    echo ""
    echo "Parameters:"
    echo "  CLUSTER_NAME  - Descriptive name for the cluster (e.g., 'production', 'staging')"
    echo "  CLUSTER_NUM   - Cluster number for port calculation (integer >= 0)"
    echo "  NODE_COUNT    - Number of nodes in the cluster (integer >= 1)"
    echo ""
    echo "Example: $0 production 1 3"
    echo "  Creates docker-compose.yml for a 3-node cluster with base port 30000"
    exit 1
fi

CLUSTER_NAME="$1"
CLUSTER_NUM="$2"
NODE_COUNT="$3"

# Validate parameters
if ! [[ "$CLUSTER_NUM" =~ ^[0-9]+$ ]]; then
    echo -e "${RED}Error: CLUSTER_NUM must be a non-negative integer${NC}"
    exit 1
fi

if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -lt 1 ]; then
    echo -e "${RED}Error: NODE_COUNT must be a positive integer${NC}"
    exit 1
fi

# Calculate port assignments
BASE_PORT=$((29000 + (CLUSTER_NUM * 1000)))
HTTPS_BASE=$((BASE_PORT + 443))
ZK_BASE=$((BASE_PORT + 181))
S2S_BASE=$((BASE_PORT + 100))

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Docker Compose Generator for NiFi Cluster                   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Cluster Configuration:"
echo "  Name:              $CLUSTER_NAME"
echo "  Cluster Number:    $CLUSTER_NUM"
echo "  Node Count:        $NODE_COUNT"
echo "  Base Port:         $BASE_PORT"
echo ""
echo "Port Assignments:"
echo "  HTTPS (NiFi UI):   ${HTTPS_BASE}...$((HTTPS_BASE + NODE_COUNT - 1))"
echo "  ZooKeeper:         ${ZK_BASE}...$((ZK_BASE + NODE_COUNT - 1))"
echo "  Site-to-Site:      ${S2S_BASE}...$((S2S_BASE + NODE_COUNT - 1))"
echo ""

# Build ZooKeeper servers string
ZK_SERVERS=""
for i in $(seq 1 "$NODE_COUNT"); do
    if [ $i -eq 1 ]; then
        ZK_SERVERS="server.${i}=zookeeper-${i}:2888:3888;2181"
    else
        ZK_SERVERS="${ZK_SERVERS} server.${i}=zookeeper-${i}:2888:3888;2181"
    fi
done

# Build ZooKeeper connect string
ZK_CONNECT=""
for i in $(seq 1 "$NODE_COUNT"); do
    if [ $i -eq 1 ]; then
        ZK_CONNECT="zookeeper-${i}:2181"
    else
        ZK_CONNECT="${ZK_CONNECT},zookeeper-${i}:2181"
    fi
done

# Build proxy host string
PROXY_HOST=""
for i in $(seq 1 "$NODE_COUNT"); do
    https_port=$((HTTPS_BASE + i - 1))
    if [ $i -eq 1 ]; then
        PROXY_HOST="localhost:${https_port}"
    else
        PROXY_HOST="${PROXY_HOST},localhost:${https_port}"
    fi
done
for i in $(seq 1 "$NODE_COUNT"); do
    PROXY_HOST="${PROXY_HOST},nifi-${i}:8443"
done

# Build ZooKeeper depends_on list
ZK_DEPENDS=""
for i in $(seq 1 "$NODE_COUNT"); do
    if [ $i -eq 1 ]; then
        ZK_DEPENDS="      - zookeeper-${i}"
    else
        ZK_DEPENDS="${ZK_DEPENDS}\n      - zookeeper-${i}"
    fi
done

OUTPUT_FILE="${SCRIPT_DIR}/docker-compose.yml"

echo -e "${YELLOW}Generating docker-compose.yml...${NC}"
echo ""

# Generate docker-compose.yml
cat > "$OUTPUT_FILE" << EOF
name: ${CLUSTER_NAME}-nifi-cluster

services:
EOF

# Generate ZooKeeper services
echo "  → Generating ZooKeeper ensemble (${NODE_COUNT} nodes)"
for i in $(seq 1 "$NODE_COUNT"); do
    ZK_PORT=$((ZK_BASE + i - 1))

    cat >> "$OUTPUT_FILE" << EOF
  # ZooKeeper Node $i
  zookeeper-${i}:
    image: zookeeper:\${ZOOKEEPER_VERSION:-3.9}
    container_name: ${CLUSTER_NAME}-zookeeper-${i}
    hostname: zookeeper-${i}
    networks:
      - ${CLUSTER_NAME}-network
    ports:
      - "${ZK_PORT}:2181"
    environment:
      ZOO_MY_ID: ${i}
      ZOO_SERVERS: ${ZK_SERVERS}
      ZOO_4LW_COMMANDS_WHITELIST: "*"
      ZOO_TICK_TIME: 2000
      ZOO_INIT_LIMIT: 10
      ZOO_SYNC_LIMIT: 5
      ZOO_MAX_CLIENT_CNXNS: 60
    volumes:
      - ./volumes/zookeeper-${i}/data:/data
      - ./volumes/zookeeper-${i}/datalog:/datalog
      - ./volumes/zookeeper-${i}/logs:/logs
    restart: unless-stopped

EOF
done

# Generate NiFi services
echo "  → Generating NiFi cluster nodes (${NODE_COUNT} nodes)"
for i in $(seq 1 "$NODE_COUNT"); do
    HTTPS_PORT=$((HTTPS_BASE + i - 1))
    S2S_PORT=$((S2S_BASE + i - 1))

    cat >> "$OUTPUT_FILE" << EOF
  # NiFi Cluster Node $i
  nifi-${i}:
    image: apache/nifi:\${NIFI_VERSION:-latest}
    container_name: ${CLUSTER_NAME}-nifi-${i}
    hostname: nifi-${i}
    networks:
      - ${CLUSTER_NAME}-network
    ports:
      - "${HTTPS_PORT}:8443"   # HTTPS UI
      - "${S2S_PORT}:10000" # Site-to-Site
    environment:
      # Cluster Configuration
      NIFI_CLUSTER_IS_NODE: "true"
      NIFI_CLUSTER_NODE_PROTOCOL_PORT: 8082
      NIFI_CLUSTER_NODE_ADDRESS: nifi-${i}
      NIFI_ZK_CONNECT_STRING: ${ZK_CONNECT}
      NIFI_ELECTION_MAX_WAIT: 1 min

      # Web Properties - HTTPS
      NIFI_WEB_HTTPS_PORT: 8443
      NIFI_WEB_HTTPS_HOST: nifi-${i}
      NIFI_WEB_PROXY_HOST: ${PROXY_HOST}

      # Security - Single User (for demo/dev)
      SINGLE_USER_CREDENTIALS_USERNAME: \${NIFI_SINGLE_USER_USERNAME:-admin}
      SINGLE_USER_CREDENTIALS_PASSWORD: \${NIFI_SINGLE_USER_PASSWORD:-changeme123456}

      # SSL/TLS Configuration - Managed by nifi.properties file (no env vars override)

      # State Management
      NIFI_STATE_MANAGEMENT_EMBEDDED_ZOOKEEPER_START: "false"

      # Performance Tuning
      NIFI_JVM_HEAP_INIT: \${NIFI_JVM_HEAP_INIT:-2g}
      NIFI_JVM_HEAP_MAX: \${NIFI_JVM_HEAP_MAX:-2g}
    volumes:
      - ./conf/nifi-${i}:/opt/nifi/nifi-current/conf:rw
      - ./volumes/nifi-${i}/content_repository:/opt/nifi/nifi-current/content_repository
      - ./volumes/nifi-${i}/database_repository:/opt/nifi/nifi-current/database_repository
      - ./volumes/nifi-${i}/flowfile_repository:/opt/nifi/nifi-current/flowfile_repository
      - ./volumes/nifi-${i}/provenance_repository:/opt/nifi/nifi-current/provenance_repository
      - ./volumes/nifi-${i}/state:/opt/nifi/nifi-current/state
      - ./volumes/nifi-${i}/logs:/opt/nifi/nifi-current/logs
    depends_on:
$(echo -e "$ZK_DEPENDS")
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -k https://localhost:8443/nifi || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

EOF
done

# Generate networks section
echo "  → Generating network configuration"
cat >> "$OUTPUT_FILE" << EOF
networks:
  ${CLUSTER_NAME}-network:
    driver: bridge
EOF

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Docker Compose Generation Complete                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Generated: ${OUTPUT_FILE}"
echo ""
echo "Services created:"
echo "  - ${NODE_COUNT} ZooKeeper nodes (zookeeper-1 to zookeeper-${NODE_COUNT})"
echo "  - ${NODE_COUNT} NiFi nodes (nifi-1 to nifi-${NODE_COUNT})"
echo "  - Network: ${CLUSTER_NAME}-network"
echo ""
echo "Access URLs:"
for i in $(seq 1 "$NODE_COUNT"); do
    https_port=$((HTTPS_BASE + i - 1))
    echo "  NiFi Node ${i}: https://localhost:${https_port}/nifi"
done
echo ""
echo "Next steps:"
echo "  1. Generate configurations: cd conf && ./generate-cluster-configs.sh ${CLUSTER_NAME} ${CLUSTER_NUM} ${NODE_COUNT}"
echo "  2. Generate certificates: cd certs && ./generate-certs.sh ${NODE_COUNT}"
echo "  3. Initialize volumes: ./init-volumes.sh"
echo "  4. Start cluster: docker compose up -d"
echo ""
