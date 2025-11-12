# doc-005: NiFi REST API Automation Strategy

**Status:** Active
**Created:** 2025-11-12
**Updated:** 2025-11-12
**Category:** Architecture Decision

---

## Context

Initial Site-to-Site setup tasks (017-020) were designed as manual UI workflows requiring human interaction. Investigation revealed that NiFi's REST API supports full automation of all required operations.

## Problem Statement

Manual UI-based workflows have significant limitations:
- **Time-consuming:** 10-15 minutes per cluster setup
- **Error-prone:** Human clicking mistakes, missed steps
- **Not repeatable:** Cannot be version-controlled or CI/CD integrated
- **Documentation burden:** Requires screenshots, detailed step-by-step instructions
- **Testing overhead:** Manual verification after each change

## Investigation Results

### REST API Capabilities Proven

Tested operations on live clusters (cluster01, cluster02):

| Operation | Endpoint | Status | Evidence |
|-----------|----------|--------|----------|
| **Token Authentication** | `POST /access/token` | ✅ WORKS | JWT token obtained programmatically |
| **Create Input Port** | `POST /process-groups/root/input-ports` | ✅ WORKS | Port ID: 7669019f-019a-1000-* |
| **Create Output Port** | `POST /process-groups/root/output-ports` | ✅ WORKS | Port ID: 766901e6-019a-1000-* |
| **Create Processor** | `POST /process-groups/root/processors` | ✅ WORKS | Multiple processors created |
| **Create RPG** | `POST /process-groups/root/remote-process-groups` | ✅ WORKS | RPG ID: 766902f9-019a-1000-* |
| **Update Properties** | `PUT /processors/{id}` | ✅ DOCUMENTED | Standard NiFi API |
| **Create Connection** | `POST /process-groups/{id}/connections` | ✅ DOCUMENTED | Standard NiFi API |
| **Start/Stop** | `PUT /processors/{id}/run-status` | ✅ DOCUMENTED | Standard NiFi API |
| **Enable RPG Transmission** | `PUT /remote-process-groups/{id}` | ✅ DOCUMENTED | Standard NiFi API |

**Proof of Concept:** `test-nifi-api-automation.sh` successfully created components in both clusters.

### Authentication Method

**Single-User Mode (current setup):**
```bash
curl -k -X POST https://localhost:30443/nifi-api/access/token \
  -d "username=admin&password=changeme123456"
```

Returns JWT token valid for 1 hour (configurable via `nifi.security.user.jws.key.rotation.period`).

**Token Usage:**
```bash
curl -k -H "Authorization: Bearer ${TOKEN}" \
  https://localhost:30443/nifi-api/...
```

## Decision

**ADOPT API-first automation for all programmatic tasks.**

### Task Categories

**Category A: Automation-First Tasks**
- Tasks that can be fully automated via API
- Should be implemented as scripts with optional manual verification
- Examples: task-017, task-018, task-019, task-020

**Category B: Learning/Documentation Tasks**
- Tasks that teach NiFi UI concepts
- Keep as manual UI guides
- Examples: exploring NiFi UI, understanding flow design patterns

**Category C: Troubleshooting Tasks**
- Tasks for debugging issues
- Keep as manual guides with API commands for verification
- Examples: investigating failed flows, certificate issues

## Implementation Strategy

### Phase 1: Rewrite Automation Tasks (CURRENT)

**Update tasks 017-020:**
- Primary implementation: Bash scripts using REST API
- Secondary documentation: Manual UI steps (for reference/troubleshooting)
- Verification: Automated checks via API

**Structure:**
```markdown
## Implementation (Automated)

### Script: automation/setup-site-to-site.sh

**Usage:**
```bash
./automation/setup-site-to-site.sh cluster01 cluster02
```

**What it does:**
1. Authenticates to both clusters
2. Creates Input/Output ports in cluster02
3. Creates processing flow in cluster02
4. Creates RPG in cluster01
5. Creates test flow in cluster01
6. Starts all components
7. Verifies end-to-end communication

**Execution time:** ~30 seconds

## Manual Reference (Optional)

For learning purposes, here's how to do this via UI:
[Keep abbreviated UI steps for reference]
```

### Phase 2: Create Automation Library

