#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Oracle.app"
CERT_NAME="Oracle Local Dev"

# Find the built app
APP_PATH=""
if [ -d "$SCRIPT_DIR/build/Release/$APP_NAME" ]; then
    APP_PATH="$SCRIPT_DIR/build/Release/$APP_NAME"
elif [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
    APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "$APP_NAME" -path "*/Build/Products/Release/*" 2>/dev/null | head -n 1)
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: Could not find built $APP_NAME."
    echo "Please build the project first (Cmd+B or Cmd+R in Xcode)."
    exit 1
fi

echo "Found app at: $APP_PATH"

# Check if the self-signed cert exists
cert_exists() {
    security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"
}

if ! cert_exists; then
    echo ""
    echo "Creating self-signed code signing certificate: '$CERT_NAME'"
    echo "You may be prompted for your macOS password."
    echo ""

    # Create a temporary config for openssl
    TMPDIR="$(mktemp -d)"
    cat > "$TMPDIR/cert.config" <<EOF
[req]
distinguished_name = req_distinguished_name
prompt = no

[req_distinguished_name]
CN = $CERT_NAME

[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

    openssl req -x509 -newkey rsa:2048 \
        -keyout "$TMPDIR/private.key" \
        -out "$TMPDIR/certificate.cer" \
        -days 3650 \
        -nodes \
        -config "$TMPDIR/cert.config" \
        -extensions ext 2>/dev/null

    # Import into login keychain
    security import "$TMPDIR/private.key" -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign 2>/dev/null || true
    security import "$TMPDIR/certificate.cer" -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign 2>/dev/null || true

    # Mark as always trusted for code signing
    CERT_HASH=$(openssl x509 -in "$TMPDIR/certificate.cer" -noout -sha1 -fingerprint | cut -d= -f2 | tr -d ':')
    security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db "$TMPDIR/certificate.cer" 2>/dev/null || true

    rm -rf "$TMPDIR"

    if ! cert_exists; then
        echo "Error: Failed to create code signing certificate."
        echo "Please create one manually in Keychain Access:"
        echo "  Keychain Access > Certificate Assistant > Create a Certificate..."
        echo "  Name: $CERT_NAME"
        echo "  Identity Type: Self Signed Root"
        echo "  Certificate Type: Code Signing"
        exit 1
    fi

    echo "Certificate created successfully."
fi

echo ""
echo "Signing $APP_NAME with '$CERT_NAME'..."
codesign --force --deep --sign "$CERT_NAME" "$APP_PATH"

echo ""
echo "Verifying signature..."
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -E "Signature|Authority|TeamIdentifier" || true

echo ""
echo "=================================="
echo "  Code Signing Complete!"
echo "=================================="
echo ""
echo "You must now run the signed app from Finder (NOT from Xcode):"
echo "  $APP_PATH"
echo ""
echo "After granting permissions once, they will persist for this signed build."
echo "If you rebuild from Xcode, run this script again to re-sign."
echo ""
