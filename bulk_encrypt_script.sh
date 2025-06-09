#!/bin/bash

# Bulk File Encryption Script for Google Cloud KMS Lab
# This script encrypts all files in the allen-p directory using Cloud KMS

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

print_progress() {
    echo -e "${BLUE}[PROGRESS]${NC} $1"
}

# Load environment variables if .env file exists
if [ -f .env ]; then
    source .env
    print_status "Loaded environment variables from .env file"
else
    print_warning "No .env file found. Make sure to run setup.sh first."
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

print_status "Starting bulk encryption process..."
print_status "Project ID: $PROJECT_ID"
print_status "KeyRing: $KEYRING_NAME"
print_status "CryptoKey: $CRYPTOKEY_NAME"
print_status "Bucket: $BUCKET_NAME"

# Download allen-p directory if it doesn't exist
MYDIR=allen-p
if [ ! -d "$MYDIR" ]; then
    print_status "Downloading allen-p email directory from Enron corpus..."
    if gsutil -m cp -r gs://enron_emails/allen-p .; then
        print_status "Directory downloaded successfully"
    else
        print_error "Failed to download allen-p directory. Please check your permissions."
        exit 1
    fi
else
    print_status "Using existing allen-p directory"
fi

# Count total files to encrypt
FILES=$(find $MYDIR -type f -not -name "*.encrypted")
TOTAL_FILES=$(echo "$FILES" | wc -l)
print_status "Found $TOTAL_FILES files to encrypt"

# Initialize counters
ENCRYPTED_COUNT=0
FAILED_COUNT=0
START_TIME=$(date +%s)

# Create progress tracking
print_status "Starting encryption process..."
echo "Progress: [..................] 0%"

# Function to show progress
show_progress() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))
    
    printf "\rProgress: ["
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' '.'
    printf "] %d%% (%d/%d)" $percent $current $total
}

# Encrypt each file
for file in $FILES; do
    ((ENCRYPTED_COUNT++))
    show_progress $ENCRYPTED_COUNT $TOTAL_FILES
    
    # Skip if already encrypted
    if [[ "$file" == *.encrypted ]]; then
        continue
    fi
    
    # Check if file is not empty
    if [ ! -s "$file" ]; then
        print_warning "Skipping empty file: $file"
        continue
    fi
    
    # Base64 encode file content
    PLAINTEXT=$(cat "$file" | base64 -w0)
    
    # Skip if encoding failed
    if [ -z "$PLAINTEXT" ]; then
        print_warning "Failed to encode file: $file"
        ((FAILED_COUNT++))
        continue
    fi
    
    # Encrypt the file
    if curl -s "https://cloudkms.googleapis.com/v1/projects/$PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
        -d "{\"plaintext\":\"$PLAINTEXT\"}" \
        -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
        -H "Content-Type:application/json" \
    | jq .ciphertext -r > "$file.encrypted" 2>/dev/null; then
        # Verify the encrypted file was created and is not empty
        if [ ! -s "$file.encrypted" ]; then
            print_warning "Encryption produced empty file for: $file"
            rm -f "$file.encrypted"
            ((FAILED_COUNT++))
        fi
    else
        print_warning "Failed to encrypt file: $file"
        ((FAILED_COUNT++))
    fi
done

echo "" # New line after progress bar

# Calculate statistics
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
SUCCESSFUL_COUNT=$((ENCRYPTED_COUNT - FAILED_COUNT))

print_status "Encryption phase completed"
print_status "  - Total files processed: $ENCRYPTED_COUNT"
print_status "  - Successfully encrypted: $SUCCESSFUL_COUNT"
print_status "  - Failed: $FAILED_COUNT"
print_status "  - Duration: ${DURATION} seconds"

# Upload encrypted files to Cloud Storage
print_status "Uploading encrypted files to Cloud Storage..."

# Find all encrypted files
ENCRYPTED_FILES=$(find $MYDIR -name "*.encrypted" -type f)
UPLOAD_COUNT=0
UPLOAD_FAILED=0

if [ -n "$ENCRYPTED_FILES" ]; then
    # Create directory structure in bucket
    print_status "Creating directory structure in Cloud Storage..."
    
    # Upload files maintaining directory structure
    for encrypted_file in $ENCRYPTED_FILES; do
        # Get relative path from allen-p
        RELATIVE_PATH=$(echo "$encrypted_file" | sed "s|^$MYDIR/||")
        GCS_PATH="gs://${BUCKET_NAME}/${MYDIR}/${RELATIVE_PATH}"
        
        if gsutil cp "$encrypted_file" "$GCS_PATH" 2>/dev/null; then
            ((UPLOAD_COUNT++))
        else
            ((UPLOAD_FAILED++))
            print_warning "Failed to upload: $encrypted_file"
        fi
    done
    
    print_status "Upload completed"
    print_status "  - Files uploaded: $UPLOAD_COUNT"
    print_status "  - Upload failures: $UPLOAD_FAILED"
else
    print_warning "No encrypted files found to upload"
fi

# Display final summary
echo ""
echo "========================================"
print_status "BULK ENCRYPTION SUMMARY"
echo "========================================"
echo "Directory processed: $MYDIR"
echo "Total files found: $TOTAL_FILES"
echo "Successfully encrypted: $SUCCESSFUL_COUNT"
echo "Encryption failures: $FAILED_COUNT"
echo "Files uploaded to GCS: $UPLOAD_COUNT"
echo "Upload failures: $UPLOAD_FAILED"
echo "Processing time: ${DURATION} seconds"
echo "Cloud Storage bucket: gs://${BUCKET_NAME}/${MYDIR}/"
echo "Encryption key: projects/$PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME"

if [ $FAILED_COUNT -eq 0 ] && [ $UPLOAD_FAILED -eq 0 ]; then
    echo "Status: ✓ ALL OPERATIONS SUCCESSFUL"
else
    echo "Status: ⚠ COMPLETED WITH SOME FAILURES"
fi
echo "========================================"

print_status "Bulk encryption completed! 🎉"
print_status "Next steps:"
echo "  1. Verify files in Cloud Storage: gsutil ls -r gs://${BUCKET_NAME}/${MYDIR}/"
echo "  2. Check a sample encrypted file: gsutil cat gs://${BUCKET_NAME}/${MYDIR}/inbox/1..encrypted"
echo "  3. View Cloud KMS audit logs in the GCP Console"
echo "  4. Monitor KMS usage and costs in the GCP Console"

# Clean up option
echo ""
read -p "Do you want to remove local encrypted files to save space? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Cleaning up local encrypted files..."
    find $MYDIR -name "*.encrypted" -type f -delete
    print_status "Local encrypted files removed"
else
    print_status "Local encrypted files preserved"
fi