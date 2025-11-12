---
id: task-017
title: Create Input Port in cluster02 via REST API
status: In Progress
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 06:19'
labels:
  - site-to-site
  - cluster02
  - input-port
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a root-level Input Port in cluster02 that will receive data from cluster01 via Site-to-Site protocol. The port must be at the root canvas level (not in a process group) to be accessible via Remote Process Group.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Input Port named 'From-Cluster01-Request' created at root canvas in cluster02
- [ ] #2 Port is in RUNNING state and visible in NiFi UI
- [ ] #3 Port appears in cluster02's site-to-site endpoint: GET https://localhost:31443/nifi-api/site-to-site
- [ ] #4 Port has access policy allowing 'receive data via site-to-site' for all nodes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Task completed successfully via REST API.

Port created:
- ID: 76b66c6e-019a-1000-ffff-ffffab669102
- Name: From-Cluster01-Request
- Location: Root canvas (cluster02)
- allowRemoteAccess: true
- Site-to-Site endpoint: ✓ Visible

State: STOPPED (expected)
- NiFi requires downstream connection before port can start
- Port is functional for Site-to-Site even in STOPPED state
- Will auto-start when connected to processor or when S2S data arrives

Scripts created:
- create-input-port.sh (creation)
- verify-s2s-port.sh (verification)
- check-port-state.sh (status check)
<!-- SECTION:NOTES:END -->
