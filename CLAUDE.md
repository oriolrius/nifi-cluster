# Apache NiFi + PLC4X Industrial Data Platform - AI Assistant Instructions

## Project Overview

This project provides a complete industrial data integration platform using:
- **Apache NiFi**: Data flow orchestration and processing
- **Apache PLC4X**: Industrial protocol connectivity (Siemens S7, Modbus, OPC-UA, etc.)
- **Apache NiFi Registry**: Version control for NiFi flows
- **Gitea**: Git repository hosting for flow storage

## Architecture

```
Industrial Equipment (PLCs) ↔ PLC4X ↔ Apache NiFi ↔ NiFi Registry ↔ Gitea
```

## Stack

### Core Services
- **Apache NiFi**: Latest version (data flow engine)
- **Apache NiFi Registry**: Latest version (flow version control)
- **Gitea**: Latest version (Git hosting with SQLite database)

### Deployment
- **Docker Compose**: Multi-container orchestration
- **Host Bind Mounts**: Direct access to data on host filesystem (no Docker volumes)
- **Network Isolation**: Separate networks for security

## Directory Structure

```
nifi-cluster/
├── docker-compose.yml          # Main orchestration file
├── .env                        # Environment variables
├── .mcp.json                   # MCP server configuration
├── conf/                       # Custom NiFi configuration (mounted into containers)
│   ├── nifi-1/                # Node 1 configuration
│   │   ├── nifi.properties    # Custom properties
│   │   ├── keystore.p12       # Private PKI keystore
│   │   ├── truststore.p12     # CA truststore
│   │   ├── bootstrap.conf
│   │   ├── authorizers.xml
│   │   └── ... (other config files)
│   ├── nifi-2/                # Node 2 configuration
│   ├── nifi-3/                # Node 3 configuration
│   ├── create-node-properties.sh  # Script to generate nifi.properties
│   └── README.md              # Configuration management guide
├── certs/                      # Private PKI certificates (source)
│   ├── ca/                    # Root Certificate Authority
│   │   ├── ca-key.pem
│   │   ├── ca-cert.pem
│   │   └── truststore.jks
│   ├── nifi-1/                # Node 1 source certificates
│   │   ├── keystore.p12
│   │   ├── truststore.p12
│   │   └── server-cert.pem
│   ├── nifi-2/                # Node 2 source certificates
│   ├── nifi-3/                # Node 3 source certificates
│   ├── generate-certs.sh      # PKI generation script
│   └── README.md              # PKI documentation
├── volumes/                    # Persistent runtime data
│   ├── zookeeper-1/
│   ├── zookeeper-2/
│   ├── zookeeper-3/
│   ├── nifi-1/
│   │   ├── content_repository/
│   │   ├── database_repository/
│   │   ├── flowfile_repository/
│   │   ├── provenance_repository/
│   │   ├── state/
│   │   └── logs/
│   ├── nifi-2/
│   └── nifi-3/
├── backlog/
│   └── tasks/                  # Project tasks
├── plc4x/                      # PLC4X build tools
│   ├── README.md               # PLC4X documentation
│   ├── build-plc4x-nar.sh      # NAR build automation script
│   └── build/                  # Build artifacts (gitignored)
├── mcp-servers/
│   └── nifi/                   # NiFi MCP server for programmatic API access
│       ├── src/                # TypeScript source code
│       ├── dist/               # Compiled JavaScript
│       ├── README.md           # MCP server documentation
│       └── SETUP.md            # Quick setup guide
└── .claude/
    ├── skills/                 # AI assistant skills
    └── agents/                 # AI assistant agents
```

## Common Tasks

### Initialize Volumes (First Time Only)
```bash
./init-volumes.sh
```
Creates the directory structure for host bind mounts and sets proper permissions.

### Start the Platform
```bash
docker compose up -d
```

### Access Services
```bash
# NiFi Cluster Web UI (HTTPS with Private PKI)
https://localhost:59443/nifi        # Node 1 - Default credentials: admin/changeme123456
https://localhost:59444/nifi        # Node 2
https://localhost:59445/nifi        # Node 3

# NiFi Registry
http://localhost:18080

# Gitea
http://localhost:3000               # First-time setup on initial access
```

### Custom Configuration & Private PKI

**Configuration Management**:
- Each NiFi node has its own configuration directory: `conf/nifi-{1,2,3}/`
- Contains custom `nifi.properties`, keystores, and all NiFi config files
- To modify: Edit files in `conf/nifi-X/` and restart the node
- See [`conf/README.md`](conf/README.md) for detailed instructions

