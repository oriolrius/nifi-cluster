---
id: task-020
title: Build complete request-response flow in cluster01 using RPG to cluster02
status: To Do
assignee: []
created_date: '2025-11-12 04:34'
updated_date: '2025-11-12 04:48'
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
## Prerequisites

**Dependencies:**
- ✅ task-017: Input Port in cluster02 (running)
- ✅ task-018: Output Port + processing flow in cluster02 (running)
- ✅ task-019: RPG in cluster01 configured with both ports enabled

**Verification Checklist:**
```bash
# cluster02: Verify both ports running
open https://localhost:31443/nifi
# Visual: Input Port + UpdateAttribute + Output Port (all green)

# cluster01: Verify RPG connected
open https://localhost:30443/nifi
# Visual: RPG with green indicator, two port icons visible
```

**Manual Reference:** NiFi User Guide > Building Dataflows

## Complete Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│ cluster01 (Initiator)                                           │
│                                                                   │
│  [GenerateFlowFile] → [UpdateAttribute] → [RPG:Input]           │
│   Generate test        Add request         Send to              │
│   data every 30s       metadata            cluster02            │
│                                                ↓                  │
│                                          (HTTPS S2S)             │
│                                                ↓                  │
└────────────────────────────────────────────────┬─────────────────┘
                                                 │
                    ┌────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────────────┐
│ cluster02 (Remote Processor)                                    │
│                                                                   │
│  [Input: From-Cluster01-Request]                                │
│                ↓                                                  │
│  [UpdateAttribute: Add Response Metadata]                       │
│                ↓                                                  │
│  [Output: To-Cluster01-Response]                                │
│                ↓                                                  │
│          (HTTPS S2S)                                             │
│                ↓                                                  │
└────────────────┬───────────────────────────────────────────────┘
                 │
    ┌────────────┘
    ↓
┌─────────────────────────────────────────────────────────────────┐
│ cluster01 (Response Handler)                                    │
│                                                                   │
│  [RPG:Output] → [LogAttribute] → [Terminate]                   │
│   Receive        Display          Delete                        │
│   response       combined         flowfile                      │
│   from           metadata                                        │
│   cluster02                                                      │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation Steps (Manual UI)

### Part A: Build Request Flow in cluster01

Work in: `https://localhost:30443/nifi`

#### Step 1: Add GenerateFlowFile Processor

1. Drag **Processor** to canvas (upper-left area)
2. Search: `GenerateFlowFile`
3. Select: `org.apache.nifi.processors.standard.GenerateFlowFile`
4. Click **ADD**

5. Right-click → **Configure**

6. **PROPERTIES Tab:**
   - **Custom Text:** (click **Set value...**)
     ```json
     {"message": "Hello from cluster01", "timestamp": "${now()}", "test": "inter-cluster-s2s"}
     ```
   - **File Size:** `0B` (uses Custom Text size)
   - **Batch Size:** `1`
   - **Data Format:** `Text`
   - **Unique FlowFiles:** `true` (generates unique data each time)

7. **SCHEDULING Tab:**
   - **Run Schedule:** `30 sec` (generates 1 file every 30 seconds)
   - **Concurrent Tasks:** `1`
   - **Execution:** `All Nodes` (if clustered) or `Primary Node` (for single test)

8. **SETTINGS Tab:**
   - **Name:** `Generate Test Request`
   - **Bulletin Level:** `WARN`
   - **Auto-terminate relationships:**
     - ☐ success (DO NOT check - we need to route this)

9. Click **APPLY**

#### Step 2: Add UpdateAttribute (Request Metadata)

1. Drag **Processor** to canvas (to the right of GenerateFlowFile)
2. Search: `UpdateAttribute`
3. Select: `org.apache.nifi.processors.attributes.UpdateAttribute`
4. Click **ADD**

5. Right-click → **Configure**

