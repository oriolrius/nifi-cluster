# NiFi Cluster PKI Certificates

## Overview

This directory contains a complete Private Key Infrastructure (PKI) for the NiFi cluster, including:
- Root Certificate Authority (CA)
- Server certificates for all NiFi nodes
- Server certificates for all ZooKeeper nodes
- Java KeyStores (JKS) for all services

## Directory Structure

```
certs/
├── ca/                    # Root Certificate Authority
│   ├── ca-key.pem        # CA private key
│   ├── ca-cert.pem       # CA certificate
│   └── truststore.jks    # JKS truststore (contains CA cert)
├── nifi-1/               # NiFi node 1 certificates
│   ├── keystore.jks      # Server keystore
│   └── truststore.jks    # Truststore (copy of CA truststore)
├── nifi-2/               # NiFi node 2 certificates
├── nifi-3/               # NiFi node 3 certificates
├── zookeeper-1/          # ZooKeeper node 1 certificates
├── zookeeper-2/          # ZooKeeper node 2 certificates
└── zookeeper-3/          # ZooKeeper node 3 certificates
```

## Certificate Details

### Root CA
- **Subject**: `/C=US/ST=California/L=San Francisco/O=NiFi Cluster/OU=Certificate Authority/CN=NiFi Cluster Root CA`
- **Validity**: 10 years (3650 days)
- **Key Size**: 2048 bits RSA

### Server Certificates
- **NiFi Nodes**: Subject CN=nifi-{1,2,3}
- **ZooKeeper Nodes**: Subject CN=zookeeper-{1,2,3}
- **SAN (Subject Alternative Names)**:
  - DNS: node hostname
  - DNS: localhost
  - IP: 127.0.0.1
- **Validity**: 10 years
- **Key Size**: 2048 bits RSA

## Passwords

All keystores and truststores use the same password:
```
Password: changeme123456
```

**IMPORTANT**: Change these passwords for production deployments!

## Regenerating Certificates

To regenerate all certificates:

```bash
cd /home/oriol/miimetiq3/nifi-cluster/certs
./generate-certs.sh
```

This will:
1. Generate a new Root CA
2. Create server certificates for all nodes
3. Convert to JKS format
4. Set up truststores

After regenerating, restart the cluster:
```bash
cd /home/oriol/miimetiq3/nifi-cluster
docker compose restart
```

## Testing Certificate Validity

### Verify Certificate Chain
```bash
# Check NiFi node 1 certificate
openssl verify -CAfile ca/ca-cert.pem nifi-1/server-cert.pem

# Check ZooKeeper node 1 certificate
openssl verify -CAfile ca/ca-cert.pem zookeeper-1/server-cert.pem
```

### View Certificate Details
```bash
# View CA certificate
openssl x509 -in ca/ca-cert.pem -text -noout

# View server certificate
openssl x509 -in nifi-1/server-cert.pem -text -noout

# List keystore contents
keytool -list -v -keystore nifi-1/keystore.jks -storepass changeme123456
```

### Test SSL Connection
```bash
# Test NiFi node 1 HTTPS
openssl s_client -connect localhost:59443 -CAfile ca/ca-cert.pem

# Should show:
# Verify return code: 0 (ok)
```

## Security Notes

1. **Private Keys**: Keep `ca-key.pem` and `*-key.pem` files secure
2. **Production**:
   - Use strong, unique passwords
   - Store passwords securely (e.g., HashiCorp Vault)
   - Consider using hardware security modules (HSMs) for CA key
3. **Certificate Rotation**: Plan to rotate certificates before expiration
4. **Access Control**: Restrict file permissions on this directory

## File Permissions

```bash
# Current permissions
drwxr-xr-x  certs/
drwxr-xr-x  certs/ca/
-rw-r--r--  certs/ca/ca-cert.pem
-rw-------  certs/ca/ca-key.pem
-rw-r--r--  certs/nifi-*/*.jks
-rw-r--r--  certs/zookeeper-*/*.jks
```

## Integration with Docker Compose

The certificates are **copied** to each node's `conf/` directory and mounted with the full configuration:

```yaml
volumes:
  - ./conf/nifi-1:/opt/nifi/nifi-current/conf:rw
```

The `conf/nifi-X/` directory contains:
- `keystore.p12` - Node's private key and certificate (copied from `certs/nifi-X/`)
- `truststore.p12` - CA certificate for trust validation (copied from `certs/nifi-X/`)
- `nifi.properties` - Configuration file with certificate paths:
  ```properties
  nifi.security.keystore=./conf/keystore.p12
  nifi.security.keystoreType=PKCS12
  nifi.security.keystorePasswd=changeme123456
  nifi.security.truststore=./conf/truststore.p12
  nifi.security.truststoreType=PKCS12
  nifi.security.truststorePasswd=changeme123456
  ```

**Note**: Certificates in `certs/` are the **source**. When regenerating certificates or making changes, you must copy them to the `conf/` directories:
```bash
# After regenerating certificates
for i in 1 2 3; do
  cp certs/nifi-${i}/keystore.p12 conf/nifi-${i}/
  cp certs/nifi-${i}/truststore.p12 conf/nifi-${i}/
done
docker compose restart nifi-1 nifi-2 nifi-3
```

## Troubleshooting

### Certificate Not Trusted
- Ensure truststore contains the CA certificate
- Verify certificate chain: `openssl verify -CAfile ca/ca-cert.pem <cert>`

### Keystore Password Errors
- Check passwords match in docker-compose.yml
- Default password: `changeme123456`

### Hostname Verification Failures
- Ensure SAN includes the hostname being accessed
- Check certificate with: `openssl x509 -in cert.pem -text | grep -A1 "Subject Alternative"`

## References

- [NiFi Security Configuration](https://nifi.apache.org/docs/nifi-docs/html/administration-guide.html#security-configuration)
- [OpenSSL Commands](https://www.openssl.org/docs/man1.1.1/man1/)
- [Java Keytool](https://docs.oracle.com/en/java/javase/11/tools/keytool.html)
