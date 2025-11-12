#!/bin/bash
#
# NiFi REST API Library
# Reusable functions for interacting with NiFi REST API
#
# Usage: source automation/lib/nifi-api.sh
#

set -eo pipefail

# Default credentials (can be overridden)
: ${NIFI_USERNAME:="admin"}
: ${NIFI_PASSWORD:="changeme123456"}

#
# Authentication
#

# Get JWT token from NiFi
# Args: $1=base_url (e.g., https://localhost:30443)
# Returns: JWT token string
nifi_get_token() {
    local url=$1

    curl -k -s -X POST "${url}/nifi-api/access/token" \
        -d "username=${NIFI_USERNAME}&password=${NIFI_PASSWORD}" \
        2>/dev/null || {
            echo "ERROR: Failed to get token from ${url}" >&2
            return 1
        }
}

#
# Component Creation
#

# Create Input Port
# Args: $1=base_url $2=token $3=name $4=comments
# Returns: Port ID
nifi_create_input_port() {
    local url=$1
    local token=$2
    local name=$3
    local comments=${4:-"Created via API"}

    local response=$(curl -k -s -X POST \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        "${url}/nifi-api/process-groups/root/input-ports" \
        -d "{
            \"revision\": {\"version\": 0},
            \"component\": {
                \"name\": \"${name}\",
                \"comments\": \"${comments}\"
            }
        }")

    echo "$response" | jq -r '.component.id // empty' || {
        echo "ERROR: Failed to create input port '${name}'" >&2
        echo "$response" | jq -r '.status, .statusText' >&2
        return 1
    }
}

# Create Output Port
# Args: $1=base_url $2=token $3=name $4=comments
# Returns: Port ID
nifi_create_output_port() {
    local url=$1
    local token=$2
    local name=$3
    local comments=${4:-"Created via API"}

    local response=$(curl -k -s -X POST \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        "${url}/nifi-api/process-groups/root/output-ports" \
        -d "{
            \"revision\": {\"version\": 0},
            \"component\": {
                \"name\": \"${name}\",
                \"comments\": \"${comments}\"
            }
        }")

    echo "$response" | jq -r '.component.id // empty' || {
        echo "ERROR: Failed to create output port '${name}'" >&2
        return 1
    }
}

# Create Processor
# Args: $1=base_url $2=token $3=type $4=name
# Returns: Processor ID
nifi_create_processor() {
    local url=$1
    local token=$2
    local type=$3
    local name=$4

    local response=$(curl -k -s -X POST \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        "${url}/nifi-api/process-groups/root/processors" \
        -d "{
            \"revision\": {\"version\": 0},
            \"component\": {
                \"type\": \"${type}\",
                \"name\": \"${name}\"
            }
        }")

    echo "$response" | jq -r '.component.id // empty' || {
        echo "ERROR: Failed to create processor '${name}'" >&2
        return 1
    }
}

# Create Remote Process Group
# Args: $1=base_url $2=token $3=target_uri
# Returns: RPG ID
nifi_create_rpg() {
    local url=$1
    local token=$2
    local target_uri=$3

    local response=$(curl -k -s -X POST \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        "${url}/nifi-api/process-groups/root/remote-process-groups" \
        -d "{
            \"revision\": {\"version\": 0},
            \"component\": {
                \"targetUri\": \"${target_uri}\"
            }
        }")

    echo "$response" | jq -r '.component.id // empty' || {
        echo "ERROR: Failed to create RPG to ${target_uri}" >&2
        return 1
    }
}

#
# Component Configuration
#

# Update Processor Properties
# Args: $1=base_url $2=token $3=processor_id $4=properties_json
nifi_update_processor_properties() {
    local url=$1
    local token=$2
    local processor_id=$3
    local properties_json=$4

    # Get current revision
    local current=$(curl -k -s -H "Authorization: Bearer ${token}" \
        "${url}/nifi-api/processors/${processor_id}")

    local version=$(echo "$current" | jq -r '.revision.version')

    # Update with new properties
    curl -k -s -X PUT \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        "${url}/nifi-api/processors/${processor_id}" \
        -d "{
            \"revision\": {\"version\": ${version}},
            \"component\": {
                \"id\": \"${processor_id}\",
                \"config\": {
                    \"properties\": ${properties_json}
                }
            }
        }" > /dev/null
}

