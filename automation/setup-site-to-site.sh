#!/bin/bash
#
# Site-to-Site Setup Automation
# Implements tasks 017-020 automatically via NiFi REST API
#
# Usage: ./automation/setup-site-to-site.sh <source_cluster> <dest_cluster>
# Example: ./automation/setup-site-to-site.sh cluster01 cluster02
#

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/nifi-api.sh"

# Parse arguments
SOURCE_CLUSTER=${1:-cluster01}
DEST_CLUSTER=${2:-cluster02}

# Calculate ports based on cluster numbers
SOURCE_NUM=$(echo "$SOURCE_CLUSTER" | sed 's/cluster0*//')
DEST_NUM=$(echo "$DEST_CLUSTER" | sed 's/cluster0*//')

SOURCE_PORT=$((29000 + SOURCE_NUM * 1000 + 443))
DEST_PORT=$((29000 + DEST_NUM * 1000 + 443))

SOURCE_URL="https://localhost:${SOURCE_PORT}"
DEST_URL="https://localhost:${DEST_PORT}"

echo "=========================================="
echo "Site-to-Site Setup Automation"
echo "=========================================="
echo ""
echo "Source: ${SOURCE_CLUSTER} (${SOURCE_URL})"
echo "Destination: ${DEST_CLUSTER} (${DEST_URL})"
echo ""

# Check requirements
nifi_check_requirements || exit 1

#
# TASK-017 & TASK-018: Setup destination cluster (cluster02)
#
echo "-------------------------------------------"
echo "Phase 1: Setup Destination Cluster"
echo "           (Tasks 017-018)"
echo "-------------------------------------------"

echo "  Authenticating to ${DEST_CLUSTER}..."
DEST_TOKEN=$(nifi_get_token "${DEST_URL}")
echo "  ✓ Token obtained"

echo ""
echo "  Creating Input Port..."
INPUT_PORT_ID=$(nifi_create_input_port \
    "${DEST_URL}" \
    "${DEST_TOKEN}" \
    "From-${SOURCE_CLUSTER}-Request" \
    "Receives data from ${SOURCE_CLUSTER} via Site-to-Site")
nifi_log_component "Input Port" "$INPUT_PORT_ID"

echo ""
echo "  Creating Output Port..."
OUTPUT_PORT_ID=$(nifi_create_output_port \
    "${DEST_URL}" \
    "${DEST_TOKEN}" \
    "To-${SOURCE_CLUSTER}-Response" \
    "Sends responses back to ${SOURCE_CLUSTER}")
nifi_log_component "Output Port" "$OUTPUT_PORT_ID"

echo ""
echo "  Creating UpdateAttribute Processor..."
PROCESSOR_ID=$(nifi_create_processor \
    "${DEST_URL}" \
    "${DEST_TOKEN}" \
    "org.apache.nifi.processors.attributes.UpdateAttribute" \
    "Add-Response-Metadata")
nifi_log_component "UpdateAttribute" "$PROCESSOR_ID"

echo ""
echo "  Configuring processor properties..."
nifi_update_processor_properties \
    "${DEST_URL}" \
    "${DEST_TOKEN}" \
    "${PROCESSOR_ID}" \
    '{
        "processed.by": "'"${DEST_CLUSTER}"'",
        "processed.timestamp": "${now()}",
        "response.status": "SUCCESS",
        "response.cluster": "'"${DEST_CLUSTER}"'"
    }'
echo "  ✓ Properties configured"

echo ""
echo "  Creating connections..."
# Connection: Input Port → UpdateAttribute
CONN1_ID=$(nifi_create_connection \
    "${DEST_URL}" \
    "${DEST_TOKEN}" \
    "${INPUT_PORT_ID}" \
    "INPUT_PORT" \
    "${PROCESSOR_ID}" \
    "PROCESSOR" \
    '[]')
nifi_log_component "Connection 1" "$CONN1_ID"

# Connection: UpdateAttribute → Output Port
CONN2_ID=$(nifi_create_connection \
    "${DEST_URL}" \
    "${DEST_TOKEN}" \
    "${PROCESSOR_ID}" \
    "PROCESSOR" \
    "${OUTPUT_PORT_ID}" \
    "OUTPUT_PORT" \
    '["success"]')
