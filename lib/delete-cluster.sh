#!/bin/bash
# NiFi Cluster Deletion Script
# Safely removes a cluster including containers, volumes, and configuration
# PRESERVES the shared CA at certs/ca/ (never deleted)
#
# Usage: ./delete-cluster.sh <CLUSTER_NAME> [--force]

set -e

# Script directory - parent directory since script is in lib/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source cluster utilities for color codes with TTY detection
source "${SCRIPT_DIR}/lib/cluster-utils.sh"

# Helper functions
print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}[$1/$2]${NC} $3"
}

print_success() {
    echo -e "  ${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "  ${RED}✗${NC} $1"
}

print_warning() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "  ${CYAN}ℹ${NC} $1"
}

show_help() {
    cat << EOF
NiFi Cluster Deletion Script

Safely removes a cluster including:
  - Docker containers and networks
  - Cluster workspace (certs, config, volumes)
  - Docker Compose file

IMPORTANT: The shared CA (certs/ca/) is NEVER deleted.

Usage:
  $0 <CLUSTER_NAME> [--force]

Arguments:
  CLUSTER_NAME    Name of the cluster to delete (e.g., cluster01)

Options:
  --force, -f     Skip confirmation prompt
  --help, -h      Show this help message

Examples:
  $0 cluster01                 # Delete cluster01 (with confirmation)
  $0 cluster02 --force         # Delete cluster02 (no confirmation)

EOF
    exit 0
}

# Parse arguments
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    show_help
fi

if [ -z "$1" ]; then
    echo -e "${RED}Error: CLUSTER_NAME is required${NC}"
    echo "Run '$0 --help' for usage information"
    exit 1
fi

CLUSTER_NAME="$1"
FORCE_DELETE=false

if [[ "$2" == "--force" ]] || [[ "$2" == "-f" ]]; then
    FORCE_DELETE=true
fi

# Validate cluster name format - matches [text][01-10] pattern from cluster CLI
if [[ ! "$CLUSTER_NAME" =~ ^[a-zA-Z]+[0-9]{2}$ ]]; then
    print_error "Invalid cluster name format"
    print_info "Cluster name must follow pattern: [text][01-10]"
    print_info "Valid examples: cluster01, production05, test03"
    print_info "Invalid examples: cluster1 (one digit), cluster11 (>10), cluster_01 (underscore)"
    exit 1
fi

# Paths
CLUSTER_DIR="clusters/${CLUSTER_NAME}"
COMPOSE_FILE="docker-compose-${CLUSTER_NAME}.yml"
SHARED_CA_DIR="certs/ca"

print_header "NiFi Cluster Deletion - $CLUSTER_NAME"

# Check what exists
echo "Checking cluster resources..."
echo ""

EXISTS_WORKSPACE=false
EXISTS_COMPOSE=false
EXISTS_CONTAINERS=false

if [ -d "$CLUSTER_DIR" ]; then
    EXISTS_WORKSPACE=true
    WORKSPACE_SIZE=$(du -sh "$CLUSTER_DIR" 2>/dev/null | cut -f1)
    print_info "Cluster workspace found: $CLUSTER_DIR ($WORKSPACE_SIZE)"
fi

if [ -f "$COMPOSE_FILE" ]; then
    EXISTS_COMPOSE=true
    print_info "Docker Compose file found: $COMPOSE_FILE"
fi

# Check for running containers (matches both dash and dot separators)
RUNNING_CONTAINERS=$(docker ps -a --format '{{.Names}}' | grep "^${CLUSTER_NAME}[-.]" || true)
if [ -n "$RUNNING_CONTAINERS" ]; then
    EXISTS_CONTAINERS=true
    CONTAINER_COUNT=$(echo "$RUNNING_CONTAINERS" | wc -l)
    print_info "Docker containers found: $CONTAINER_COUNT"
    echo ""
    echo "Containers:"
    echo "$RUNNING_CONTAINERS" | sed 's/^/    /'
fi

echo ""

# Check if anything exists
if [ "$EXISTS_WORKSPACE" = false ] && [ "$EXISTS_COMPOSE" = false ] && [ "$EXISTS_CONTAINERS" = false ]; then
    print_warning "Cluster '$CLUSTER_NAME' does not exist or has already been deleted"
    exit 0
fi

# Show what will be deleted
print_header "Deletion Plan"

echo "The following will be DELETED:"
echo ""

if [ "$EXISTS_CONTAINERS" = true ]; then
    echo "  ${RED}✗${NC} Docker containers (stopped and removed):"
    echo "$RUNNING_CONTAINERS" | sed 's/^/      /'
    echo ""
fi

if [ "$EXISTS_COMPOSE" = true ]; then
    echo "  ${RED}✗${NC} Docker Compose file:"
    echo "      $COMPOSE_FILE"
    echo ""
fi