6. **PROPERTIES Tab** - Add custom properties:
   
   | Property Name | Property Value |
   |---------------|----------------|
   | `request.id` | `${UUID()}` |
   | `request.timestamp` | `${now()}` |
   | `source.cluster` | `cluster01` |
   | `request.type` | `test-s2s` |

7. **SETTINGS Tab:**
   - **Name:** `Add Request Metadata`

8. Click **APPLY**

#### Step 3: Connect GenerateFlowFile → UpdateAttribute

1. Hover over GenerateFlowFile
2. Drag connection arrow to UpdateAttribute
3. **Create Connection Dialog:**
   - **For relationships:** ☑ `success`
   - **Back Pressure:** (defaults OK)
4. Click **ADD**

#### Step 4: Connect UpdateAttribute → RPG Input Port

1. Hover over UpdateAttribute
2. Drag connection arrow to **RPG** (the cluster02-rpg component)
3. **Create Connection Dialog:**
   - **For relationships:** ☑ `success`
   - **Connect to Remote Input Port:** Select `From-Cluster01-Request`
4. Click **ADD**

**Visual Result:** Connection now points to small port icon on left side of RPG

### Part B: Build Response Flow in cluster01

#### Step 5: Add LogAttribute Processor

1. Drag **Processor** to canvas (to the right of RPG)
2. Search: `LogAttribute`
3. Select: `org.apache.nifi.processors.standard.LogAttribute`
4. Click **ADD**

5. Right-click → **Configure**

6. **PROPERTIES Tab:**
   - **Log Level:** `info`
   - **Log Payload:** `true` (check this - shows flowfile content)
   - **Attributes to Log:** (leave blank - logs all)
   - **Attributes to Log by Regular Expression:** `.*` (logs all attributes)
   - **Attributes to Ignore:** (leave blank)
   - **Attributes to Ignore by Regular Expression:** (leave blank)
   - **Log prefix:** `[RESPONSE FROM CLUSTER02]`

7. **SETTINGS Tab:**
   - **Name:** `Log Response`
   - **Bulletin Level:** `INFO`
   - **Auto-terminate relationships:**
     - ☑ `success` (check this after adding Terminate processor)

8. Click **APPLY**

#### Step 6: Add Terminate Funnel

1. Drag **Funnel** component to canvas (to the right of LogAttribute)
2. **OR** use Terminate processor if preferred:
   - Drag Processor → Search `TerminateFlowFile` → ADD

**Using Funnel (simpler):**
- Funnel automatically consumes/deletes flowfiles
- No configuration needed

**Using TerminateFlowFile processor:**
- Explicitly deletes flowfiles
- Configure → Settings → Auto-terminate: ☑ success

#### Step 7: Connect RPG Output Port → LogAttribute

1. Hover over **RPG** (find the small port icon on **right side**)
2. Drag from RPG's **output port** to LogAttribute
3. **Create Connection Dialog:**
   - **From Remote Output Port:** Select `To-Cluster01-Response`
   - **For relationships:** (auto-selected)
4. Click **ADD**

**Visual Result:** Connection comes from right-side port icon of RPG

#### Step 8: Connect LogAttribute → Terminate/Funnel

1. Hover over LogAttribute
2. Drag connection to Terminate/Funnel
3. **Create Connection Dialog:**
   - **For relationships:** ☑ `success`
4. Click **ADD**

### Part C: Start All Components in cluster01

**Start in this order:**

1. **Right-click GenerateFlowFile → Start** (⬤ Green)
2. **Right-click UpdateAttribute → Start** (⬤ Green)
3. **Right-click LogAttribute → Start** (⬤ Green)
4. **Right-click TerminateFlowFile → Start** (if using processor) (⬤ Green)

**RPG should already be transmitting** (configured in task-019)

### Part D: Verify cluster02 Components Running

Quick check in cluster02: `https://localhost:31443/nifi`

- ✓ Input Port: `From-Cluster01-Request` (⬤ Green)
- ✓ UpdateAttribute: `Add Response Metadata` (⬤ Green)
- ✓ Output Port: `To-Cluster01-Response` (⬤ Green)