# Create Connection
# Args: $1=base_url $2=token $3=source_id $4=source_type $5=dest_id $6=dest_type $7=relationships
nifi_create_connection() {
    local url=$1
    local token=$2
    local source_id=$3
    local source_type=$4  # PROCESSOR, INPUT_PORT, OUTPUT_PORT, FUNNEL
    local dest_id=$5
    local dest_type=$6
    local relationships=$7  # JSON array, e.g., ["success"]

    local response=$(curl -k -s -X POST \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        "${url}/nifi-api/process-groups/root/connections" \
        -d "{
            \"revision\": {\"version\": 0},
            \"component\": {
                \"source\": {
                    \"id\": \"${source_id}\",
                    \"type\": \"${source_type}\"
                },
                \"destination\": {
                    \"id\": \"${dest_id}\",
                    \"type\": \"${dest_type}\"
                },
                \"selectedRelationships\": ${relationships}
            }
        }")

    echo "$response" | jq -r '.component.id // empty' || {
        echo "ERROR: Failed to create connection ${source_id} -> ${dest_id}" >&2
        return 1
    }
}

#
# Component Lifecycle
#

# Start Component (Processor, Port, etc.)
# Args: $1=base_url $2=token $3=component_id $4=component_type
nifi_start_component() {
    local url=$1
    local token=$2
    local component_id=$3
    local component_type=$4  # processors, input-ports, output-ports

    # Get current revision
    local current=$(curl -k -s -H "Authorization: Bearer ${token}" \
        "${url}/nifi-api/${component_type}/${component_id}")

    local version=$(echo "$current" | jq -r '.revision.version')

    # Start component
    curl -k -s -X PUT \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        "${url}/nifi-api/${component_type}/${component_id}/run-status" \
        -d "{
            \"revision\": {\"version\": ${version}},
            \"state\": \"RUNNING\"
        }" > /dev/null
}

# Stop Component
# Args: $1=base_url $2=token $3=component_id $4=component_type
nifi_stop_component() {
    local url=$1
    local token=$2
    local component_id=$3
    local component_type=$4

    local current=$(curl -k -s -H "Authorization: Bearer ${token}" \
        "${url}/nifi-api/${component_type}/${component_id}")

    local version=$(echo "$current" | jq -r '.revision.version')

    curl -k -s -X PUT \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        "${url}/nifi-api/${component_type}/${component_id}/run-status" \
        -d "{
            \"revision\": {\"version\": ${version}},
            \"state\": \"STOPPED\"
        }" > /dev/null
}

#
# Verification & Query
#

# Get Component Status
# Args: $1=base_url $2=token $3=component_id $4=component_type
# Returns: State (RUNNING, STOPPED, etc.)
nifi_get_component_status() {
    local url=$1
    local token=$2
    local component_id=$3
    local component_type=$4

    curl -k -s -H "Authorization: Bearer ${token}" \
        "${url}/nifi-api/${component_type}/${component_id}" \
        | jq -r '.component.state'
}

# Wait for Component to be Running
# Args: $1=base_url $2=token $3=component_id $4=component_type $5=timeout_sec
nifi_wait_for_running() {
    local url=$1
    local token=$2
    local component_id=$3
    local component_type=$4
    local timeout=${5:-30}

    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local state=$(nifi_get_component_status "$url" "$token" "$component_id" "$component_type")

        if [ "$state" == "RUNNING" ]; then
            return 0
        fi

        sleep 1
        elapsed=$((elapsed + 1))
    done

    echo "ERROR: Component ${component_id} did not start within ${timeout} seconds" >&2
    return 1
}

# List all Input Ports
# Args: $1=base_url $2=token
# Returns: JSON array of ports
nifi_list_input_ports() {
    local url=$1
    local token=$2

    curl -k -s -H "Authorization: Bearer ${token}" \
        "${url}/nifi-api/flow/process-groups/root" \
        | jq -r '.processGroupFlow.flow.inputPorts'
}

# List all Output Ports
# Args: $1=base_url $2=token
# Returns: JSON array of ports
nifi_list_output_ports() {
    local url=$1
    local token=$2

    curl -k -s -H "Authorization: Bearer ${token}" \
        "${url}/nifi-api/flow/process-groups/root" \
        | jq -r '.processGroupFlow.flow.outputPorts'
}

# Check Site-to-Site Endpoint
# Args: $1=base_url $2=token
# Returns: S2S configuration JSON
nifi_get_site_to_site_config() {
    local url=$1
    local token=$2

    curl -k -s -H "Authorization: Bearer ${token}" \
        "${url}/nifi-api/site-to-site"
}

#
# Utility Functions
#

# Pretty print component info
# Args: $1=component_name $2=component_id
nifi_log_component() {
    local name=$1
    local id=$2
    echo "  ✓ ${name}: ${id}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verify required tools
nifi_check_requirements() {
    local missing=()

    command_exists curl || missing+=("curl")
    command_exists jq || missing+=("jq")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "ERROR: Missing required tools: ${missing[*]}" >&2
        echo "Install with: sudo apt-get install ${missing[*]}" >&2
        return 1
    fi

    return 0
}
