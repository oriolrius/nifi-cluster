---
id: task-003
title: >-
  Create cluster-specific certificate generation script
  (generate-cluster-certs.sh)
status: To Do
assignee: []
created_date: '2025-11-11 14:59'
labels:
  - pki
  - security
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement script to generate certificates for all nodes in a cluster using the shared CA.

Script should accept parameters:
- CLUSTER_NAME (e.g., cluster01)
- NODE_COUNT (default 3)

Generate certificates for:
- NiFi nodes: cluster01-nifi01, cluster01-nifi02, cluster01-nifi03
- ZooKeeper nodes: cluster01-zk01, cluster01-zk02, cluster01-zk03

Each cert should include proper SAN entries (DNS: node name, localhost; IP: 127.0.0.1)

Reference: Analysis report section 11.2 step 2
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Script generates node certificates signed by shared CA
- [ ] #2 SAN entries include hostname and localhost
- [ ] #3 PKCS12 keystores and truststores created
- [ ] #4 Certificate validation passes (openssl verify)
<!-- AC:END -->
