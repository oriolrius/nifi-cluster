---
id: task-018
title: Create Output Port in cluster02 for sending responses back to cluster01
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
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