**Private PKI Certificates**:
- Cluster uses a private Certificate Authority (CA)
- Each node has unique certificate: CN=nifi-1, CN=nifi-2, CN=nifi-3
- Certificates located in `certs/` (source) and `conf/` (active)
- To regenerate: Run `certs/generate-certs.sh` and copy to `conf/`
- See [`certs/README.md`](certs/README.md) for PKI management

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f nifi
docker-compose logs -f nifi-registry
docker-compose logs -f gitea
```

### Stop Platform
```bash
docker-compose down              # Stop and remove containers
docker-compose down -v           # Also remove volumes (CAUTION: deletes data)
```

### Build PLC4X NiFi Processors
```bash
cd plc4x
./build-plc4x-nar.sh            # Build latest version
./build-plc4x-nar.sh v0.13.1    # Build specific version
cd ..
docker compose restart nifi      # Restart NiFi to load new processors
```

For detailed PLC4X documentation, see `plc4x/README.md`.

### NiFi MCP Server (Programmatic API Access)

The project includes an MCP (Model Context Protocol) server that enables AI assistants to interact with NiFi programmatically through the REST API.

**Setup:**
```bash
cd mcp-servers/nifi
npm install                     # Install dependencies (first time only)
npm run build                   # Build TypeScript (first time only)
```

**Configuration:**

The MCP server is configured in `.mcp.json` at the project root. Update credentials:

```json
{
  "mcpServers": {
    "nifi": {
      "command": "node",
      "args": ["./mcp-servers/nifi/dist/index.js"],
      "env": {
        "NIFI_URL": "http://localhost:8080",
        "NIFI_USERNAME": "admin",
        "NIFI_PASSWORD": "your-actual-password"
      }
    }
  }
}
```

**Usage:**

Once configured, you can ask your AI assistant to:
- List processors and flows
- Create and configure processors
- Start/stop processors
- Create connections between components
- Monitor system health and bulletins
- Search for components

For detailed MCP server documentation, see `mcp-servers/nifi/README.md` and `mcp-servers/nifi/SETUP.md`.

## NiFi Flow Development

### Version Control Workflow

1. **Connect NiFi to Registry**
   - In NiFi UI: Controller Settings → Registry Clients
   - Add new client pointing to `http://nifi-registry:18080`

2. **Create Flow**
   - Build your data flow in a Process Group
   - Right-click Process Group → Version → Start version control
   - Select Registry, Bucket, Flow name
   - Commit with meaningful message

3. **Update Flow**
   - Make changes to your flow
   - Right-click Process Group → Version → Commit local changes
   - Add commit message describing changes

4. **View in Gitea**
   - Flows are automatically pushed to Gitea
   - Access at `http://localhost:3000` → nifi-flows repository

### PLC4X Integration

**Supported Protocols:**
- Siemens S7 (S7-300, S7-400, S7-1200, S7-1500)
- Modbus TCP/RTU
- OPC-UA
- EtherNet/IP (Allen-Bradley)
- Beckhoff ADS

**Example Connection Strings:**
```
s7://192.168.1.100?rack=0&slot=1
modbus-tcp://192.168.1.200:502
opcua:tcp://192.168.1.50:4840
```

**Example Field Addresses:**
```
DB1.DBD0:REAL          # Siemens: Real number at DB1, offset 0
holding-register:0     # Modbus: Holding register 0
ns=2;s=Temperature     # OPC-UA: Temperature tag
```

### Common NiFi Processors

**Data Ingestion:**
- `GetFile`, `ListenHTTP`, `ConsumeKafka`
- `GetPLC4X` (read from PLCs)

**Transformation:**
- `UpdateAttribute`, `JoltTransformJSON`, `ExecuteScript`

**Routing:**
- `RouteOnAttribute`, `RouteOnContent`

**Data Egress:**
- `PutFile`, `InvokeHTTP`, `PublishKafka`
- `PutPLC4X` (write to PLCs)

## Configuration

### Environment Variables

Create `.env` file:
```bash
# NiFi
NIFI_WEB_HTTP_PORT=8080
NIFI_SINGLE_USER_USERNAME=admin
NIFI_SINGLE_USER_PASSWORD=your-secure-password

# NiFi Registry
NIFI_REGISTRY_WEB_HTTP_PORT=18080

# Gitea
GITEA_HTTP_PORT=3000
GITEA_SSH_PORT=2222

# Note: Gitea uses SQLite (no additional database configuration needed)
```

### Security Best Practices

1. **Change default passwords** in `.env` file
2. **Use strong passwords** for all services
3. **Enable HTTPS** with reverse proxy (Nginx/Traefik) for production
4. **Restrict network access** using Docker networks
5. **Regular backups** of volumes directory
6. **Update regularly** to latest stable versions

## Backup & Recovery

### Backup All Data
```bash
# Stop services
docker compose down

# Backup volumes and configuration
tar -czf backup-$(date +%Y%m%d).tar.gz docker-compose.yml .env volumes/

# Restart services
docker compose up -d
```

