---
id: task-020
title: Build complete request-response flow in cluster01 using RPG to cluster02
status: To Do
assignee: []
created_date: '2025-11-12 04:34'
updated_date: '2025-11-12 04:35'
labels:
  - site-to-site
  - cluster01
  - end-to-end-flow
  - demo
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create a complete end-to-end flow in cluster01 that: (1) generates sample data, (2) sends it to cluster02 via RPG, (3) receives the processed response back from cluster02, and (4) logs the result. This demonstrates bidirectional inter-cluster communication using Site-to-Site protocol.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GenerateFlowFile processor creates test data in cluster01
- [ ] #2 Data flows through RPG to cluster02 input port
- [ ] #3 cluster02 processes data and sends response to output port
- [ ] #4 RPG receives response from cluster02 output port
- [ ] #5 LogAttribute processor in cluster01 displays the response with cluster02 metadata
- [ ] #6 Complete flow verified with test data showing round-trip timestamps
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Complete Flow Architecture

```
cluster01: [GenerateFlowFile] → [UpdateAttribute] → [RPG Send to cluster02]
                                                              |
                                                              v
cluster02: [Input Port] → [UpdateAttribute] → [Output Port]
                                                              |
                                                              v  
cluster01: [RPG Receive] → [LogAttribute] → [Terminate]
```

## Implementation Steps

### 1. Create Request Flow in cluster01

**GenerateFlowFile:**
- Custom Text: `{"message": "Hello from cluster01", "timestamp": "${now()}", "test": "inter-cluster-s2s"}`
- Run Schedule: 30 sec

**UpdateAttribute (add request metadata):**
- `request.id` = `${UUID()}`
- `request.timestamp` = `${now()}`
- `source.cluster` = `cluster01`

**Connect:** UpdateAttribute → RPG (From-Cluster01-Request port)

### 2. Create Response Flow in cluster01

**LogAttribute:**
- Log Level: info
- Log Payload: true
- Attributes to Log Regex: `.*`

**Connect:** RPG (To-Cluster01-Response port) → LogAttribute → Terminate
<!-- SECTION:NOTES:END -->
