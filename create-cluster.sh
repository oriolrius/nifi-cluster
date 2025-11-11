#!/bin/bash
# Master orchestration script to create a complete NiFi cluster
# Usage: ./create-cluster.sh <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>
#
# Example: ./create-cluster.sh production 0 3
#   - Creates a 3-node NiFi cluster with base port 29000
#   - Generates all certificates, configs, and docker-compose.yml
#   - Initializes all required volumes

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to display usage
usage() {
    cat << EOF
${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}
${CYAN}║  NiFi Cluster Creation Script                                 ║${NC}
${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}

Usage: $0 <CLUSTER_NAME> <CLUSTER_NUM> <NODE_COUNT>

Parameters:
  CLUSTER_NAME  - Name for the cluster (e.g., 'cluster01', 'cluster02')
  CLUSTER_NUM   - Cluster number for port calculation (integer >= 0)
  NODE_COUNT    - Number of nodes in the cluster (integer >= 1)

Port Calculation:
  BASE_PORT = 29000 + (CLUSTER_NUM × 1000)

  HTTPS Ports:  BASE_PORT + 443 to BASE_PORT + 443 + NODE_COUNT - 1
  ZK Ports:     BASE_PORT + 181 to BASE_PORT + 181 + NODE_COUNT - 1
  S2S Ports:    BASE_PORT + 100 to BASE_PORT + 100 + NODE_COUNT - 1

Examples:
  # First cluster (3 nodes, cluster #1)
  $0 cluster01 1 3
  → Base port: 30000, HTTPS: 30443-30445

  # Second cluster (3 nodes, cluster #2)
  $0 cluster02 2 3
  → Base port: 31000, HTTPS: 31443-31445

  # Third cluster (2 nodes, cluster #3)
  $0 cluster03 3 2
  → Base port: 32000, HTTPS: 32443-32444

What this script does:
  1. Validates prerequisites (Docker, required directories)
  2. Creates volume directories for ZooKeeper and NiFi nodes
  3. Generates SSL/TLS certificates for secure communication
  4. Generates NiFi configuration files for each node
  5. Generates docker-compose.yml for the entire cluster
  6. Displays access URLs and next steps

Flags:
  --help, -h    Show this help message

EOF
    exit 0
}

# Function to print section headers
print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to print step messages
print_step() {
    echo -e "${MAGENTA}▶ Step $1/$2:${NC} ${YELLOW}$3${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}✗ Error:${NC} $1" >&2
}

# Function to print warnings
print_warning() {
    echo -e "${YELLOW}⚠ Warning:${NC} $1"
}

# Check for help flag
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    usage
fi

# Validate input parameters
if [ $# -ne 3 ]; then
    print_error "Invalid number of arguments"
    echo ""
    echo "Run '$0 --help' for usage information"
    exit 1
fi

CLUSTER_NAME="$1"
CLUSTER_NUM="$2"
NODE_COUNT="$3"

# Validate parameters
if ! [[ "$CLUSTER_NUM" =~ ^[0-9]+$ ]]; then
    print_error "CLUSTER_NUM must be a non-negative integer"
    exit 1
fi

if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -lt 1 ]; then
    print_error "NODE_COUNT must be a positive integer"
    exit 1
fi

# Calculate ports
BASE_PORT=$((29000 + (CLUSTER_NUM * 1000)))
HTTPS_BASE=$((BASE_PORT + 443))
ZK_BASE=$((BASE_PORT + 181))
S2S_BASE=$((BASE_PORT + 100))

print_header "NiFi Cluster Creation - ${CLUSTER_NAME}"

echo "Cluster Configuration:"
echo "  Name:              ${CLUSTER_NAME}"
echo "  Cluster Number:    ${CLUSTER_NUM}"
echo "  Node Count:        ${NODE_COUNT}"
echo "  Base Port:         ${BASE_PORT}"
echo ""
echo "Port Assignments:"
echo "  HTTPS (NiFi UI):   ${HTTPS_BASE}...$((HTTPS_BASE + NODE_COUNT - 1))"
echo "  ZooKeeper:         ${ZK_BASE}...$((ZK_BASE + NODE_COUNT - 1))"
echo "  Site-to-Site:      ${S2S_BASE}...$((S2S_BASE + NODE_COUNT - 1))"
echo ""

# Step 1: Validate prerequisites
print_step 1 5 "Validating Prerequisites"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi
print_success "Docker found: $(docker --version | head -1)"

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    print_error "Docker Compose is not available"
    exit 1
fi
print_success "Docker Compose found: $(docker compose version --short)"

# Check if required directories exist
for dir in certs conf; do
    if [ ! -d "$SCRIPT_DIR/$dir" ]; then
        print_error "Required directory not found: $dir"
        exit 1
    fi
done
print_success "Required directories exist"