### Backup Individual Services
```bash
# NiFi only
tar -czf nifi-backup-$(date +%Y%m%d).tar.gz volumes/nifi/

# Gitea only
tar -czf gitea-backup-$(date +%Y%m%d).tar.gz volumes/gitea/

# NiFi Registry only
tar -czf registry-backup-$(date +%Y%m%d).tar.gz volumes/nifi-registry/
```

### Restore from Backup
```bash
# Stop services
docker compose down

# Restore volumes
tar -xzf backup-YYYYMMDD.tar.gz

# Restart services
docker compose up -d
```

### Gitea-specific Backup
```bash
# Create backup
docker-compose exec gitea /bin/sh -c \
  "gitea dump -c /data/gitea/conf/app.ini -f /data/gitea-backup.zip"

# Copy backup
docker cp gitea:/data/gitea-backup.zip ./backups/
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Port already in use | Change port in `.env` or stop conflicting service |
| Cannot access NiFi UI | Check logs: `docker-compose logs nifi` |
| PLC connection timeout | Verify PLC IP, port, and network connectivity |
| Flow not saving to Gitea | Check NiFi Registry logs, Git configuration |
| Gitea 502 error | Check Gitea logs, verify volumes are mounted |

### Health Checks
```bash
# Check all services are running
docker-compose ps

# Check service health
docker-compose exec nifi curl -f http://localhost:8080/nifi
docker-compose exec nifi-registry curl -f http://localhost:18080
docker-compose exec gitea curl -f http://localhost:3000

# Network connectivity
docker-compose exec nifi ping nifi-registry
docker-compose exec nifi-registry ping gitea
```

### Debug Mode
```bash
# Enable verbose logging
docker-compose logs -f --tail=100

# Inspect specific container
docker-compose exec nifi bash
docker-compose exec gitea sh
```

## Best Practices

### NiFi Flow Design
1. **Use Process Groups** to organize related processors
2. **Label everything** for clarity
3. **Handle errors** - always configure failure relationships
4. **Use variables** for environment-specific values
5. **Version control regularly** with meaningful commit messages
6. **Monitor backpressure** on connections

### Performance Optimization
1. **Tune concurrent tasks** per processor based on load
2. **Configure backpressure thresholds** appropriately
3. **Use batching** for high-volume flows
4. **Monitor resource usage** (CPU, memory, disk)
5. **Clean up old provenance data** periodically

### Security
1. **Minimize privileged mode** usage in containers
2. **Use secrets management** for credentials
3. **Enable authentication** on all services
4. **Regular security updates** for all images
5. **Network segmentation** between services

## Backlog.md CLI - Task Management

### Golden Rule

**NEVER edit task files directly. Always use `backlog` CLI commands.**

### Core Commands

```bash
# View/Search (use --plain for AI-readable output)
backlog task <id> --plain              # View task details
backlog task list --plain              # List all tasks
backlog search "keyword" --plain       # Search tasks

# Task Lifecycle
backlog task create "Title" -d "Description" --ac "Criterion"
backlog task edit <id> -s "In Progress" -a @myself  # Start work
backlog task edit <id> --plan $'1. Step\n2. Step'   # Add plan
backlog task edit <id> --check-ac 1                 # Mark AC complete
backlog task edit <id> --notes "Done X, Y, Z"       # Add notes
backlog task edit <id> -s Done                      # Mark complete

# Multi-line input requires ANSI-C quoting: $'line1\nline2'
```

### Quick Reference

| Action | Command |
|--------|---------|
| Add AC | `--ac "Criterion"` (multiple flags allowed) |
| Check AC | `--check-ac <index>` (multiple flags allowed) |
| Edit title | `-t "New Title"` |
| Change status | `-s "Status"` |
| Assign | `-a @user` |
| Add labels | `-l label1,label2` |

## Resources

### Documentation
- [Apache NiFi Docs](https://nifi.apache.org/docs.html)
- [Apache NiFi Registry](https://nifi.apache.org/registry.html)
- [Apache PLC4X](https://plc4x.apache.org/users/index.html)
- [Gitea Documentation](https://docs.gitea.io/)
- [Docker Compose Docs](https://docs.docker.com/compose/)

### Skills Available
Use the `Skill` tool to invoke these specialized skills:
- `apache-nifi` - NiFi flow design, processors, configuration
- `apache-nifi-registry` - Flow version control and management
- `plc4x` - Industrial protocol connectivity
- `docker-compose` - Container orchestration
- `gitea` - Git repository hosting
- `linux-bash` - Shell commands and scripting
- `git` - Version control operations
- `backlog-md` - Task management

## File References

When referencing code or configuration files, use markdown links:
- `[docker-compose.yml](docker-compose.yml)`
- `[nifi.properties:42](volumes/nifi/conf/nifi.properties#L42)`
