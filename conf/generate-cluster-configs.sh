#!/bin/bash
# Generate complete NiFi cluster configuration from templates
# Usage: ./generate-cluster-configs.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
#
# Example: ./generate-cluster-configs.sh production 1 3
#   - Creates configs for 3 nodes
#   - Base port: 29000 + (1 * 1000) = 30000
#   - External HTTPS ports: 30443, 30444, 30445

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
    echo "  Creates a 3-node cluster with base port 30000 (29000 + 1*1000)"
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
S2S_BASE=$((BASE_PORT + 100))
CLUSTER_PROTOCOL_BASE=$((BASE_PORT + 82))
LOAD_BALANCE_BASE=$((BASE_PORT + 342))

echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  NiFi Cluster Configuration Generator                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Cluster Configuration:"
echo "  Name:              $CLUSTER_NAME"
echo "  Cluster Number:    $CLUSTER_NUM"
echo "  Node Count:        $NODE_COUNT"
echo "  Base Port:         $BASE_PORT"
echo ""
echo "Port Assignments:"
echo "  HTTPS Ports:       ${HTTPS_BASE}...$((HTTPS_BASE + NODE_COUNT - 1))"
echo "  Site-to-Site:      ${S2S_BASE}...$((S2S_BASE + NODE_COUNT - 1))"
echo "  Cluster Protocol:  $CLUSTER_PROTOCOL_BASE (all nodes)"
echo "  Load Balance:      $LOAD_BALANCE_BASE (all nodes)"
echo ""

# Build ZooKeeper connect string
ZK_CONNECT_STRING=""
for i in $(seq 1 "$NODE_COUNT"); do
    if [ $i -eq 1 ]; then
        ZK_CONNECT_STRING="zookeeper-${i}:2181"
    else
        ZK_CONNECT_STRING="${ZK_CONNECT_STRING},zookeeper-${i}:2181"
    fi
done

# Build proxy host string
PROXY_HOST_STRING=""
for i in $(seq 1 "$NODE_COUNT"); do
    https_port=$((HTTPS_BASE + i - 1))
    if [ $i -eq 1 ]; then
        PROXY_HOST_STRING="localhost:${https_port}"
    else
        PROXY_HOST_STRING="${PROXY_HOST_STRING},localhost:${https_port}"
    fi
done
for i in $(seq 1 "$NODE_COUNT"); do
    PROXY_HOST_STRING="${PROXY_HOST_STRING},nifi-${i}:8443"
done

echo -e "${YELLOW}Starting configuration generation...${NC}"
echo ""

# Generate configuration for each node
for i in $(seq 1 "$NODE_COUNT"); do
    NODE_NAME="nifi-${i}"
    CONF_DIR="${SCRIPT_DIR}/${NODE_NAME}"
    HTTPS_PORT=$((HTTPS_BASE + i - 1))
    S2S_PORT=$((S2S_BASE + i - 1))

    echo -e "${GREEN}[Node ${i}/${NODE_COUNT}]${NC} Generating configuration for ${NODE_NAME}..."

    # Create node configuration directory
    mkdir -p "$CONF_DIR"
    mkdir -p "$CONF_DIR/archive"

    # Generate nifi.properties
    echo "  → Generating nifi.properties"
    cat > "$CONF_DIR/nifi.properties" << EOF
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.

# NiFi Cluster: ${CLUSTER_NAME} - Node ${i}
# Generated: $(date)
# Cluster Number: ${CLUSTER_NUM}

####################
# Core Properties #
####################
nifi.flow.configuration.file=./conf/flow.json.gz
nifi.flow.configuration.archive.enabled=true
nifi.flow.configuration.archive.dir=./conf/archive/
nifi.flow.configuration.archive.max.time=30 days
nifi.flow.configuration.archive.max.storage=500 MB
nifi.flowcontroller.autoResumeState=true
nifi.flowcontroller.graceful.shutdown.period=10 sec
nifi.flowservice.writedelay.interval=500 ms
nifi.administrative.yield.duration=30 sec
nifi.bored.yield.duration=10 millis
nifi.queue.backpressure.count=10000
nifi.queue.backpressure.size=1 GB

nifi.authorizer.configuration.file=./conf/authorizers.xml
nifi.login.identity.provider.configuration.file=./conf/login-identity-providers.xml
nifi.nar.library.directory=./lib
nifi.nar.library.autoload.directory=/opt/nifi/nifi-current/nar_extensions
nifi.nar.working.directory=./work/nar/

####################
# State Management #
####################
nifi.state.management.configuration.file=./conf/state-management.xml
nifi.state.management.provider.local=local-provider
nifi.state.management.provider.cluster=zk-provider
nifi.state.management.embedded.zookeeper.start=false