**New directory structure:**
```
nifi-cluster/
├── automation/
│   ├── lib/
│   │   ├── nifi-api.sh          # Reusable API functions
│   │   └── nifi-common.sh       # Common utilities
│   ├── setup-site-to-site.sh    # Tasks 017-020 automated
│   ├── create-test-flow.sh      # Task 020 only
│   └── verify-s2s.sh            # Verification script
└── backlog/
    ├── docs/
    │   └── doc-005 - NiFi-REST-API-Automation-Strategy.md
    └── tasks/
        ├── task-017.md          # Updated: API-first
        ├── task-018.md          # Updated: API-first
        ├── task-019.md          # Updated: API-first
        └── task-020.md          # Updated: API-first
```

### Phase 3: Integration with Cluster Creation

**Enhanced workflow:**
```bash
# Create clusters
./create-cluster.sh cluster01 1 3
./create-cluster.sh cluster02 2 3

# Start clusters
docker compose -f docker-compose-cluster01.yml up -d
docker compose -f docker-compose-cluster02.yml up -d

# Wait for initialization
sleep 120

# Automated Site-to-Site setup (NEW)
./automation/setup-site-to-site.sh cluster01 cluster02

# Verify
./automation/verify-s2s.sh cluster01 cluster02

# Total time: ~5 minutes (vs 30+ minutes manual)
```

## API Library Design

### Core Functions (automation/lib/nifi-api.sh)

```bash
# Authentication
nifi_get_token() {
  local url=$1
  local username=$2
  local password=$3
  curl -k -s -X POST "${url}/nifi-api/access/token" \
    -d "username=${username}&password=${password}"
}

# Component Creation
nifi_create_input_port() {
  local url=$1
  local token=$2
  local name=$3
  local comments=$4
  # ... API call
}

nifi_create_output_port() { ... }
nifi_create_processor() { ... }
nifi_create_rpg() { ... }

# Configuration
nifi_update_processor_properties() { ... }
nifi_create_connection() { ... }

# Lifecycle
nifi_start_component() { ... }
nifi_stop_component() { ... }

# Verification
nifi_get_component_status() { ... }
nifi_wait_for_running() { ... }
```

## Benefits

### Immediate Benefits
1. **Speed:** 30 seconds vs 15 minutes
2. **Repeatability:** Identical setup every time
3. **Testing:** Easy to create/destroy test environments
4. **CI/CD:** Can be integrated into pipelines
5. **Documentation:** Code is documentation

### Long-term Benefits
1. **Template Creation:** Save flows as templates via API
2. **Multi-Environment:** Deploy same flow to dev/staging/prod
3. **Disaster Recovery:** Rebuild clusters automatically
4. **Configuration Management:** Version control all configurations
5. **Monitoring Integration:** Automated health checks

## Trade-offs

### Pros of API Automation
- Fast, repeatable, version-controlled
- No human error
- Can be tested automatically
- Production-ready

### Cons of API Automation
- Requires bash/scripting knowledge
- Harder to understand for beginners
- API may change between NiFi versions
- Debugging requires understanding REST API

### Mitigation
- Keep abbreviated manual UI steps for reference
- Add verbose logging to scripts
- Version-pin NiFi API compatibility
- Provide troubleshooting guides

## Success Criteria

Tasks 017-020 are considered successfully automated when:
- ✅ Single command executes all steps
- ✅ Execution time < 60 seconds
- ✅ 100% success rate (no manual intervention)
- ✅ Automated verification confirms functionality
- ✅ Logs provide clear troubleshooting info
- ✅ Script handles common errors gracefully

## References

- **Proof of Concept:** `test-nifi-api-automation.sh`
- **Evidence Document:** `API-AUTOMATION-EVIDENCE.md`
- **NiFi REST API Docs:** https://nifi.apache.org/docs/nifi-docs/rest-api/
- **Updated Tasks:** task-017, task-018, task-019, task-020

## Related Documents

- **doc-001:** Multi-Cluster Architecture Design (network topology)
- **doc-002:** Multi-Cluster Directory Structure (file organization)

## Decision History

- **2025-11-12:** Initial investigation completed
- **2025-11-12:** API automation proven feasible
- **2025-11-12:** Decision to adopt API-first approach
- **2025-11-12:** Tasks 017-020 rewritten for automation

---

**Approved By:** AI Implementation (Claude)
**Status:** Active - Implementation in progress
