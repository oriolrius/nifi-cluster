# NiFi Cluster Configuration Summary

## ✅ Setup Complete

Your NiFi cluster is now running with:
- **Custom `nifi.properties` files** for each node
- **Private PKI certificates** from your own Certificate Authority
- **3-node cluster** with full connectivity

## Configuration Architecture

### Directory Structure

```
nifi-cluster/
├── conf/                       # Custom configuration (MOUNTED)
│   ├── nifi-1/                # Active config for node 1
│   │   ├── nifi.properties   # Custom properties
│   │   ├── keystore.p12      # Node certificate (from private CA)
│   │   ├── truststore.p12    # CA certificate
│   │   └── ... (other NiFi config files)
│   ├── nifi-2/
│   └── nifi-3/
├── certs/                      # Certificate SOURCE
│   ├── ca/                    # Your private CA
│   ├── nifi-1/                # Source certificates
│   ├── nifi-2/
│   └── nifi-3/
└── volumes/                    # Runtime data
```

### Key Differences from Standard Setup

| Aspect | Standard NiFi | Your Custom Setup |
|--------|---------------|-------------------|
| Configuration | Auto-generated | Custom `nifi.properties` per node |
| Certificates | Auto-generated (localhost) | Private PKI (CN=nifi-1, nifi-2, nifi-3) |
| Issuer | Self-signed | NiFi Cluster Root CA |
| Mount Strategy | Individual files | Entire `conf/` directory |
| Certificate Location | Various | Centralized in `conf/` and `certs/` |

## Access Points

- **Node 1**: https://localhost:59443/nifi
- **Node 2**: https://localhost:59444/nifi
- **Node 3**: https://localhost:59445/nifi
- **Credentials**: admin / changeme123456

## Cluster Status Verification

```bash
# Check all nodes are healthy
docker compose ps

# Verify PKI certificates
for i in 1 2 3; do
  echo "Node nifi-${i}:"
  openssl s_client -connect localhost:5944${i} -showcerts </dev/null 2>&1 | openssl x509 -noout -subject
done

# Should show:
# Node nifi-1: CN=nifi-1, OU=NiFi Nodes, O=NiFi Cluster
# Node nifi-2: CN=nifi-2, OU=NiFi Nodes, O=NiFi Cluster
# Node nifi-3: CN=nifi-3, OU=NiFi Nodes, O=NiFi Cluster

# Verify certificate trust chain
openssl s_client -connect localhost:59443 -CAfile certs/ca/ca-cert.pem </dev/null 2>&1 | grep "Verify return code"
# Should show: Verify return code: 0 (ok)
```

## Common Operations

### Modify Configuration

1. Edit configuration:
   ```bash
   vim conf/nifi-1/nifi.properties
   ```

2. Restart the node:
   ```bash
   docker compose restart nifi-1
   ```

### Regenerate Certificates

1. Generate new certificates:
   ```bash
   cd certs
   ./generate-certs.sh
   cd ..
   ```

2. Copy to active configuration:
   ```bash
   for i in 1 2 3; do
     cp certs/nifi-${i}/keystore.p12 conf/nifi-${i}/
     cp certs/nifi-${i}/truststore.p12 conf/nifi-${i}/
   done
   ```

3. Restart cluster:
   ```bash
   docker compose restart nifi-1 nifi-2 nifi-3
   ```

### Backup Configuration

```bash
# Backup everything
tar -czf nifi-cluster-backup-$(date +%Y%m%d).tar.gz \
  conf/ certs/ volumes/ docker-compose.yml .env

# Backup just configuration
tar -czf nifi-config-backup-$(date +%Y%m%d).tar.gz conf/ certs/
```

## Documentation

- **Main README**: [`README.md`](README.md) - Cluster overview and operations
- **Configuration Guide**: [`conf/README.md`](conf/README.md) - Detailed configuration management
- **PKI Guide**: [`certs/README.md`](certs/README.md) - Certificate management and troubleshooting
- **AI Instructions**: [`CLAUDE.md`](CLAUDE.md) - Complete reference for AI assistants

## Updated Files

The following files have been updated to reflect the custom configuration:

1. **README.md**
   - Added directory structure showing `conf/` and `certs/`
   - Added "Custom Configuration with Private PKI" section
   - Updated access points to HTTPS URLs

2. **certs/README.md**
   - Updated "Integration with Docker Compose" section
   - Added instructions for copying certificates to `conf/`
   - Clarified certificate source vs. active location

3. **CLAUDE.md**
   - Updated complete directory structure
   - Added "Custom Configuration & Private PKI" section
   - Updated access URLs to HTTPS with ports

4. **conf/README.md** (created earlier)
   - Complete configuration management guide
   - Task breakdown and best practices
   - Troubleshooting section

## Security Notes

⚠️ **For Production**:
1. Change default password: `changeme123456`
2. Use strong, unique passwords
3. Rotate certificates before expiration (10 years)
4. Restrict file permissions on `certs/ca/ca-key.pem`
5. Store passwords in secrets management (Vault, etc.)

## Troubleshooting

If issues occur:

1. Check logs:
   ```bash
   docker compose logs -f nifi-1
   ```

2. Verify certificate paths in properties:
   ```bash
   docker exec nifi-1 cat /opt/nifi/nifi-current/conf/nifi.properties | grep security.keystore
   ```

3. Check cluster connectivity:
   ```bash
   docker compose logs | grep "state=CONNECTED"
   ```

For detailed troubleshooting, see:
- [`conf/README.md#troubleshooting`](conf/README.md#troubleshooting)
- [`certs/README.md#troubleshooting`](certs/README.md#troubleshooting)

---

**Setup Date**: $(date)
**NiFi Version**: latest
**Cluster Size**: 3 nodes
**PKI**: Private Certificate Authority