# Check if required scripts exist
REQUIRED_SCRIPTS=(
    "certs/generate-certs.sh"
    "conf/generate-cluster-configs.sh"
    "generate-docker-compose.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -x "$SCRIPT_DIR/$script" ]; then
        print_error "Required script not found or not executable: $script"
        exit 1
    fi
done
print_success "All required scripts found"

echo ""

# Step 2: Initialize volumes
print_step 2 5 "Initializing Volume Directories"
echo ""

mkdir -p volumes

echo "Creating ZooKeeper volume directories..."
for i in $(seq 1 "$NODE_COUNT"); do
    mkdir -p "volumes/zookeeper-${i}"/{data,datalog,logs}
    echo "  → Created volumes/zookeeper-${i}/{data,datalog,logs}"
done

echo ""
echo "Creating NiFi volume directories..."
for i in $(seq 1 "$NODE_COUNT"); do
    mkdir -p "volumes/nifi-${i}"/{content_repository,database_repository,flowfile_repository,provenance_repository,state,logs}
    echo "  → Created volumes/nifi-${i}/{content_repository,database_repository,flowfile_repository,provenance_repository,state,logs}"
done

echo ""
echo "Setting permissions..."
# Set proper ownership (1000:1000 is common for NiFi and ZooKeeper)
if command -v sudo &> /dev/null; then
    sudo chown -R 1000:1000 volumes/zookeeper-* 2>/dev/null || print_warning "Could not set ownership on ZooKeeper volumes (may require manual intervention)"
    sudo chown -R 1000:1000 volumes/nifi-* 2>/dev/null || print_warning "Could not set ownership on NiFi volumes (may require manual intervention)"
    print_success "Permissions set (UID:GID 1000:1000)"
else
    print_warning "sudo not available - you may need to manually set ownership on volume directories"
fi

print_success "Volume initialization complete"
echo ""

# Step 3: Generate certificates
print_step 3 5 "Generating SSL/TLS Certificates"
echo ""

cd "$SCRIPT_DIR/certs"
if ./generate-certs.sh "$NODE_COUNT"; then
    print_success "Certificates generated successfully"
else
    print_error "Certificate generation failed"
    exit 1
fi
cd "$SCRIPT_DIR"
echo ""

# Step 4: Generate NiFi configurations
print_step 4 5 "Generating NiFi Configuration Files"
echo ""

cd "$SCRIPT_DIR/conf"
if ./generate-cluster-configs.sh "$CLUSTER_NAME" "$CLUSTER_NUM" "$NODE_COUNT"; then
    print_success "NiFi configurations generated successfully"
else
    print_error "Configuration generation failed"
    exit 1
fi
cd "$SCRIPT_DIR"
echo ""

# Step 5: Generate docker-compose.yml
print_step 5 5 "Generating docker-compose-${CLUSTER_NAME}.yml"
echo ""

if ./generate-docker-compose.sh "$CLUSTER_NAME" "$CLUSTER_NUM" "$NODE_COUNT"; then
    print_success "docker-compose-${CLUSTER_NAME}.yml generated successfully"
else
    print_error "docker-compose file generation failed"
    exit 1
fi
echo ""

# Success!
print_header "Cluster Creation Complete!"

echo -e "${GREEN}Your ${CLUSTER_NAME} NiFi cluster is ready to start!${NC}"
echo ""
echo -e "${CYAN}Cluster Information:${NC}"
echo "  Name:              ${CLUSTER_NAME}"
echo "  Nodes:             ${NODE_COUNT}"
echo "  Network:           ${CLUSTER_NAME}-network"
echo ""
echo -e "${CYAN}Access URLs:${NC}"
for i in $(seq 1 "$NODE_COUNT"); do
    https_port=$((HTTPS_BASE + i - 1))
    echo "  Node ${i}: https://localhost:${https_port}/nifi"
done
echo ""
echo -e "${CYAN}Default Credentials:${NC}"
echo "  Username:          admin"
echo "  Password:          changeme123456"
echo "  (Set via NIFI_SINGLE_USER_USERNAME and NIFI_SINGLE_USER_PASSWORD in .env)"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Review .env file and update passwords if needed"
echo "  2. Start the cluster:"
echo "     ${YELLOW}docker compose -f docker-compose-${CLUSTER_NAME}.yml up -d${NC}"
echo ""
echo "  3. Monitor startup:"
echo "     ${YELLOW}docker compose -f docker-compose-${CLUSTER_NAME}.yml logs -f${NC}"
echo ""
echo "  4. Wait 2-3 minutes for cluster initialization"
echo ""
echo "  5. Access the NiFi UI at any of the URLs above"
echo ""
echo -e "${CYAN}Useful Commands for ${CLUSTER_NAME}:${NC}"
echo "  View logs:         ${YELLOW}docker compose -f docker-compose-${CLUSTER_NAME}.yml logs -f nifi-1${NC}"
echo "  Check status:      ${YELLOW}docker compose -f docker-compose-${CLUSTER_NAME}.yml ps${NC}"
echo "  Stop cluster:      ${YELLOW}docker compose -f docker-compose-${CLUSTER_NAME}.yml down${NC}"
echo "  Restart cluster:   ${YELLOW}docker compose -f docker-compose-${CLUSTER_NAME}.yml restart${NC}"
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Happy clustering! 🚀                                          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
