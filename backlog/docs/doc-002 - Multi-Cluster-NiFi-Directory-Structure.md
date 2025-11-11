---
id: doc-002
title: Multi-Cluster NiFi Directory Structure
type: other
created_date: '2025-11-11 15:22'
---
# Multi-Cluster NiFi Directory Structure

This document explains the directory structure designed to support multiple independent NiFi clusters with a shared Certificate Authority (CA).

## Directory Structure Overview

```
nifi-cluster/
├── shared/                     # Shared resources across all clusters
│   └── certs/                  # Certificate management
│       └── ca/                 # Shared Certificate Authority
│           ├── ca-key.pem      # CA private key (generated)
│           ├── ca-cert.pem     # CA certificate (generated)
│           └── truststore.p12  # CA truststore (generated)
│
├── clusters/                   # Individual cluster instances
│   ├── cluster01/              # First cluster (example)
│   │   ├── certs/              # Cluster-specific certificates
│   │   │   ├── nifi-1/         # Node 1 certificates
│   │   │   ├── nifi-2/         # Node 2 certificates
│   │   │   └── nifi-3/         # Node 3 certificates
│   │   ├── conf/               # Cluster-specific configuration
│   │   │   ├── nifi-1/         # Node 1 config
│   │   │   ├── nifi-2/         # Node 2 config
│   │   │   └── nifi-3/         # Node 3 config
│   │   ├── volumes/            # Cluster-specific volumes
│   │   │   ├── zookeeper-1/
│   │   │   ├── zookeeper-2/
│   │   │   ├── zookeeper-3/
│   │   │   ├── nifi-1/
│   │   │   ├── nifi-2/
│   │   │   └── nifi-3/
│   │   ├── docker-compose.yml  # Cluster-specific compose file
│   │   └── .env                # Cluster-specific environment variables
│   │
│   └── cluster02/              # Second cluster (example)
│       └── ... (same structure)
│
├── templates/                  # Configuration templates
│   ├── nifi.properties.template
│   ├── state-management.xml.template
│   ├── docker-compose.yml.template
│   └── .env.template
│
├── scripts/                    # Automation scripts
│   ├── generate-ca.sh          # Generate shared CA
│   ├── generate-cluster-certs.sh  # Generate cluster certificates
│   ├── generate-cluster-configs.sh # Generate cluster configs
│   ├── init-cluster-volumes.sh    # Initialize cluster volumes
│   ├── generate-docker-compose.sh # Generate docker-compose file
│   ├── create-cluster.sh          # Master cluster creation script
│   └── validate-cluster.sh        # Validate cluster setup
│
└── backlog/                    # Project task management
    └── tasks/
```

## Key Design Principles

### 1. Shared Certificate Authority

All clusters share a single Certificate Authority located in `shared/certs/ca/`. This allows:
- **Consistent trust relationships** across all clusters
- **Simplified certificate management** with one CA to maintain
- **Inter-cluster communication** if needed in the future

### 2. Cluster Isolation

Each cluster in `clusters/clusterXX/` is completely independent:
- **Separate certificates** signed by the shared CA
- **Isolated configurations** with unique settings
- **Independent volumes** with no data sharing
- **Dedicated ports** to avoid conflicts
- **Own docker-compose.yml** for independent lifecycle management

### 3. Template-Based Generation

All configuration files are generated from templates in `templates/`:
- **Consistency** across clusters with standardized configurations
- **Customization** through environment variables
- **Version control** for templates, not generated files
- **Easy updates** by regenerating from updated templates

### 4. Automation Scripts

The `scripts/` directory contains all automation tools:
- **One-command cluster creation** with `create-cluster.sh`
- **Modular scripts** for individual tasks
- **Validation and verification** tools
- **Reusable** across multiple cluster deployments

## Cluster Naming Convention

Clusters follow the naming pattern: `cluster01`, `cluster02`, `cluster03`, etc.

