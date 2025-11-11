# Shared Certificate Authority (CA)

This directory contains the **shared Certificate Authority** used by all NiFi clusters.

## Purpose

All clusters (cluster01, cluster02, cluster03, etc.) use the **same CA** for signing their node certificates. This approach:

- Simplifies certificate management
- Enables potential Site-to-Site communication between clusters
- Provides a single trust anchor for all clusters
- Reduces complexity in multi-cluster deployments

## Structure

```
certs/
├── ca/                     # Shared CA for all clusters
│   ├── ca-key.pem         # CA private key (CRITICAL - keep secure!)
│   ├── ca-cert.pem        # CA certificate
│   ├── truststore.jks     # Java truststore
│   └── truststore.p12     # PKCS12 truststore
└── generate-certs.sh      # Certificate generation script
```

## Usage

The `generate-certs.sh` script is called by `create-cluster.sh` and should:

1. Use the existing CA from `ca/` directory
2. Generate node-specific certificates signed by this CA
3. Place generated certificates in `clusters/<CLUSTER_NAME>/certs/`

## Important Notes

- **ONE CA for ALL clusters** - Do not create separate CAs per cluster
- The CA private key (`ca/ca-key.pem`) must be protected (chmod 600)
- All cluster node certificates are signed by this shared CA
- Each cluster stores its node certificates in its own workspace under `clusters/<CLUSTER_NAME>/certs/`

## Security

```bash
# Protect the CA private key
chmod 600 ca/ca-key.pem

# Backup the CA (CRITICAL)
tar -czf ca-backup-$(date +%Y%m%d).tar.gz ca/
```
