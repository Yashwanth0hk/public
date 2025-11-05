#!/bin/bash
# =============================================
# Self-Signed CA, Gateway Certificates + PKCS12 TrustStore
# Works in Git Bash (Windows)
# =============================================

OPENSSL=openssl

# Passwords
PKCS12_PASS="changeit"
TRUSTSTORE_PASS="changeit"
TRUSTSTORE_FILE="intranet-truststore.p12"

export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

# -----------------------------
# Step 1: Create CA
# -----------------------------
echo "Creating CA..."
$OPENSSL genrsa -out intranetCA.key 4096
$OPENSSL req -x509 -new -nodes -key intranetCA.key -sha256 -days 3650 -out intranetCA.crt \
  -subj "/C=IN/ST=Karnataka/L=Bangalore/O=IntranetCA/OU=IT/CN=Intranet-CA"

# -----------------------------
# Step 2: Gateway1
# -----------------------------
echo "Creating Gateway1 certificate..."
$OPENSSL genrsa -out gateway1.key 2048
$OPENSSL req -new -key gateway1.key -out gateway1.csr \
  -subj "/C=IN/ST=Karnataka/L=Bangalore/O=Intranet/OU=IT/CN=gateway1.local"

cat > gateway1_ext.cnf <<EOL
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = gateway1.local
IP.1 = 10.252.174.88
EOL

$OPENSSL x509 -req -in gateway1.csr -CA intranetCA.crt -CAkey intranetCA.key -CAcreateserial \
  -out gateway1.crt -days 825 -sha256 -extfile gateway1_ext.cnf

$OPENSSL pkcs12 -export -in gateway1.crt -inkey gateway1.key -out gateway1.p12 \
  -name gateway1 -passout pass:$PKCS12_PASS

# -----------------------------
# Step 3: Gateway2
# -----------------------------
echo "Creating Gateway2 certificate..."
$OPENSSL genrsa -out gateway2.key 2048
$OPENSSL req -new -key gateway2.key -out gateway2.csr \
  -subj "/C=IN/ST=Karnataka/L=Bangalore/O=Intranet/OU=IT/CN=gateway2.local"

cat > gateway2_ext.cnf <<EOL
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = gateway2.local
IP.1 = 192.168.1.102
EOL

$OPENSSL x509 -req -in gateway2.csr -CA intranetCA.crt -CAkey intranetCA.key -CAcreateserial \
  -out gateway2.crt -days 825 -sha256 -extfile gateway2_ext.cnf

$OPENSSL pkcs12 -export -in gateway2.crt -inkey gateway2.key -out gateway2.p12 \
  -name gateway2 -passout pass:$PKCS12_PASS

# -----------------------------
# Step 4: PKCS12 TrustStore
# -----------------------------
echo "Creating PKCS12 TrustStore..."
keytool -importcert -noprompt -trustcacerts -alias intranetCA -file intranetCA.crt \
  -keystore $TRUSTSTORE_FILE -storetype PKCS12 -storepass $TRUSTSTORE_PASS

# -----------------------------
# Done
# -----------------------------
echo "✅ PKCS12 certificates and TrustStore generated successfully!"
echo "Gateway1 PKCS12: gateway1.p12"
echo "Gateway2 PKCS12: gateway2.p12"
echo "TrustStore PKCS12: $TRUSTSTORE_FILE (password: '$TRUSTSTORE_PASS')"