- **Fixed format**: `clusterNN` where NN is zero-padded (01, 02, ..., 99)
- **Port allocation**: Each cluster gets a unique port range
  - cluster01: 8081-8089, 9443-9445, etc.
  - cluster02: 8091-8099, 9446-9448, etc.
- **Network naming**: Each cluster has isolated Docker networks
  - cluster01: `cluster01-nifi-net`, `cluster01-zk-net`
  - cluster02: `cluster02-nifi-net`, `cluster02-zk-net`

## Workflow: Creating a New Cluster

### Quick Start

```bash
# Create a new cluster (automated)
./scripts/create-cluster.sh cluster01

# Start the cluster
cd clusters/cluster01
docker-compose up -d
```

### Manual Steps (for understanding)

```bash
# 1. Generate shared CA (once, if not exists)
./scripts/generate-ca.sh

# 2. Create cluster directory structure
mkdir -p clusters/cluster01/{certs,conf,volumes}

# 3. Generate cluster certificates
./scripts/generate-cluster-certs.sh cluster01

# 4. Generate cluster configurations
./scripts/generate-cluster-configs.sh cluster01

# 5. Initialize cluster volumes
./scripts/init-cluster-volumes.sh cluster01

# 6. Generate docker-compose.yml
./scripts/generate-docker-compose.sh cluster01

# 7. Start the cluster
cd clusters/cluster01
docker-compose up -d
```

## Port Allocation

Each cluster requires a range of ports. The standard allocation is:

| Service | cluster01 | cluster02 | cluster03 |
|---------|-----------|-----------|-----------|
| NiFi Node 1 | 8081 | 8091 | 8101 |
| NiFi Node 2 | 8082 | 8092 | 8102 |
| NiFi Node 3 | 8083 | 8093 | 8103 |
| NiFi HTTPS 1 | 9443 | 9446 | 9449 |
| NiFi HTTPS 2 | 9444 | 9447 | 9450 |
| NiFi HTTPS 3 | 9445 | 9448 | 9451 |
| ZooKeeper 1 | 2181 | 2191 | 2201 |
| ZooKeeper 2 | 2182 | 2192 | 2202 |
| ZooKeeper 3 | 2183 | 2193 | 2203 |

See `docs/PORT-ALLOCATION.md` for complete port mapping.

## Certificate Management

### Shared CA Structure

```
shared/certs/ca/
├── ca-key.pem          # CA private key (keep secure!)
├── ca-cert.pem         # CA public certificate
└── truststore.p12      # Truststore for all nodes
```

### Cluster Certificate Structure

```
clusters/cluster01/certs/
├── nifi-1/
│   ├── keystore.p12        # Node private key + cert
│   ├── truststore.p12      # Copy of shared CA truststore
│   └── server-cert.pem     # Node certificate
├── nifi-2/
│   └── ... (same structure)
└── nifi-3/
    └── ... (same structure)
```

### Certificate Properties

- **CA Certificate**: Common Name = `NiFi Cluster CA`
- **Node Certificates**:
  - Common Name = `nifi-1.cluster01`, `nifi-2.cluster01`, etc.
  - SAN (Subject Alternative Names):
    - DNS: `nifi-1`, `nifi-1.cluster01-nifi-net`, `localhost`
    - IP: `127.0.0.1`

## Configuration Files

### Environment Variables (.env)

Each cluster has its own `.env` file with:
- Cluster identifier
- Port assignments
- Admin credentials
- JVM settings
- Custom properties

### NiFi Properties

Each node has a custom `nifi.properties` file with:
- Cluster-specific hostnames
- Node-specific ports
- Certificate paths
- ZooKeeper connection strings
- State management configuration

### Docker Compose

Each cluster has its own `docker-compose.yml` with:
- Cluster-specific service names
- Port mappings
- Volume mounts
- Network definitions
- Environment variable references

## Security Considerations

