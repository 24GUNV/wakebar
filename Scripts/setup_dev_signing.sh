#!/usr/bin/env bash
#
# Creates a stable self-signed code-signing identity for local development.
#
# Why: keychain "Always Allow" grants are tied to the app's code-signing
# identity. Ad-hoc signatures change on every rebuild, so macOS treats each
# build as a new app and re-prompts for the Claude Code credential. Signing
# every debug build with this one certificate keeps the grant across rebuilds.
#
# Run once, interactively (it asks for your login keychain password so
# codesign can use the imported key without prompting on every build):
#   Scripts/setup_dev_signing.sh
set -euo pipefail

identity_name="Wakebar Dev Signing"
login_keychain="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "$identity_name"; then
  echo "Identity \"$identity_name\" already exists. Nothing to do."
  exit 0
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cat > "$workdir/openssl.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = codesign_ext
prompt = no

[dn]
CN = Wakebar Dev Signing

[codesign_ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
EOF

echo "Generating self-signed certificate (valid ~10 years)..."
openssl req -x509 -newkey rsa:2048 -sha256 -nodes \
  -keyout "$workdir/key.pem" -out "$workdir/cert.pem" \
  -days 3650 -config "$workdir/openssl.cnf" 2>/dev/null

# A throwaway password only for the transient PKCS#12 container.
p12_password="$(openssl rand -hex 16)"
openssl pkcs12 -export \
  -inkey "$workdir/key.pem" -in "$workdir/cert.pem" \
  -out "$workdir/identity.p12" -passout "pass:$p12_password" \
  -name "$identity_name"

echo "Importing into the login keychain..."
security import "$workdir/identity.p12" \
  -k "$login_keychain" \
  -P "$p12_password" \
  -T /usr/bin/codesign

echo "Trusting the certificate for code signing (macOS may ask for your password)..."
security add-trusted-cert -p codeSign -k "$login_keychain" "$workdir/cert.pem"

echo "Allowing codesign to use the key without a per-build prompt."
echo "Enter your login keychain (login account) password:"
read -r -s keychain_password
security set-key-partition-list \
  -S "apple-tool:,apple:,codesign:" \
  -s -l "$identity_name" -t private -k "$keychain_password" \
  "$login_keychain" > /dev/null
unset keychain_password

echo
echo "Done. Verify with: security find-identity -v -p codesigning"
echo "Debug builds now sign as \"$identity_name\" (see Configurations/Debug.xcconfig)."
echo "Expect ONE final keychain prompt from the newly signed build; click Always Allow"
echo "and it will stick across rebuilds."
