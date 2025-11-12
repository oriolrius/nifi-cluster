---
id: task-018
title: Create Output Port in cluster02 for sending responses back to cluster01
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 04:33'
labels:
  - site-to-site
  - cluster02
  - output-port
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a root-level Output Port in cluster02 that will send response data back to cluster01 via Site-to-Site protocol. This completes the request-response pattern between clusters.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Output Port named 'To-Cluster01-Response' created at root canvas in cluster02
- [ ] #2 Port is in RUNNING state
- [ ] #3 Port appears in cluster02's site-to-site endpoint outputPorts list
- [ ] #4 Port has access policy allowing 'send data via site-to-site'
- [ ] #5 Internal flow connects Input Port → processing → Output Port
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation Steps

### 1. Create Output Port at Root Canvas
- In cluster02 NiFi UI (https://localhost:31443/nifi)
- Drag 'Output Port' component to root canvas
- Name it: 'To-Cluster01-Response'
- Click 'ADD'

### 2. Configure Output Port
- Right-click → Configure
- Settings:
  - Concurrent tasks: 1
  - Allow Remote Access: ENABLED (critical for S2S)
- Comments: 'Sends processed response back to cluster01'

### 3. Create Simple Processing Flow
Build a flow: Input Port → Processor → Output Port

**Add UpdateAttribute Processor:**
- Drag 'UpdateAttribute' processor to canvas
- Configure properties:
  - Add property: `processed.by` = `cluster02`
  - Add property: `processing.timestamp` = `${now()}`
  - Add property: `response.status` = `SUCCESS`

### 4. Connect Components
```
From-Cluster01-Request (Input Port)
  ↓ (connection: success)
UpdateAttribute
  ↓ (connection: success)
To-Cluster01-Response (Output Port)
```

### 5. Start All Components
- Start UpdateAttribute processor
- Start Output Port
- Verify all components show green 'Running' status

### 6. Verify S2S Output Port Availability
```bash
curl -k -u admin:changeme123456 \
  https://localhost:31443/nifi-api/site-to-site \
  | jq '.controller.outputPorts'
```

Expected:
```json
{
  "id": "<port-id>",
  "name": "To-Cluster01-Response",
  "type": "OUTPUT_PORT"
}
```

## Flow Architecture
```
cluster02 (Remote)
==================
[Input Port: From-Cluster01-Request]
         ↓
    [UpdateAttribute]
     - Add metadata
     - Add timestamp
     - Add status
         ↓
[Output Port: To-Cluster01-Response]
```

## Technical Notes
- Both ports must be at root canvas level
- UpdateAttribute adds response metadata
- Flow must be running before cluster01 can connect
- Connections should have appropriate back-pressure settings
<!-- SECTION:NOTES:END -->
