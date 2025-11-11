---
id: task-002
title: Create shared CA generation script (generate-ca.sh)
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
Implement one-time script to generate the shared Certificate Authority that will be used by all clusters.

Script should:
- Generate CA private key (2048-bit RSA)
- Generate CA certificate (10-year validity)
- Create JKS and PKCS12 truststores
- Store in shared/certs/ca/
- Be idempotent (don't overwrite existing CA)

Reference: Analysis report section 11.2 step 1
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Script creates CA key and certificate
- [ ] #2 Both JKS and PKCS12 truststores generated
- [ ] #3 Script validates existing CA before regenerating
- [ ] #4 Proper error handling and logging implemented
<!-- AC:END -->
