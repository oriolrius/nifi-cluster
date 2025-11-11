# Custom NiFi Properties Configuration

## Overview

Your NiFi cluster is now configured to use:
- **Custom `nifi.properties` files** for each node (node-specific configurations)
- **Your existing SSL certificates** from the `certs/` directory

## Configuration Structure

```
conf/
├── nifi-1/
│   └── nifi.properties    # Node 1 custom properties
├── nifi-2/
│   └── nifi.properties    # Node 2 custom properties
├── nifi-3/
│   └── nifi.properties    # Node 3 custom properties
└── README.md              # This file
```

## How It Works

### 1. Custom Properties File
Each NiFi node uses its own `nifi.properties` file mounted from the host:

```yaml
volumes:
  - ./conf/nifi-1/nifi.properties:/opt/nifi/nifi-current/conf/nifi.properties:ro
```

This gives you full control over NiFi configuration without building a custom Docker image.

### 2. SSL Certificates
Your certificates from `certs/nifi-{1,2,3}/` are mounted and configured via environment variables:

```yaml
environment:
  NIFI_SECURITY_KEYSTORE: ./certs/keystore.p12
  NIFI_SECURITY_TRUSTSTORE: ./certs/truststore.p12
```

**Important**: Environment variables override `nifi.properties` for SSL paths. This is intentional to ensure your custom certificates are used.

## Modifying Configuration

### Editing Properties Files

To change NiFi settings:

1. Edit the properties file for the node(s):
   ```bash
   vim conf/nifi-1/nifi.properties
   ```

2. Restart the affected node(s):
   ```bash
   docker compose restart nifi-1
   ```

### Common Settings to Modify

| Setting | Location | Purpose |
|---------|----------|---------|
| JVM Heap | `docker-compose.yml` `NIFI_JVM_HEAP_*` | Memory allocation |
| SSL Certificates | `docker-compose.yml` `NIFI_SECURITY_*` | Certificate paths |
| Web UI Port | `nifi.properties` `nifi.web.https.port` | HTTPS port |
| Cluster Settings | `nifi.properties` `nifi.cluster.*` | Cluster behavior |
| ZooKeeper | `nifi.properties` `nifi.zookeeper.connect.string` | ZK connection |

### Settings That Require Environment Variables

Due to NiFi's startup script behavior, these settings **must** be in `docker-compose.yml`:

- `SINGLE_USER_CREDENTIALS_USERNAME`
- `SINGLE_USER_CREDENTIALS_PASSWORD`
- `NIFI_SECURITY_KEYSTORE` (if using custom path)
- `NIFI_SECURITY_TRUSTSTORE` (if using custom path)
- `NIFI_CLUSTER_NODE_ADDRESS` (node-specific)
- `NIFI_WEB_PROXY_HOST`

## Current Configuration Summary

### Node-Specific Settings

Each node has these unique values in its properties file:

| Property | Node 1 | Node 2 | Node 3 |
|----------|--------|--------|--------|
| `nifi.cluster.node.address` | nifi-1 | nifi-2 | nifi-3 |
| `nifi.remote.input.host` | nifi-1 | nifi-2 | nifi-3 |

### SSL/TLS Configuration

- **Keystore**: `./certs/keystore.p12` (PKCS12 format)
- **Truststore**: `./certs/truststore.p12` (PKCS12 format)
- **Password**: `changeme123456` (defined in `docker-compose.yml`)

**Security Note**: Change the password in production by updating the environment variables in `docker-compose.yml`.

### Access Points

- **Node 1 UI**: https://localhost:59443/nifi
- **Node 2 UI**: https://localhost:59444/nifi
- **Node 3 UI**: https://localhost:59445/nifi

## Regenerating Properties Files

To regenerate all node properties from scratch:

```bash
cd /home/oriol/miimetiq3/nifi-cluster/conf
./create-node-properties.sh
```

This will recreate `nifi-{1,2,3}/nifi.properties` with default cluster settings.

## Troubleshooting

### Properties Not Applied

**Problem**: Changes to `nifi.properties` don't take effect

**Solution**:
1. Check if an environment variable is overriding the property
2. Restart the node: `docker compose restart nifi-1`
3. Check logs: `docker logs nifi-1 | grep -i error`

### Certificate Errors

**Problem**: SSL handshake failures or certificate errors

**Solution**:
1. Verify certificates exist:
   ```bash
   docker exec nifi-1 ls -la /opt/nifi/nifi-current/certs/
   ```
2. Check passwords match in `docker-compose.yml`
3. Regenerate certificates: `cd certs && ./generate-certs.sh`

### Node Won't Join Cluster

**Problem**: Node starts but doesn't join the cluster

**Solution**:
1. Check ZooKeeper connectivity:
   ```bash
   docker compose logs zookeeper-1
   ```
2. Verify `nifi.cluster.node.address` matches the container hostname
3. Ensure all nodes use the same `nifi.sensitive.props.key`

## Best Practices

1. **Version Control**: Keep your `conf/` directory in git to track configuration changes
2. **Backups**: Backup `conf/` and `certs/` before making changes
3. **Testing**: Test configuration changes on one node before applying to all
4. **Documentation**: Comment custom settings in `nifi.properties` for future reference
5. **Security**: Never commit sensitive passwords or keys to version control

## Advanced: Building Without Environment Variables

If you want to manage everything via `nifi.properties` (no environment variables), you'll need a custom Docker image with a modified entrypoint script that doesn't override the properties file. This is complex and not recommended unless absolutely necessary.

