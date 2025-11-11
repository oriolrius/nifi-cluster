---
id: task-008
title: Implement volume initialization script (init-cluster-volumes.sh)
status: Done
assignee: []
created_date: '2025-11-11 14:59'
updated_date: '2025-11-11 16:11'
labels:
  - filesystem
  - initialization
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create script to initialize volume directory structure for a cluster.

Script should:
- Accept CLUSTER_NAME and NODE_COUNT parameters
- Create ZooKeeper directories: data, datalog, logs
- Create NiFi directories: content_repository, database_repository, flowfile_repository, provenance_repository, state, logs
- Set proper permissions (UID:GID 1000:1000)
- Create conf directories for each node

Reference: Analysis report section 6.2, 12.5
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All required directories created per node
- [x] #2 Permissions set to 1000:1000
- [x] #3 Script validates inputs before execution
- [x] #4 Idempotent (safe to run multiple times)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Created init-cluster-volumes.sh script (290 lines) in scripts/ directory.

Features:
- Parameterized: Accepts CLUSTER_NAME and NODE_COUNT (default: 3)
- Creates complete directory structure under clusters/<cluster-name>/

Directory Structure Created Per Node:
1. ZooKeeper directories (4 per node):
   - volumes/<node>/data
   - volumes/<node>/datalog
   - volumes/<node>/logs
   - conf/<node>/

2. NiFi directories (7 per node):
   - volumes/<node>/content_repository
   - volumes/<node>/database_repository
   - volumes/<node>/flowfile_repository
   - volumes/<node>/provenance_repository
   - volumes/<node>/state
   - volumes/<node>/logs
   - conf/<node>/

Validation & Error Handling:
- Cluster name validation (alphanumeric, dash, underscore only)
- Node count validation (1-10 nodes)
- Warning for even node counts (ZK quorum best practice)
- Confirmation prompt if cluster directory exists
- Comprehensive usage/help message

Idempotency:
- Safe to run multiple times
- Detects existing directories and skips creation
- Reports "already exists" for existing paths
- Only creates missing directories

Permissions:
- Sets UID:GID to 1000:1000 using sudo
- Handles sudo with/without password
- Graceful fallback if sudo unavailable
- Warnings if permissions cannot be set

User Experience:
- Color-coded output (✓ green, ⚠ yellow, ✗ red)
- Progress indicators for each step
- Directory tree visualization (if tree command available)
- Next steps guidance after completion
- Clear error messages

Testing Verified:
- No arguments: Shows usage and errors
- Invalid cluster name: Validates and rejects
- Valid creation: Creates all directories correctly
- Idempotency: Re-run detects existing directories
- Permissions: Attempts to set 1000:1000 ownership

Location: scripts/init-cluster-volumes.sh (executable)
<!-- SECTION:NOTES:END -->