## Verification & Testing

### Method 1: Visual Monitoring (Real-Time)

**In cluster01 UI:**

1. **Watch RPG statistics:**
   - Hover over RPG
   - Should show: `Sent: 1, 2, 3...` (incrementing every 30 seconds)
   - Should show: `Received: 1, 2, 3...` (matching sent count)

2. **Watch connection queues:**
   - Connections should briefly show `1 / 1` then clear to `0 / 0`
   - Data flows through quickly (< 1 second round-trip)

3. **Check processor statistics:**
   - Right-click any processor → **View status history**
   - Charts show throughput over time

**In cluster02 UI:**

1. **Watch Input Port statistics:**
   - Right-click Input Port → **View status history**
   - Should show increasing input count

2. **Watch Output Port statistics:**
   - Right-click Output Port → **View status history**
   - Should show increasing output count

### Method 2: Log Monitoring (Detailed)

**cluster01 logs - Watch LogAttribute output:**

```bash
docker compose -f docker-compose-cluster01.yml logs -f nifi-1 \
  | grep -A 20 "RESPONSE FROM CLUSTER02"
```

**Expected log output every 30 seconds:**
```
[RESPONSE FROM CLUSTER02]
Standard FlowFile Attributes
Key: 'entryDate'
  Value: '2025-01-12T04:47:30.123Z'
Key: 'filename'
  Value: '12345678-1234-1234-1234-123456789abc'
Key: 'path'
  Value: './'
Key: 'uuid'
  Value: '12345678-1234-1234-1234-123456789abc'

Additional FlowFile Attributes:
Key: 'request.id'
  Value: 'a1b2c3d4-5678-90ef-ghij-klmnopqrstuv'
Key: 'request.timestamp'
  Value: '1736653650123'
Key: 'source.cluster'
  Value: 'cluster01'
Key: 'request.type'
  Value: 'test-s2s'
Key: 'processed.by'
  Value: 'cluster02'
Key: 'processed.timestamp'
  Value: '1736653650456'
Key: 'response.status'
  Value: 'SUCCESS'
Key: 'response.cluster'
  Value: 'cluster02'

FlowFile Content:
{"message": "Hello from cluster01", "timestamp": "1736653650123", "test": "inter-cluster-s2s"}
```

**Key Attributes to Verify:**
- ✓ `source.cluster: cluster01` (added by cluster01)
- ✓ `processed.by: cluster02` (added by cluster02)
- ✓ `response.status: SUCCESS` (added by cluster02)
- ✓ Both timestamps present (request + processed)

### Method 3: Statistics via API

**cluster01 - Check RPG stats:**
```bash
TOKEN="<cluster01-token>"

curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:30443/nifi-api/flow/process-groups/root \
  | jq '.processGroupFlow.flow.remoteProcessGroups[] | {sent: .sent, received: .received}'
```

**Expected:**
```json
{
  "sent": "3 (3.2 KB)",
  "received": "3 (3.2 KB)"
}
```

**cluster02 - Check port stats:**
```bash
TOKEN="<cluster02-token>"

curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:31443/nifi-api/flow/process-groups/root \
  | jq '.processGroupFlow.flow | {
    inputPorts: .inputPorts[].status.aggregateSnapshot.flowFilesIn,
    outputPorts: .outputPorts[].status.aggregateSnapshot.flowFilesOut
  }'
```

### Method 4: Performance Metrics

**Expected Performance:**
- **Round-trip time:** < 1 second (typically 100-300ms)
- **Throughput:** 2 files/minute (30-second interval)
- **Data size:** ~200 bytes per flowfile
- **Queue buildup:** None (0 / 0 on all connections)

**Monitor for 3-5 minutes:**
- Files processed: 6-10
- No errors in bulletins
- All components green (running)
- Consistent timing (every 30 seconds)

## Expected Result

✅ **Success Indicators:**