# Database Settings
nifi.database.directory=./database_repository

# FlowFile Repository
nifi.flowfile.repository.implementation=org.apache.nifi.controller.repository.WriteAheadFlowFileRepository
nifi.flowfile.repository.directory=./flowfile_repository
nifi.flowfile.repository.checkpoint.interval=20 secs
nifi.flowfile.repository.always.sync=false

nifi.swap.manager.implementation=org.apache.nifi.controller.FileSystemSwapManager
nifi.queue.swap.threshold=20000

# Content Repository
nifi.content.repository.implementation=org.apache.nifi.controller.repository.FileSystemRepository
nifi.content.claim.max.appendable.size=50 KB
nifi.content.repository.directory.default=./content_repository
nifi.content.repository.archive.max.retention.period=3 hours
nifi.content.repository.archive.max.usage.percentage=90%
nifi.content.repository.archive.enabled=true
nifi.content.repository.always.sync=false

# Provenance Repository
nifi.provenance.repository.implementation=org.apache.nifi.provenance.WriteAheadProvenanceRepository
nifi.provenance.repository.directory.default=./provenance_repository
nifi.provenance.repository.max.storage.time=30 days
nifi.provenance.repository.max.storage.size=10 GB
nifi.provenance.repository.rollover.time=10 mins
nifi.provenance.repository.rollover.size=100 MB

# Status History Repository
nifi.components.status.repository.implementation=org.apache.nifi.controller.status.history.VolatileComponentStatusRepository
nifi.components.status.repository.buffer.size=1440
nifi.components.status.snapshot.frequency=1 min

#####################
# Site-to-Site      #
#####################
nifi.remote.input.host=${NODE_NAME}
nifi.remote.input.secure=true
nifi.remote.input.socket.port=${S2S_PORT}
nifi.remote.input.http.enabled=true
nifi.remote.input.http.transaction.ttl=30 sec

#####################
# Web Properties    #
#####################
# HTTP disabled for security
nifi.web.http.host=
nifi.web.http.port=

# HTTPS enabled
nifi.web.https.host=0.0.0.0
nifi.web.https.port=8443
nifi.web.https.network.interface.default=
nifi.web.https.application.protocols=h2 http/1.1
nifi.web.jetty.working.directory=./work/jetty
nifi.web.jetty.threads=200
nifi.web.max.header.size=16 KB

# Proxy configuration for cluster access
nifi.web.proxy.host=${PROXY_HOST_STRING}
nifi.web.max.requests.per.second=30000
nifi.web.request.timeout=60 secs

#####################
# Security Properties
#####################
nifi.sensitive.props.key=changeme_sensitive_key_123
nifi.sensitive.props.algorithm=NIFI_PBKDF2_AES_GCM_256

# SSL/TLS Configuration
nifi.security.keystore=/opt/nifi/nifi-current/conf/keystore.p12
nifi.security.keystoreType=PKCS12
nifi.security.keystorePasswd=changeme123456
nifi.security.keyPasswd=changeme123456
nifi.security.truststore=/opt/nifi/nifi-current/conf/truststore.p12
nifi.security.truststoreType=PKCS12
nifi.security.truststorePasswd=changeme123456

# Single User Authentication (for demo/dev)
nifi.security.user.authorizer=single-user-authorizer
nifi.security.allow.anonymous.authentication=false
nifi.security.user.login.identity.provider=single-user-provider
nifi.security.user.jws.key.rotation.period=PT1H

#####################
# Cluster Properties
#####################
# Cluster Common Properties (same for all nodes)
nifi.cluster.protocol.heartbeat.interval=5 sec
nifi.cluster.protocol.heartbeat.missable.max=8
nifi.cluster.protocol.is.secure=true

# Cluster Node Properties (node-specific)
nifi.cluster.is.node=true
nifi.cluster.leader.election.implementation=CuratorLeaderElectionManager
nifi.cluster.node.address=${NODE_NAME}
nifi.cluster.node.protocol.port=${CLUSTER_PROTOCOL_BASE}
nifi.cluster.node.protocol.max.threads=50
nifi.cluster.node.event.history.size=25
nifi.cluster.node.connection.timeout=5 sec
nifi.cluster.node.read.timeout=5 sec
nifi.cluster.node.max.concurrent.requests=100
nifi.cluster.flow.election.max.wait.time=1 min

# Load Balancing
nifi.cluster.load.balance.host=
nifi.cluster.load.balance.port=${LOAD_BALANCE_BASE}
nifi.cluster.load.balance.connections.per.node=1
nifi.cluster.load.balance.max.thread.count=8
nifi.cluster.load.balance.comms.timeout=30 sec

