#!/bin/bash
# Initialize volume directories for NiFi cluster and ZooKeeper ensemble
#
# DEPRECATED: This script is superseded by create-cluster.sh which handles
# volume initialization automatically as part of cluster creation.
#
# Use: ./create-cluster.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
# Example: ./create-cluster.sh cluster01 1 3
#
# This script is kept for backward compatibility but is no longer recommended.

set -e

echo "Creating ZooKeeper volume directories..."

# ZooKeeper Node 1
mkdir -p volumes/zookeeper-1/{data,datalog,logs}

# ZooKeeper Node 2
mkdir -p volumes/zookeeper-2/{data,datalog,logs}

# ZooKeeper Node 3
mkdir -p volumes/zookeeper-3/{data,datalog,logs}

echo "Creating NiFi cluster volume directories..."

# NiFi Node 1
mkdir -p volumes/nifi-1/{content_repository,database_repository,flowfile_repository,provenance_repository,state,logs}

# NiFi Node 2
mkdir -p volumes/nifi-2/{content_repository,database_repository,flowfile_repository,provenance_repository,state,logs}

# NiFi Node 3
mkdir -p volumes/nifi-3/{content_repository,database_repository,flowfile_repository,provenance_repository,state,logs}

echo "Setting permissions..."

# Set proper ownership (1000:1000 is common for NiFi, adjust if needed)
# ZooKeeper runs as user 1000
sudo chown -R 1000:1000 volumes/zookeeper-*

# NiFi runs as user 1000
sudo chown -R 1000:1000 volumes/nifi-*

echo ""
echo "Volume initialization complete!"
echo ""
echo "Directory structure:"
tree -L 2 volumes/ 2>/dev/null || ls -R volumes/

echo ""
echo "Next steps:"
echo "1. Review and update .env file with your passwords"
echo "2. Run: docker compose up -d"
echo "3. Wait 2-3 minutes for cluster to initialize"
echo "4. Access NiFi cluster at:"
echo "   - Node 1: https://localhost:59443/nifi"
echo "   - Node 2: https://localhost:59444/nifi"
echo "   - Node 3: https://localhost:59445/nifi"
echo ""
