#!/bin/bash
# Check NiFi cluster node status
# Usage: ./check-cluster.sh [cluster_name]
#   If no cluster name provided, checks all available clusters

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/cluster-utils.sh"

# Function to check a single node
check_node() {
    local cluster_name="$1"
    local node="$2"
    local container="${cluster_name}.${node}"

    echo -n "  ${container}: "

    # Check if container exists and is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${RED}NOT RUNNING${NC}"
        return 1
    fi

    # Check if NiFi has started
    if docker exec "$container" sh -c 'grep "Started Application" /opt/nifi/nifi-current/logs/nifi-app*.log 2>/dev/null | tail -1' | grep -q "Started Application"; then
        local start_time=$(docker exec "$container" sh -c 'grep "Started Application" /opt/nifi/nifi-current/logs/nifi-app*.log 2>/dev/null | tail -1' | grep -o "Started Application.*")
        echo -e "${GREEN}✓ READY${NC} - ${start_time}"
        return 0
    else
        echo -e "${YELLOW}⏳ STARTING${NC}"
        return 2
    fi
}

# Function to check an entire cluster
check_cluster() {
    local cluster_name="$1"

    if ! cluster_exists "$cluster_name"; then
        echo -e "${RED}✗ Cluster ${cluster_name} not found${NC}"
        return 1
    fi

    local node_count=$(get_node_count "$cluster_name")
    local cluster_num=$(get_cluster_num "$cluster_name")
    local status=$(get_cluster_status "$cluster_name")

    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Cluster: ${cluster_name}${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "  Status: ${status}"
    echo -e "  Nodes: ${node_count}"

    if [ "$status" = "not-found" ]; then
        return 1
    fi

    if [ "$status" = "stopped" ]; then
        echo -e "${YELLOW}  ⚠ Cluster is not running. Start with:${NC}"
        echo -e "    docker compose -f docker-compose-${cluster_name}.yml up -d"
        return 0
    fi

    echo ""
    echo "Node Status:"

    local ready_count=0
    local starting_count=0
    local failed_count=0

    for i in $(seq 1 "$node_count"); do
        check_node "$cluster_name" "nifi-${i}"
        local result=$?
        case $result in
            0) ready_count=$((ready_count + 1)) ;;
            2) starting_count=$((starting_count + 1)) ;;
            *) failed_count=$((failed_count + 1)) ;;
        esac
    done

    echo ""
    echo "Summary:"
    echo -e "  ${GREEN}Ready:${NC} ${ready_count}/${node_count}"
    if [ $starting_count -gt 0 ]; then
        echo -e "  ${YELLOW}Starting:${NC} ${starting_count}/${node_count}"
    fi
    if [ $failed_count -gt 0 ]; then
        echo -e "  ${RED}Failed:${NC} ${failed_count}/${node_count}"
    fi

    # Print access URLs
    echo ""
    echo "Access URLs:"
    for i in $(seq 1 "$node_count"); do
        local url=$(get_cluster_url "$cluster_name" "$i")
        echo "  Node ${i}: ${url}/nifi"
    done
}

# Main script logic
main() {
    if [ $# -eq 0 ]; then
        # No arguments - check all clusters
        echo -e "${BLUE}Checking all available clusters...${NC}"

        local clusters=($(get_all_clusters))

        if [ ${#clusters[@]} -eq 0 ]; then
            echo -e "${YELLOW}No clusters found. Create one with:${NC}"
            echo "  ./create-cluster.sh cluster01 1 3"
            exit 0
        fi

        for cluster in "${clusters[@]}"; do
            check_cluster "$cluster"
        done
    else
        # Check specific cluster(s)
        for cluster_name in "$@"; do
            if ! validate_cluster_name "$cluster_name"; then
                continue
            fi
            check_cluster "$cluster_name"
        done
    fi
}

# Show help
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    cat << EOF
Usage: $0 [cluster_name...]

Check NiFi cluster node status and readiness.

Options:
  [cluster_name...]  One or more cluster names to check (e.g., cluster01 cluster02)
                     If not provided, checks all available clusters

  -h, --help        Show this help message

Examples:
  $0                # Check all clusters
  $0 cluster01      # Check specific cluster
  $0 cluster01 cluster02  # Check multiple clusters

EOF
    exit 0
fi

main "$@"