nifi_log_component "Connection 2" "$CONN2_ID"

echo ""
echo "  Starting components..."
nifi_start_component "${DEST_URL}" "${DEST_TOKEN}" "${INPUT_PORT_ID}" "input-ports"
nifi_wait_for_running "${DEST_URL}" "${DEST_TOKEN}" "${INPUT_PORT_ID}" "input-ports"
echo "  ✓ Input Port started"

nifi_start_component "${DEST_URL}" "${DEST_TOKEN}" "${PROCESSOR_ID}" "processors"
nifi_wait_for_running "${DEST_URL}" "${DEST_TOKEN}" "${PROCESSOR_ID}" "processors"
echo "  ✓ UpdateAttribute started"

nifi_start_component "${DEST_URL}" "${DEST_TOKEN}" "${OUTPUT_PORT_ID}" "output-ports"
nifi_wait_for_running "${DEST_URL}" "${DEST_TOKEN}" "${OUTPUT_PORT_ID}" "output-ports"
echo "  ✓ Output Port started"

echo ""
echo "✅ Phase 1 Complete: ${DEST_CLUSTER} ready to receive data"

#
# TASK-019: Create Remote Process Group in source cluster
#
echo ""
echo "-------------------------------------------"
echo "Phase 2: Setup Source Cluster RPG"
echo "           (Task 019)"
echo "-------------------------------------------"

echo "  Authenticating to ${SOURCE_CLUSTER}..."
SOURCE_TOKEN=$(nifi_get_token "${SOURCE_URL}")
echo "  ✓ Token obtained"

echo ""
echo "  Creating Remote Process Group..."
RPG_ID=$(nifi_create_rpg \
    "${SOURCE_URL}" \
    "${SOURCE_TOKEN}" \
    "${DEST_URL}/nifi")
nifi_log_component "RPG" "$RPG_ID"

echo ""
echo "  Waiting for RPG to connect (10 seconds)..."
sleep 10

# Note: Enabling RPG transmission requires more complex API calls
# involving port discovery and configuration. For now, manual step required.
echo "  ⚠  RPG transmission must be enabled manually:"
echo "     1. Open ${SOURCE_URL}/nifi"
echo "     2. Right-click RPG → Manage Remote Ports"
echo "     3. Enable both 'From-${SOURCE_CLUSTER}-Request' and 'To-${SOURCE_CLUSTER}-Response'"

echo ""
echo "✅ Phase 2 Complete: RPG created in ${SOURCE_CLUSTER}"

#
# TASK-020: Create test flow in source cluster
#
echo ""
echo "-------------------------------------------"
echo "Phase 3: Create Test Flow"
echo "           (Task 020)"
echo "-------------------------------------------"

echo "  Creating GenerateFlowFile processor..."
GEN_ID=$(nifi_create_processor \
    "${SOURCE_URL}" \
    "${SOURCE_TOKEN}" \
    "org.apache.nifi.processors.standard.GenerateFlowFile" \
    "Generate-Test-Data")
nifi_log_component "GenerateFlowFile" "$GEN_ID"

echo ""
echo "  Configuring GenerateFlowFile..."
nifi_update_processor_properties \
    "${SOURCE_URL}" \
    "${SOURCE_TOKEN}" \
    "${GEN_ID}" \
    '{
        "File Size": "0B",
        "Batch Size": "1",
        "Data Format": "Text",
        "Custom Text": "{\"message\": \"Hello from '"${SOURCE_CLUSTER}"'\", \"timestamp\": \"${now()}\", \"test\": \"inter-cluster-s2s\"}"
    }'
echo "  ✓ Properties configured"

echo ""
echo "  Creating UpdateAttribute processor (request metadata)..."
UPDATE_REQ_ID=$(nifi_create_processor \
    "${SOURCE_URL}" \
    "${SOURCE_TOKEN}" \
    "org.apache.nifi.processors.attributes.UpdateAttribute" \
    "Add-Request-Metadata")
nifi_log_component "UpdateAttribute" "$UPDATE_REQ_ID"

