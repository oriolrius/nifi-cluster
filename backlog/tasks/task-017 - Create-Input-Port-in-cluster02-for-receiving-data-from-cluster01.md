---
id: task-017
title: Create Input Port in cluster02 for receiving data from cluster01
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
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
