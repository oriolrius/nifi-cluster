---
id: task-018
title: Create Output Port and processing flow in cluster02 via REST API
status: In Progress
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 06:26'
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
Task completed successfully via REST API.

Components Created:
- Output Port ID: 76bc5724-019a-1000-ffff-ffffdc2c4902
- Processor ID: 76bc577d-019a-1000-0000-0000769ce412
- Connection 1 ID: 76bdae97-019a-1000-0000-00002db88b8a (Input→Processor)
- Connection 2 ID: 76bdaf26-019a-1000-0000-000008d9076b (Processor→Output)

Processor Configuration:
- Type: UpdateAttribute
- Name: Add-Response-Metadata
- Custom Properties:
  * processed.by = "cluster02"
  * processed.timestamp = "${now()}"
  * response.status = "SUCCESS"
  * response.cluster = "cluster02"

Flow Architecture:
[From-Cluster01-Request] → [Add-Response-Metadata] → [To-Cluster01-Response]

All components: RUNNING ✓
Both ports visible in S2S endpoint: ✓

Scripts created:
- create-cluster02-flow.sh (initial creation attempt)
- create-connections.sh (connection creation)
- start-cluster02-flow.sh (start components)
- verify-cluster02-flow.sh (verification)
<!-- SECTION:NOTES:END -->