### What's in Git

- Templates (safe to commit)
- Scripts (safe to commit)
- Documentation (safe to commit)
- `.env.example` files (safe to commit)

### What's NOT in Git (see .gitignore)

- `shared/certs/ca/` - CA private keys
- `clusters/*/certs/` - Cluster certificates
- `clusters/*/conf/` - Generated configurations with secrets
- `clusters/*/volumes/` - Runtime data
- `clusters/*/.env` - Environment variables with passwords
- `clusters/*/docker-compose.yml` - Generated compose files

### Security Best Practices

1. **Protect the CA private key** in `shared/certs/ca/ca-key.pem`
2. **Use strong passwords** in `.env` files
3. **Never commit certificates** or configuration with secrets
4. **Backup CA keys** securely offline
5. **Rotate certificates** periodically
6. **Use unique passwords** for each cluster

## Backup Strategy

### Critical Files to Backup

```bash
# Backup shared CA (CRITICAL)
tar -czf ca-backup-$(date +%Y%m%d).tar.gz shared/certs/ca/

# Backup specific cluster
tar -czf cluster01-backup-$(date +%Y%m%d).tar.gz clusters/cluster01/

# Backup all clusters
tar -czf all-clusters-backup-$(date +%Y%m%d).tar.gz clusters/
```

### Restore Procedure

```bash
# Restore CA
tar -xzf ca-backup-YYYYMMDD.tar.gz

# Restore cluster
tar -xzf cluster01-backup-YYYYMMDD.tar.gz

# Restart cluster
cd clusters/cluster01
docker-compose down && docker-compose up -d
```

## Maintenance

### Adding a New Cluster

```bash
# Use the master creation script
./scripts/create-cluster.sh cluster03
```

### Removing a Cluster

```bash
# Stop and remove cluster
cd clusters/cluster02
docker-compose down -v

# Remove cluster directory
cd ../..
rm -rf clusters/cluster02
```

### Updating Cluster Configuration

```bash
# Update templates
vim templates/nifi.properties.template

# Regenerate cluster configs
./scripts/generate-cluster-configs.sh cluster01

# Restart cluster
cd clusters/cluster01
docker-compose restart
```

## Troubleshooting

### Cluster Won't Start

1. Check port conflicts: `netstat -tulpn | grep <port>`
2. Verify certificates: `openssl x509 -in <cert> -text -noout`
3. Check logs: `docker-compose logs -f`
4. Validate configuration: `./scripts/validate-cluster.sh cluster01`

### Certificate Issues

```bash
# Verify CA certificate
openssl x509 -in shared/certs/ca/ca-cert.pem -text -noout

# Verify node certificate
openssl x509 -in clusters/cluster01/certs/nifi-1/server-cert.pem -text -noout

# Test certificate chain
openssl verify -CAfile shared/certs/ca/ca-cert.pem \
  clusters/cluster01/certs/nifi-1/server-cert.pem
```

### Network Issues

```bash
# Check Docker networks
docker network ls | grep cluster01

# Inspect network
docker network inspect cluster01-nifi-net

# Test connectivity
docker exec cluster01-nifi-1 ping nifi-2
```

## Migration from Single Cluster

If you have an existing single-cluster setup, see `docs/MIGRATION.md` for step-by-step migration instructions.

## Next Steps

1. Generate shared CA: `./scripts/generate-ca.sh`
2. Create first cluster: `./scripts/create-cluster.sh cluster01`
3. Review cluster configuration: `clusters/cluster01/.env`
4. Start cluster: `cd clusters/cluster01 && docker-compose up -d`
5. Access NiFi: `https://localhost:9443/nifi`

## References

- [NiFi Clustering Documentation](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#clustering)
- [NiFi Security Guide](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#security-configuration)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [OpenSSL Certificate Management](https://www.openssl.org/docs/man1.1.1/man1/openssl-x509.html)
