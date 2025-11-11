#!/bin/bash
################################################################################
# Initialize Volume and Configuration Directory Structure for NiFi Cluster
################################################################################
# This script creates the required directory structure for a multi-cluster
# NiFi deployment, including volumes for data persistence and configuration
# directories for each node.
#
# Usage:
#   ./init-cluster-volumes.sh <CLUSTER_NAME> [NODE_COUNT]
#
# Arguments:
#   CLUSTER_NAME  - Name of the cluster (e.g., cluster01, cluster02, prod, dev)
#   NODE_COUNT    - Number of nodes (default: 3)
#
# Example:
#   ./init-cluster-volumes.sh cluster01 3
#
################################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_NODE_COUNT=3
DEFAULT_UID=1000
DEFAULT_GID=1000

################################################################################
# Functions
################################################################################

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}"
}

print_info() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_usage() {
    cat << EOF
Usage: $0 <CLUSTER_NAME> [NODE_COUNT]

Arguments:
  CLUSTER_NAME    Name of the cluster (e.g., cluster01, cluster02, prod, dev)
  NODE_COUNT      Number of nodes in the cluster (default: $DEFAULT_NODE_COUNT)

Examples:
  $0 cluster01              # Create cluster01 with 3 nodes
  $0 cluster02 3            # Create cluster02 with 3 nodes
  $0 prod 5                 # Create prod cluster with 5 nodes

The script will create the following directory structure:
  clusters/<CLUSTER_NAME>/
    ├── volumes/
    │   ├── zookeeper-1/
    │   │   ├── data/
    │   │   ├── datalog/
    │   │   └── logs/
    │   ├── nifi-1/
    │   │   ├── content_repository/
    │   │   ├── database_repository/
    │   │   ├── flowfile_repository/
    │   │   ├── provenance_repository/
    │   │   ├── state/
    │   │   └── logs/
    │   └── ...
    └── conf/
        ├── zookeeper-1/
        ├── nifi-1/
        └── ...

EOF
}

