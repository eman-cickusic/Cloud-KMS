#!/bin/bash

# Single File Encryption Script for Google Cloud KMS Lab
# This script demonstrates encrypting a single file using Cloud KMS

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load environment variables if .env file exists
if [ -f .env ]; then
    source .env
    print_status "Loaded environment variables from .env file"
else
    print_warning "No .env file found. Make sure to run setup.sh first or set variables manually."
fi

# Check required variables
if [ -z "$PROJECT_ID" ] || [ -z "$KEYRING_NAME" ] || [ -z "$CRYPTOKEY_NAME" ] || [ -z "$BUCKET_NAME" ]; then
    print_error "Required environment variables not set. Please run setup.sh first."
    exit 1
fi

# Use DEVSHELL_PROJECT_ID if available (for Cloud Shell compatibility)
if [ -n "$DEVSHELL_PROJECT_ID" ]; then
    PROJECT_ID=$DEVSHELL_PROJECT_ID
fi

print_status "Starting single file encryption demo..."
print_status "Project ID: $PROJECT_ID"
print_status "KeyRing: $KEYRING_NAME"
print_status "CryptoKey: $CRYPTOKEY_NAME"
print_status "Bucket: $BUCKET_NAME"

# Check if sample file exists
SAMPLE_FILE="1."
if [ ! -f "$SAMPLE_FILE" ]; then
    print_status "Sample file not found. Downloading from Enron corpus..."
    if gsutil cp gs://enron_emails/allen-p/inbox/1. .; then
        print_status "Sample file downloaded successfully"
    else
        print_error "Failed to download sample file. Please check your permissions."
        exit 1
    fi
fi

# Display sample of the file content
print_status "Sample file content (first 5 lines):"
head -5 "$SAMPLE_FILE" | sed 's/^/  /'

# Base64 encode the file content
print_status "Base64 encoding the file content..."
PLAINTEXT=$(cat "$SAMPLE_FILE" | base64 -w0)
print_status "File encoded successfully (${#PLAINTEXT} characters)"

# Encrypt the data using Cloud KMS
print_status "Encrypting data using Cloud KMS..."
ENCRYPTED_FILE="${SAMPLE_FILE}.encrypted"

curl -s "https://cloudkms.googleapis.com/v1/projects/$PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
  -d "{\"plaintext\":\"$PLAINTEXT\"}" \
  -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json" \
| jq .ciphertext -r > "$ENCRYPTED_FILE"

if [ -f "$ENCRYPTED_FILE" ] && [ -s "$ENCRYPTED_FILE" ]; then
    print_status "File encrypted successfully: $ENCRYPTED_FILE"
    print_status "Encrypted file size: $(wc -c < "$ENCRYPTED_FILE") bytes"
else
    print_error "Encryption failed or produced empty file"
    exit 1
fi

# Verify decryption works
print_status "Verifying decryption..."
DECRYPTED_CONTENT=$(curl -s "https://cloudkms.googleapis.com/v1/projects/$PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:decrypt" \
  -d "{\"ciphertext\":\"$(cat $ENCRYPTED_FILE)\"}" \
  -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type:application/json" \
| jq .plaintext -r | base64 -d)

# Compare original and decrypted content
ORIGINAL_CONTENT=$(cat "$SAMPLE_FILE")
if [ "$ORIGINAL_CONTENT" = "$DECRYPTED_CONTENT" ]; then
    print_status "✓ Decryption verification successful - content matches original"
else
    print_error "✗ Decryption verification failed - content does not match"
    exit 1
fi

# Upload encrypted file to Cloud Storage
print_status "Uploading encrypted file to Cloud Storage..."
if gsutil cp "$ENCRYPTED_FILE" gs://${BUCKET_NAME}/; then
    print_status "✓ Encrypted file uploaded successfully to gs://${BUCKET_NAME}/${ENCRYPTED_FILE}"
else
    print_error "Failed to upload encrypted file to Cloud Storage"
    exit 1
fi

# Display summary
echo ""
echo "=============================="
print_status "ENCRYPTION SUMMARY"
echo "=============================="
echo "Original file: $SAMPLE_FILE ($(wc -c < "$SAMPLE_FILE") bytes)"
echo "Encrypted file: $ENCRYPTED_FILE ($(wc -c < "$ENCRYPTED_FILE") bytes)"
echo "Cloud Storage location: gs://${BUCKET_NAME}/${ENCRYPTED_FILE}"
echo "Encryption key: projects/$PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME"
echo "Status: ✓ SUCCESS"
echo "=============================="

print_status "Single file encryption completed successfully! 🎉"
print_status "Next steps:"
echo "  1. Check your Cloud Storage bucket: gsutil ls gs://${BUCKET_NAME}"
echo "  2. View the encrypted file: gsutil cat gs://${BUCKET_NAME}/${ENCRYPTED_FILE}"
echo "  3. Run bulk_encrypt.sh to encrypt multiple files"
echo "  4. Check Cloud KMS audit logs in the GCP Console"