echo ""
echo "  Configuring request metadata..."
nifi_update_processor_properties \
    "${SOURCE_URL}" \
    "${SOURCE_TOKEN}" \
    "${UPDATE_REQ_ID}" \
    '{
        "request.id": "${UUID()}",
        "request.timestamp": "${now()}",
        "source.cluster": "'"${SOURCE_CLUSTER}"'",
        "request.type": "test-s2s"
    }'
echo "  ✓ Properties configured"

echo ""
echo "  Creating LogAttribute processor..."
LOG_ID=$(nifi_create_processor \
    "${SOURCE_URL}" \
    "${SOURCE_TOKEN}" \
    "org.apache.nifi.processors.standard.LogAttribute" \
    "Log-Response")
nifi_log_component "LogAttribute" "$LOG_ID"

echo ""
echo "  Configuring LogAttribute..."
nifi_update_processor_properties \
    "${SOURCE_URL}" \
    "${SOURCE_TOKEN}" \
    "${LOG_ID}" \
    '{
        "Log Level": "info",
        "Log Payload": "true",
        "Attributes to Log": "",
        "Attributes to Log by Regular Expression": ".*",
        "Log prefix": "[RESPONSE FROM '"${DEST_CLUSTER}"']"
    }'
echo "  ✓ Properties configured"

echo ""
echo "  Creating connections..."
# GenerateFlowFile → UpdateAttribute
CONN3_ID=$(nifi_create_connection \
    "${SOURCE_URL}" \
    "${SOURCE_TOKEN}" \
    "${GEN_ID}" \
    "PROCESSOR" \
    "${UPDATE_REQ_ID}" \
    "PROCESSOR" \
    '["success"]')
nifi_log_component "Connection 3" "$CONN3_ID"

echo "  ⚠  Manual connections required to/from RPG:"
echo "     - UpdateAttribute → RPG (From-${SOURCE_CLUSTER}-Request)"
echo "     - RPG (To-${SOURCE_CLUSTER}-Response) → LogAttribute"
echo "     - LogAttribute → [Terminate/Funnel]"

echo ""
echo "  Starting processors..."
nifi_start_component "${SOURCE_URL}" "${SOURCE_TOKEN}" "${UPDATE_REQ_ID}" "processors"
echo "  ✓ UpdateAttribute started"

nifi_start_component "${SOURCE_URL}" "${SOURCE_TOKEN}" "${LOG_ID}" "processors"
echo "  ✓ LogAttribute started"

echo ""
echo "  ⚠  GenerateFlowFile NOT started (prevents data flow until RPG connections complete)"

echo ""
echo "✅ Phase 3 Complete: Test flow created in ${SOURCE_CLUSTER}"

#
# Summary
#
echo ""
echo "=========================================="
echo "Site-to-Site Setup: COMPLETED"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✅ ${DEST_CLUSTER}: Input Port, Output Port, Processing Flow (RUNNING)"
echo "  ✅ ${SOURCE_CLUSTER}: RPG created (connected to ${DEST_CLUSTER})"
echo "  ✅ ${SOURCE_CLUSTER}: Test flow created (processors ready)"
echo ""
echo "Manual Steps Required:"
echo "  1. Enable RPG transmission:"
echo "     - Open ${SOURCE_URL}/nifi"
echo "     - Right-click RPG → Manage Remote Ports"
echo "     - Enable 'From-${SOURCE_CLUSTER}-Request' (Concurrent: 1)"
echo "     - Enable 'To-${SOURCE_CLUSTER}-Response' (Concurrent: 1)"
echo ""
echo "  2. Complete flow connections:"
echo "     - Connect UpdateAttribute → RPG input port"
echo "     - Connect RPG output port → LogAttribute"
echo "     - Connect LogAttribute → Terminate/Funnel"
echo ""
echo "  3. Start data generation:"
echo "     - Right-click GenerateFlowFile → Configure → Scheduling"
echo "     - Set Run Schedule: 30 sec"
echo "     - Right-click GenerateFlowFile → Start"
echo ""
echo "Verification:"
echo "  Watch logs:"
echo "    docker compose -f docker-compose-${SOURCE_CLUSTER}.yml logs -f nifi-1 | grep 'RESPONSE FROM'"
echo ""
echo "  Should see combined attributes from both clusters every 30 seconds"
echo ""
