#!/bin/bash
# Cluster Utilities Library
# Provides functions to automatically detect cluster parameters

# Color codes for output - only enable if outputting to a terminal
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    MAGENTA=''
    CYAN=''
    NC=''
fi

# Extract cluster number from cluster name
# Usage: cluster_num=$(get_cluster_num "cluster01")
# Returns: 1 (for cluster01), 2 (for cluster02), etc.
get_cluster_num() {
    local cluster_name="$1"
    echo "$cluster_name" | sed -E 's/^cluster0*([0-9]+)$/\1/'
}

# Calculate base port from cluster number
# Usage: base_port=$(get_base_port 1)
get_base_port() {
    local cluster_num="$1"
    echo $((29000 + (cluster_num * 1000)))
}

# Calculate HTTPS port from cluster number and node index
# Usage: https_port=$(get_https_port 1 1)  # cluster 1, node 1
get_https_port() {
    local cluster_num="$1"
    local node_index="$2"
    local base_port=$(get_base_port "$cluster_num")
    echo $((base_port + 443 + node_index - 1))
}

# Count nodes in a cluster by checking docker-compose file
# Usage: node_count=$(get_node_count "cluster01")
get_node_count() {
    local cluster_name="$1"
    local compose_file="docker-compose-${cluster_name}.yml"

    if [ ! -f "$compose_file" ]; then
        echo "0"
        return 1
    fi

    # Count services that match the pattern: cluster_name-nifi-*
    grep -E "^  ${cluster_name}-nifi-[0-9]+:" "$compose_file" | wc -l
}

# Get list of running containers for a cluster
# Usage: containers=$(get_cluster_containers "cluster01")
get_cluster_containers() {
    local cluster_name="$1"
    docker ps --format '{{.Names}}' | grep "^${cluster_name}\." | sort
}

# Check if cluster docker-compose file exists
# Usage: if cluster_exists "cluster01"; then ...
cluster_exists() {
    local cluster_name="$1"
    [ -f "docker-compose-${cluster_name}.yml" ]
}

# Get all available clusters
# Usage: clusters=$(get_all_clusters)
get_all_clusters() {
    ls docker-compose-cluster*.yml 2>/dev/null | sed -E 's/docker-compose-(cluster[0-9]+)\.yml/\1/' | sort
}

# Check if cluster is running
# Usage: if cluster_is_running "cluster01"; then ...
cluster_is_running() {
    local cluster_name="$1"
    local container_count=$(docker ps --filter "name=${cluster_name}." --format '{{.Names}}' | wc -l)
    [ "$container_count" -gt 0 ]
}

# Get cluster status (running/stopped/not-found)
# Usage: status=$(get_cluster_status "cluster01")
get_cluster_status() {
    local cluster_name="$1"

    if ! cluster_exists "$cluster_name"; then
        echo "not-found"
        return 1
    fi

    if cluster_is_running "$cluster_name"; then
        echo "running"
    else
        echo "stopped"
    fi
}

# Print cluster information
# Usage: print_cluster_info "cluster01"
print_cluster_info() {
    local cluster_name="$1"
    local cluster_num=$(get_cluster_num "$cluster_name")
    local node_count=$(get_node_count "$cluster_name")
    local base_port=$(get_base_port "$cluster_num")
    local https_base=$((base_port + 443))
    local status=$(get_cluster_status "$cluster_name")

    echo -e "${BLUE}Cluster:${NC} ${cluster_name}"
    echo -e "${BLUE}Number:${NC} ${cluster_num}"
    echo -e "${BLUE}Nodes:${NC} ${node_count}"
    echo -e "${BLUE}Base Port:${NC} ${base_port}"
    echo -e "${BLUE}HTTPS Ports:${NC} ${https_base}-$((https_base + node_count - 1))"
    echo -e "${BLUE}Status:${NC} ${status}"
}

# Validate cluster name format
# Usage: if validate_cluster_name "cluster01"; then ...
validate_cluster_name() {
    local cluster_name="$1"
    if [[ ! "$cluster_name" =~ ^cluster[0-9]+$ ]]; then
        echo -e "${RED}Error: Invalid cluster name format. Expected: cluster01, cluster02, etc.${NC}" >&2
        return 1
    fi
    return 0
}

# Get NiFi API URL for cluster
# Usage: url=$(get_cluster_url "cluster01" 1)  # cluster01, node 1
get_cluster_url() {
    local cluster_name="$1"
    local node_index="${2:-1}"  # Default to node 1
    local cluster_num=$(get_cluster_num "$cluster_name")
    local https_port=$(get_https_port "$cluster_num" "$node_index")
    echo "https://localhost:${https_port}"
}

# Wait for cluster to be ready
# Usage: wait_for_cluster "cluster01" 120  # wait up to 120 seconds
wait_for_cluster() {
    local cluster_name="$1"
    local timeout="${2:-180}"
    local node_count=$(get_node_count "$cluster_name")
    local elapsed=0
    local interval=5

    echo -e "${YELLOW}Waiting for ${cluster_name} to be ready (up to ${timeout}s)...${NC}"

    while [ $elapsed -lt $timeout ]; do
        local ready_count=0

        for i in $(seq 1 "$node_count"); do
            local container="${cluster_name}.nifi-${i}"
            if docker exec "$container" test -f /opt/nifi/nifi-current/logs/nifi-app.log 2>/dev/null; then
                if docker exec "$container" grep -q "Started Application" /opt/nifi/nifi-current/logs/nifi-app.log 2>/dev/null; then
                    ready_count=$((ready_count + 1))
                fi
            fi
        done

        if [ "$ready_count" -eq "$node_count" ]; then
            echo -e "${GREEN}✓ All ${node_count} nodes are ready!${NC}"
            return 0
        fi

        echo -e "  ${ready_count}/${node_count} nodes ready... (${elapsed}s elapsed)"
        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo -e "${RED}✗ Timeout waiting for cluster to be ready${NC}"
    return 1
}
