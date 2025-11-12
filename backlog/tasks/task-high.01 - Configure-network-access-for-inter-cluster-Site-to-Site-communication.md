---
id: task-high.01
title: Configure network access for inter-cluster Site-to-Site communication
status: To Do
assignee: []
created_date: '2025-11-12 04:32'
labels:
  - site-to-site
  - networking
  - inter-cluster
dependencies: []
parent_task_id: task-high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enable network connectivity between cluster01 and cluster02 for NiFi Site-to-Site (S2S) protocol using HTTPS transport. Both clusters are already configured with nifi.remote.input.http.enabled=true and nifi.remote.input.secure=true in nifi.properties.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Verify cluster01 can reach cluster02's HTTPS endpoint (https://localhost:31443/nifi-api/site-to-site)
- [ ] #2 Verify cluster02 can reach cluster01's HTTPS endpoint (https://localhost:30443/nifi-api/site-to-site)
- [ ] #3 Confirm both clusters share the same CA certificate for TLS trust
- [ ] #4 Test S2S handshake using curl from host to both cluster endpoints
<!-- AC:END -->