**cluster01:**
1. GenerateFlowFile creating files every 30 seconds
2. RPG showing incrementing Sent/Received counters
3. LogAttribute logging combined metadata
4. No flowfiles stuck in queues
5. No error bulletins

**cluster02:**
1. Input Port receiving data
2. UpdateAttribute processing
3. Output Port sending responses
4. Incrementing statistics on all components

**Logs:**
1. LogAttribute shows both cluster01 and cluster02 attributes
2. Payload contains original JSON message
3. Timestamps show sub-second processing

## Troubleshooting

### Issue: No data flowing to cluster02

**Check:**
1. All cluster01 components started (green)?
2. RPG connection shows `Transmitting: true`?
3. RPG port enabled in "Manage Remote Ports"?
4. Connection from UpdateAttribute → RPG correct port?

**Solution:**
```bash
# Check cluster01 logs for S2S errors
docker compose -f docker-compose-cluster01.yml logs nifi-1 \
  | grep -i "site-to-site\|remote\|s2s" | tail -50
```

### Issue: No response from cluster02

**Check:**
1. cluster02 Output Port running?
2. cluster02 flow complete (Input → Update → Output)?
3. RPG output port enabled?
4. Connection from RPG → LogAttribute from correct port?

**Solution:**
```bash
# Check cluster02 logs
docker compose -f docker-compose-cluster02.yml logs nifi-1 \
  | grep -i "site-to-site\|output\|send" | tail -50
```

### Issue: Data stuck in queues

**Check back-pressure:**
1. Right-click connection → **View configuration**
2. Check: Object Threshold (default 10,000)
3. Check: Size Threshold (default 1 GB)

**If queue growing:**
- Increase concurrent tasks on downstream processor
- Add additional processing nodes
- Check for slow processor (bottleneck)

### Issue: LogAttribute not showing attributes

**Check LogAttribute configuration:**
1. **Log Payload:** Must be `true`
2. **Attributes to Log by Regular Expression:** Must be `.*`
3. **Log Level:** Must be `info` or lower

**Check NiFi log level:**
```bash
# View nifi.properties
grep 'logger.level' clusters/cluster01/conf/cluster01-nifi-1/bootstrap.conf
# Should include INFO level for org.apache.nifi.processors.standard.LogAttribute
```

## Performance Tuning (Optional)

### Increase Throughput

**Faster generation:**
- GenerateFlowFile → Run Schedule: `5 sec` (12 files/min)
- GenerateFlowFile → Batch Size: `10` (10 files per trigger)

**More concurrent processing:**
- UpdateAttribute → Concurrent Tasks: `2-4`
- RPG ports → Concurrent Tasks: `2-4`

### Enable Compression

**For large payloads:**
1. Right-click RPG → **Manage Remote Ports**
2. Edit both ports → **Use Compression: true**
3. Reduces network transfer size

### Batch Settings

**For high volume:**
1. Right-click RPG → **Manage Remote Ports**
2. Edit input port:
   - **Batch Count:** `100` (send 100 files per batch)
   - **Batch Duration:** `10 sec` (or send after 10 seconds)
3. Reduces S2S overhead

## Testing Variations

### Test 1: High-Volume Load

- Run Schedule: `1 sec`
- Batch Size: `10`
- Monitor for 5 minutes
- Verify: No queue buildup, all green

### Test 2: Large Payloads

- Custom Text: 10 KB JSON object
- Enable compression
- Monitor round-trip time

### Test 3: Error Handling

- Stop cluster02 Output Port
- Observe queue buildup in cluster02
- Verify: RPG shows appropriate back-pressure
- Restart Output Port
- Verify: Queue drains automatically

## Manual References

- **NiFi User Guide** > Building Dataflows
- **NiFi User Guide** > Processors > GenerateFlowFile
- **NiFi User Guide** > Processors > LogAttribute
- **NiFi User Guide** > Expression Language
- **NiFi Administration Guide** > Monitoring and Management
<!-- SECTION:NOTES:END -->