if [ "$EXISTS_WORKSPACE" = true ]; then
    echo "  ${RED}✗${NC} Cluster workspace (certificates, configs, volumes):"
    echo "      $CLUSTER_DIR/ ($WORKSPACE_SIZE)"
    echo "      - certs/ (node certificates)"
    echo "      - conf/ (node configurations)"
    echo "      - volumes/ (runtime data)"
    echo ""
fi

echo "The following will be ${GREEN}PRESERVED${NC}:"
echo ""
echo "  ${GREEN}✓${NC} Shared Certificate Authority:"
echo "      $SHARED_CA_DIR/ (used by all clusters)"
echo ""

# Confirmation
if [ "$FORCE_DELETE" = false ]; then
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}WARNING: This action cannot be undone!${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Are you sure you want to delete cluster '$CLUSTER_NAME'? (yes/no): " CONFIRM
    echo ""

    if [[ "$CONFIRM" != "yes" ]]; then
        print_info "Deletion cancelled"
        exit 0
    fi
fi

# Start deletion
print_header "Deleting Cluster: $CLUSTER_NAME"

TOTAL_STEPS=4
CURRENT_STEP=1

# Step 1: Stop and remove Docker containers
print_step $CURRENT_STEP $TOTAL_STEPS "Stopping Docker containers"
echo ""

if [ "$EXISTS_COMPOSE" = true ] && [ "$EXISTS_CONTAINERS" = true ]; then
    if docker compose -f "$COMPOSE_FILE" down --volumes 2>/dev/null; then
        print_success "Docker containers and networks removed"
    else
        print_warning "Docker compose down failed, trying manual cleanup"

        # Manual cleanup
        for container in $RUNNING_CONTAINERS; do
            if docker rm -f "$container" 2>/dev/null; then
                print_success "Removed container: $container"
            else
                print_warning "Could not remove container: $container"
            fi
        done
    fi
elif [ "$EXISTS_CONTAINERS" = true ]; then
    print_warning "No compose file found, removing containers manually"

    for container in $RUNNING_CONTAINERS; do
        if docker rm -f "$container" 2>/dev/null; then
            print_success "Removed container: $container"
        else
            print_warning "Could not remove container: $container"
        fi
    done
else
    print_info "No containers to remove"
fi

# Check and remove network
NETWORK_NAME="${CLUSTER_NAME}-nifi-cluster_${CLUSTER_NAME}-network"
if docker network ls | grep -q "$NETWORK_NAME"; then
    if docker network rm "$NETWORK_NAME" 2>/dev/null; then
        print_success "Removed Docker network: $NETWORK_NAME"
    else
        print_warning "Could not remove network (may be in use)"
    fi
fi

echo ""
((CURRENT_STEP++))

# Step 2: Delete Docker Compose file
print_step $CURRENT_STEP $TOTAL_STEPS "Deleting Docker Compose file"
echo ""

if [ "$EXISTS_COMPOSE" = true ]; then
    if rm -f "$COMPOSE_FILE"; then
        print_success "Deleted: $COMPOSE_FILE"
    else
        print_error "Failed to delete: $COMPOSE_FILE"
    fi
else
    print_info "No compose file to delete"
fi

echo ""
((CURRENT_STEP++))

# Step 3: Delete cluster workspace
print_step $CURRENT_STEP $TOTAL_STEPS "Deleting cluster workspace"
echo ""

if [ "$EXISTS_WORKSPACE" = true ]; then
    if sudo rm -rf "$CLUSTER_DIR"; then
        print_success "Deleted: $CLUSTER_DIR/"
        print_info "Removed certificates, configurations, and volumes"
    else
        print_error "Failed to delete: $CLUSTER_DIR/"
    fi
else
    print_info "No workspace to delete"
fi

echo ""
((CURRENT_STEP++))

# Step 4: Verify shared CA is preserved
print_step $CURRENT_STEP $TOTAL_STEPS "Verifying shared CA preservation"
echo ""

if [ -d "$SHARED_CA_DIR" ] && [ -f "$SHARED_CA_DIR/ca-cert.pem" ]; then
    print_success "Shared CA preserved: $SHARED_CA_DIR/"
    print_info "CA can be used for future clusters"
else
    print_warning "Shared CA not found at: $SHARED_CA_DIR/"
    print_info "Will be created when next cluster is generated"
fi

echo ""

# Summary
print_header "Deletion Complete"

echo -e "${GREEN}✓ Cluster '$CLUSTER_NAME' has been deleted${NC}"
echo ""
echo "Summary:"
echo "  - Docker containers: Stopped and removed"
echo "  - Docker networks: Removed"
echo "  - Compose file: Deleted"
echo "  - Cluster workspace: Deleted"
echo "  - Shared CA: ${GREEN}Preserved${NC}"
echo ""
echo "Remaining clusters:"
REMAINING_CLUSTERS=$(ls -1d clusters/cluster*/ 2>/dev/null | xargs -n1 basename 2>/dev/null || true)
if [ -n "$REMAINING_CLUSTERS" ]; then
    echo "$REMAINING_CLUSTERS" | sed 's/^/  - /'
else
    echo "  (none)"
fi
echo ""
