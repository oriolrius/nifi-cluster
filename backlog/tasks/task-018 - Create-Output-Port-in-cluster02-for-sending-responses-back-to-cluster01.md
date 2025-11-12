---
id: task-018
title: Create Output Port in cluster02 for sending responses back to cluster01
status: To Do
assignee: []
created_date: '2025-11-12 04:33'
updated_date: '2025-11-12 04:45'
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
## Prerequisites

**Dependencies:**
- ✅ task-017 completed: Input Port 'From-Cluster01-Request' created and running

**Verify Input Port exists:**
```bash
# In cluster02 NiFi UI, verify Input Port on root canvas
open https://localhost:31443/nifi
```

**Manual Reference:** NiFi User Guide > Components > Output Port

## Implementation Steps (Manual UI)

### Step 1: Create Output Port at Root Canvas

1. In cluster02 NiFi UI: `https://localhost:31443/nifi`
2. Ensure at root canvas level (breadcrumb: **NiFi Flow**)
3. From top toolbar, drag **Output Port** icon (blue circle with arrow pointing out)
4. **Add Port Dialog:**
   - **Port Name:** `To-Cluster01-Response`
   - **Allow remote access:** ☑ **CHECKED** (auto-enabled for root ports)
5. Click **ADD**

### Step 2: Add UpdateAttribute Processor

**Purpose:** Add response metadata to flowfiles before sending back to cluster01

1. Drag **Processor** icon from toolbar to canvas
2. **Add Processor Dialog:**
   - Search: `UpdateAttribute`
   - Select: `org.apache.nifi.processors.attributes.UpdateAttribute`
3. Click **ADD**

### Step 3: Configure UpdateAttribute Processor

1. Right-click UpdateAttribute → **Configure**

2. **PROPERTIES Tab** - Add custom properties (click **+** button):

   | Property Name | Property Value |
   |---------------|----------------|
   | `processed.by` | `cluster02` |
   | `processed.timestamp` | `${now()}` |
   | `response.status` | `SUCCESS` |
   | `response.cluster` | `cluster02` |

   **Expression Language:**
   - `${now()}` - Current timestamp in milliseconds
   - All properties use NiFi Expression Language (EL)

3. **SETTINGS Tab:**
   - **Name:** `Add Response Metadata`
   - **Penalty Duration:** `30 sec` (default)
   - **Yield Duration:** `1 sec` (default)
   - **Bulletin Level:** `WARN` (default)

4. **SCHEDULING Tab:**
   - **Concurrent Tasks:** `1`
   - **Run Schedule:** `0 sec` (run continuously)

5. Click **APPLY**

### Step 4: Create Connections

**Connection 1: Input Port → UpdateAttribute**

1. Hover over Input Port `From-Cluster01-Request`
2. Drag connection arrow to UpdateAttribute processor
3. **Create Connection Dialog:**
   - **For relationships:** ☑ (auto-selected, input ports have no relationships)
   - **Back Pressure:**
     - Object Threshold: `10000` (default)
     - Size Threshold: `1 GB` (default)
   - **Load Balance Strategy:** `Do not load balance` (single node processing)
4. Click **ADD**

**Connection 2: UpdateAttribute → Output Port**

1. Hover over UpdateAttribute processor
2. Drag connection arrow to Output Port `To-Cluster01-Response`
3. **Create Connection Dialog:**
   - **For relationships:** ☑ `success` (check this)
   - **Back Pressure:** (use defaults)
   - **Load Balance Strategy:** `Do not load balance`
4. Click **ADD**

**IMPORTANT:** UpdateAttribute has `failure` relationship - leave unconnected (processor will error if attribute update fails).

### Step 5: Configure Output Port Settings

1. Right-click Output Port → **Configure**
2. **SETTINGS Tab:**
   - **Name:** `To-Cluster01-Response` (confirm)
   - **Concurrent tasks:** `1`
   - **Comments:** `Sends processed response back to cluster01 via Site-to-Site`
3. Click **APPLY**

### Step 6: Start All Components (Sequential)

**Start Order Matters:**

1. **Start Input Port:**
   - Right-click `From-Cluster01-Request` → **Start**
   - Status: ⬤ Green (running)

2. **Start UpdateAttribute:**
   - Right-click UpdateAttribute → **Start**
   - Status: ⬤ Green (running)