validate_cluster_name() {
    local name=$1

    # Check if name is empty
    if [ -z "$name" ]; then
        print_error "Cluster name cannot be empty"
        return 1
    fi

    # Check if name contains only valid characters (alphanumeric, dash, underscore)
    if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Cluster name can only contain letters, numbers, dashes, and underscores"
        return 1
    fi

    # Check length (reasonable limits)
    if [ ${#name} -lt 2 ] || [ ${#name} -gt 50 ]; then
        print_error "Cluster name must be between 2 and 50 characters"
        return 1
    fi

    return 0
}

validate_node_count() {
    local count=$1

    # Check if it's a number
    if ! [[ "$count" =~ ^[0-9]+$ ]]; then
        print_error "Node count must be a positive integer"
        return 1
    fi

    # Check reasonable range (1-10 nodes)
    if [ "$count" -lt 1 ] || [ "$count" -gt 10 ]; then
        print_error "Node count must be between 1 and 10"
        return 1
    fi

    # Warn if even number (ZooKeeper best practice is odd)
    if [ $((count % 2)) -eq 0 ]; then
        print_warning "ZooKeeper quorum works best with an odd number of nodes"
    fi

    return 0
}

create_directory_safe() {
    local dir=$1

    if [ -d "$dir" ]; then
        print_info "Directory already exists: $dir"
    else
        mkdir -p "$dir"
        print_info "Created: $dir"
    fi
}

################################################################################
# Main Script
################################################################################

# Parse arguments
if [ $# -lt 1 ]; then
    print_error "Missing required argument: CLUSTER_NAME"
    echo ""
    print_usage
    exit 1
fi

CLUSTER_NAME=$1
NODE_COUNT=${2:-$DEFAULT_NODE_COUNT}

print_header "NiFi Cluster Volume Initialization"

echo "Configuration:"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Node Count:   $NODE_COUNT"
echo "  UID:GID:      $DEFAULT_UID:$DEFAULT_GID"
echo ""

# Validate inputs
print_info "Validating inputs..."
if ! validate_cluster_name "$CLUSTER_NAME"; then
    exit 1
fi

if ! validate_node_count "$NODE_COUNT"; then
    exit 1
fi

# Set base paths
BASE_DIR="clusters/$CLUSTER_NAME"
VOLUMES_DIR="$BASE_DIR/volumes"
CONF_DIR="$BASE_DIR/conf"

# Check if cluster directory already exists
if [ -d "$BASE_DIR" ]; then
    print_warning "Cluster directory already exists: $BASE_DIR"
    read -p "Do you want to continue and create missing directories? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Aborted by user"
        exit 0
    fi
fi

echo ""
print_header "Creating ZooKeeper Directories"

for i in $(seq 1 $NODE_COUNT); do
    echo "ZooKeeper Node $i:"

    # Volume directories
    create_directory_safe "$VOLUMES_DIR/zookeeper-$i/data"
    create_directory_safe "$VOLUMES_DIR/zookeeper-$i/datalog"
    create_directory_safe "$VOLUMES_DIR/zookeeper-$i/logs"

    # Configuration directory
    create_directory_safe "$CONF_DIR/zookeeper-$i"

    echo ""
done

echo ""
print_header "Creating NiFi Directories"

for i in $(seq 1 $NODE_COUNT); do
    echo "NiFi Node $i:"

    # Volume directories
    create_directory_safe "$VOLUMES_DIR/nifi-$i/content_repository"
    create_directory_safe "$VOLUMES_DIR/nifi-$i/database_repository"
    create_directory_safe "$VOLUMES_DIR/nifi-$i/flowfile_repository"
    create_directory_safe "$VOLUMES_DIR/nifi-$i/provenance_repository"
    create_directory_safe "$VOLUMES_DIR/nifi-$i/state"
    create_directory_safe "$VOLUMES_DIR/nifi-$i/logs"

    # Configuration directory
    create_directory_safe "$CONF_DIR/nifi-$i"

    echo ""
done

echo ""
print_header "Setting Permissions"

# Set permissions for all created directories
if command -v sudo &> /dev/null && [ "$EUID" -ne 0 ]; then
    print_info "Setting ownership to $DEFAULT_UID:$DEFAULT_GID (requires sudo)..."

    # Check if we can use sudo without password or if user will be prompted
    if sudo -n true 2>/dev/null; then
        sudo chown -R $DEFAULT_UID:$DEFAULT_GID "$BASE_DIR"
        print_info "Permissions set successfully"
    else
        echo ""
        print_warning "Sudo access required to set proper permissions"
        sudo chown -R $DEFAULT_UID:$DEFAULT_GID "$BASE_DIR"
        print_info "Permissions set successfully"
    fi
elif [ "$EUID" -eq 0 ]; then
    chown -R $DEFAULT_UID:$DEFAULT_GID "$BASE_DIR"
    print_info "Permissions set successfully"
else
    print_warning "Cannot set permissions - sudo not available and not running as root"
    print_warning "You may need to manually set ownership: chown -R $DEFAULT_UID:$DEFAULT_GID $BASE_DIR"
fi

echo ""
print_header "Directory Structure Created"

# Display directory tree if available
if command -v tree &> /dev/null; then
    tree -L 3 -d "$BASE_DIR" 2>/dev/null || true
else
    ls -lR "$BASE_DIR"
fi

echo ""
print_header "Initialization Complete!"

echo ""
echo "Cluster: $CLUSTER_NAME"
echo "Location: $BASE_DIR"
echo "Nodes: $NODE_COUNT"
echo ""
echo "Next steps:"
echo "  1. Generate cluster configuration:"
echo "     ./scripts/generate-cluster-configs.sh $CLUSTER_NAME $NODE_COUNT"
echo ""
echo "  2. Generate docker-compose.yml:"
echo "     ./scripts/generate-docker-compose.sh $CLUSTER_NAME"
echo ""
echo "  3. Start the cluster:"
echo "     cd $BASE_DIR && docker compose up -d"
echo ""
