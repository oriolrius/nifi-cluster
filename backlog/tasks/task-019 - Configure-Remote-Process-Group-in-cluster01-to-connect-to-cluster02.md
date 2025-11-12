---
id: task-019
title: Configure Remote Process Group in cluster01 to connect to cluster02
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
labels:
  - site-to-site
  - cluster01
  - remote-process-group
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create and configure a Remote Process Group (RPG) in cluster01 that connects to cluster02 using HTTPS Site-to-Site protocol. The RPG will enable cluster01 to send data to cluster02's input port and receive responses from cluster02's output port.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 RPG component created in cluster01 pointing to https://localhost:31443/nifi
- [ ] #2 RPG successfully connects and retrieves cluster02 site-to-site details
- [ ] #3 RPG shows cluster02's input port 'From-Cluster01-Request' as available
- [ ] #4 RPG shows cluster02's output port 'To-Cluster01-Response' as available
- [ ] #5 Transport Protocol set to HTTPS (not RAW)
- [ ] #6 RPG shows green 'transmitting' indicator when active
<!-- AC:END -->