#####################
# ZooKeeper         #
#####################
nifi.zookeeper.connect.string=${ZK_CONNECT_STRING}
nifi.zookeeper.connect.timeout=10 secs
nifi.zookeeper.session.timeout=10 secs
nifi.zookeeper.root.node=/nifi
nifi.zookeeper.client.secure=false

#####################
# Performance Tuning
#####################
# JVM heap is set via environment variables in docker-compose.yml
# NIFI_JVM_HEAP_INIT and NIFI_JVM_HEAP_MAX

EOF

    # Generate state-management.xml
    echo "  → Generating state-management.xml"
    cat > "$CONF_DIR/state-management.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!--
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
-->
<stateManagement>
  <local-provider>
    <id>local-provider</id>
    <class>org.apache.nifi.controller.state.providers.local.WriteAheadLocalStateProvider</class>
    <property name="Directory">./state/local</property>
    <property name="Always Sync">false</property>
    <property name="Partitions">16</property>
    <property name="Checkpoint Interval">2 mins</property>
  </local-provider>
  <cluster-provider>
    <id>zk-provider</id>
    <class>org.apache.nifi.controller.state.providers.zookeeper.ZooKeeperStateProvider</class>
    <property name="Connect String">ZK_CONNECT_STRING</property>
    <property name="Root Node">/nifi</property>
    <property name="Session Timeout">10 seconds</property>
    <property name="Access Control">Open</property>
  </cluster-provider>
</stateManagement>
EOF

    # Substitute ZooKeeper connect string
    sed -i "s|ZK_CONNECT_STRING|${ZK_CONNECT_STRING}|g" "$CONF_DIR/state-management.xml"

    # Copy standard config files if they exist in nifi-1 or from Docker image defaults
    # These files are typically the same across all nodes
    if [ -f "${SCRIPT_DIR}/nifi-1/authorizers.xml" ] && [ $i -ne 1 ]; then
        echo "  → Copying authorizers.xml"
        cp "${SCRIPT_DIR}/nifi-1/authorizers.xml" "$CONF_DIR/"
    fi

    if [ -f "${SCRIPT_DIR}/nifi-1/bootstrap.conf" ] && [ $i -ne 1 ]; then
        echo "  → Copying bootstrap.conf"
        cp "${SCRIPT_DIR}/nifi-1/bootstrap.conf" "$CONF_DIR/"
    fi

    if [ -f "${SCRIPT_DIR}/nifi-1/logback.xml" ] && [ $i -ne 1 ]; then
        echo "  → Copying logback.xml"
        cp "${SCRIPT_DIR}/nifi-1/logback.xml" "$CONF_DIR/"
    fi

    if [ -f "${SCRIPT_DIR}/nifi-1/login-identity-providers.xml" ] && [ $i -ne 1 ]; then
        echo "  → Copying login-identity-providers.xml"
        cp "${SCRIPT_DIR}/nifi-1/login-identity-providers.xml" "$CONF_DIR/"
    fi

    if [ -f "${SCRIPT_DIR}/nifi-1/zookeeper.properties" ] && [ $i -ne 1 ]; then
        echo "  → Copying zookeeper.properties"
        cp "${SCRIPT_DIR}/nifi-1/zookeeper.properties" "$CONF_DIR/"
    fi

    # Copy certificates if they exist
    CERT_SOURCE="${PROJECT_ROOT}/certs/${NODE_NAME}"
    if [ -d "$CERT_SOURCE" ]; then
        echo "  → Copying certificates from $CERT_SOURCE"
        if [ -f "$CERT_SOURCE/keystore.p12" ]; then
            cp "$CERT_SOURCE/keystore.p12" "$CONF_DIR/"
        fi
        if [ -f "$CERT_SOURCE/truststore.p12" ]; then
            cp "$CERT_SOURCE/truststore.p12" "$CONF_DIR/"
        fi
    else
        echo -e "  ${YELLOW}⚠ Warning: Certificate directory not found: $CERT_SOURCE${NC}"
    fi

    echo -e "  ${GREEN}✓${NC} Configuration for ${NODE_NAME} completed"
    echo ""
done

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Configuration Generation Complete                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Generated configurations for ${NODE_COUNT} nodes in: ${SCRIPT_DIR}"
echo ""
echo "Next steps:"
echo "  1. Review generated configurations in conf/nifi-*/"
echo "  2. Update docker-compose.yml with correct port mappings"
echo "  3. Ensure certificates exist in certs/nifi-*/"
echo "  4. Start cluster: docker compose up -d"
echo ""
echo "Access URLs (after starting):"
for i in $(seq 1 "$NODE_COUNT"); do
    https_port=$((HTTPS_BASE + i - 1))
    echo "  Node ${i}: https://localhost:${https_port}/nifi"
done
echo ""