3. **Start Output Port:**
   - Right-click `To-Cluster01-Response` → **Start**
   - Status: ⬤ Green (running)

**All components should show green status indicators**

### Step 7: Verify Flow Visually

Expected canvas layout:
```
[From-Cluster01-Request] ──→ [UpdateAttribute] ──→ [To-Cluster01-Response]
     (Input Port)           (Add Response Metadata)      (Output Port)
         ⬤ Green                  ⬤ Green                   ⬤ Green
```

Connection counters should show: `0 / 0` (queued / total)

## Verification Methods

### Method 1: Site-to-Site API Verification

```bash
# Get JWT token from UI first (see task-017 for instructions)
TOKEN="<your-token>"

curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:31443/nifi-api/site-to-site \
  | jq '.controller | {inputPorts: .inputPorts, outputPorts: .outputPorts}'
```

**Expected Output:**
```json
{
  "inputPorts": [
    {
      "id": "<input-port-id>",
      "name": "From-Cluster01-Request",
      "type": "INPUT_PORT"
    }
  ],
  "outputPorts": [
    {
      "id": "<output-port-id>",
      "name": "To-Cluster01-Response",
      "type": "OUTPUT_PORT"
    }
  ]
}
```

### Method 2: Check Processor Configuration

```bash
# List processors in root process group
curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:31443/nifi-api/process-groups/root/processors \
  | jq '.processors[] | {name: .component.name, type: .component.type, state: .component.state}'
```

Expected: UpdateAttribute processor with state: `RUNNING`

### Method 3: Manual Testing (with task-019 completed)

Once cluster01 RPG is configured:
1. Generate test data in cluster01
2. Send via RPG to `From-Cluster01-Request`
3. Check UpdateAttribute statistics (right-click → **View status history**)
4. Verify flowfiles appear at `To-Cluster01-Response`

## Flow Architecture Details

```
┌─────────────────────────────────────────────────────────────┐
│ cluster02 (Remote Side)                                     │
│                                                               │
│  [From-Cluster01-Request]  ← Receives from cluster01 RPG    │
│           │                                                   │
│           ↓                                                   │
│  [UpdateAttribute]         ← Adds response metadata         │
│   Properties:                                                │
│   - processed.by = "cluster02"                              │
│   - processed.timestamp = "${now()}"                        │
│   - response.status = "SUCCESS"                             │
│   - response.cluster = "cluster02"                          │
│           │                                                   │
│           ↓                                                   │
│  [To-Cluster01-Response]   ← Sends back to cluster01 RPG   │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## UpdateAttribute NiFi Expression Language

**Functions Used:**
- `${now()}` - Current system time in milliseconds (Long)
- Returns: Unix epoch timestamp (e.g., `1699804800000`)

**Expression Language Reference:**
- Manual: NiFi Expression Language Guide
- Available in UI: Click **?** icon in property value field

## Expected Result

✅ **Success Indicators:**
1. Input Port `From-Cluster01-Request`: Green, running
2. UpdateAttribute processor: Green, running, 0 errors
3. Output Port `To-Cluster01-Response`: Green, running
4. Both ports appear in S2S API endpoint
5. All connections show `0 / 0` (no data yet)
6. Ready to process requests from cluster01

## Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Output Port not in S2S API | Created in Process Group | Move to root canvas |
| UpdateAttribute shows errors | Invalid EL syntax | Verify `${now()}` syntax |
| Connection shows warning | No relationship selected | Select `success` relationship |
| Data stuck in queue | Component not started | Start all components |
| Back-pressure threshold | Queue full | Increase thresholds or add terminate processor |

## Testing Notes

**Without cluster01 Connected:**
- Flow will remain idle (no data)
- All components running (green status)
- Queue counters: `0 / 0`

**With cluster01 Connected (task-019+):**
- Data flows through automatically
- UpdateAttribute adds metadata
- Response sent via Output Port
- Monitor via Statistics (right-click components → **Stats**)

## Manual References

- **NiFi User Guide** > Components > Output Port
- **NiFi User Guide** > Expression Language
- **NiFi User Guide** > Processors > UpdateAttribute
- **NiFi Administration Guide** > Site-to-Site Properties
<!-- SECTION:NOTES:END -->
