#!/bin/bash
# Update certificate paths in nifi.properties

for i in 1 2 3; do
  sed -i 's|nifi.security.keystore=.*|nifi.security.keystore=./certs/keystore.p12|' "/home/oriol/miimetiq3/nifi-cluster/conf/nifi-${i}/nifi.properties"
  sed -i 's|nifi.security.truststore=.*|nifi.security.truststore=./certs/truststore.p12|' "/home/oriol/miimetiq3/nifi-cluster/conf/nifi-${i}/nifi.properties"
  echo "Updated nifi-${i}/nifi.properties"
done
