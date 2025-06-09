#!/bin/bash

# Google Cloud KMS Lab Setup Script
# This script sets up the initial environment for the KMS encryption lab

set -e  # Exit on any error

echo "🚀 Starting Google Cloud KMS Lab Setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI not found. Please install Google Cloud SDK first."
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_warning "jq not found. Installing jq..."
    # Install jq based on the system
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get update && sudo apt-get install -y jq
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq
    else
        print_error "Please install jq manually for your system"
        exit 1
    fi
fi

# Get project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    print_error "No project set. Please run: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

print_status "Using project: $PROJECT_ID"

# Set environment variables
export DEVSHELL_PROJECT_ID=$PROJECT_ID
export KEYRING_NAME=test
export CRYPTOKEY_NAME=qwiklab
export BUCKET_NAME="${PROJECT_ID}-enron_corpus"

print_status "Environment variables set:"
echo "  - PROJECT_ID: $PROJECT_ID"
echo "  - KEYRING_NAME: $KEYRING_NAME"
echo "  - CRYPTOKEY_NAME: $CRYPTOKEY_NAME"
echo "  - BUCKET_NAME: $BUCKET_NAME"

# Enable required APIs
print_status "Enabling required APIs..."
gcloud services enable cloudkms.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable logging.googleapis.com

# Create Cloud Storage bucket
print_status "Creating Cloud Storage bucket..."
if gsutil mb gs://${BUCKET_NAME} 2>/dev/null; then
    print_status "Bucket created successfully: gs://${BUCKET_NAME}"
else
    print_warning "Bucket may already exist or name is taken. Continuing..."
fi

# Create KMS KeyRing
print_status "Creating KMS KeyRing..."
if gcloud kms keyrings create $KEYRING_NAME --location global 2>/dev/null; then
    print_status "KeyRing created successfully: $KEYRING_NAME"
else
    print_warning "KeyRing may already exist. Continuing..."
fi

# Create CryptoKey
print_status "Creating CryptoKey..."
if gcloud kms keys create $CRYPTOKEY_NAME --location global \
    --keyring $KEYRING_NAME \
    --purpose encryption 2>/dev/null; then
    print_status "CryptoKey created successfully: $CRYPTOKEY_NAME"
else
    print_warning "CryptoKey may already exist. Continuing..."
fi

# Get current user email
USER_EMAIL=$(gcloud auth list --limit=1 2>/dev/null | grep '@' | awk '{print $2}')
print_status "Current user: $USER_EMAIL"

# Set IAM permissions
print_status "Setting IAM permissions..."
gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
    --location global \
    --member user:$USER_EMAIL \
    --role roles/cloudkms.admin

gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
    --location global \
    --member user:$USER_EMAIL \
    --role roles/cloudkms.cryptoKeyEncrypterDecrypter

# Download sample data
print_status "Downloading sample data..."
if gsutil cp gs://enron_emails/allen-p/inbox/1. . 2>/dev/null; then
    print_status "Sample email downloaded successfully"
else
    print_warning "Could not download sample data. You may need to do this manually."
fi

# Create environment file for future use
cat > .env << EOF
# Google Cloud KMS Lab Environment Variables
export PROJECT_ID=$PROJECT_ID
export DEVSHELL_PROJECT_ID=$PROJECT_ID
export KEYRING_NAME=$KEYRING_NAME
export CRYPTOKEY_NAME=$CRYPTOKEY_NAME
export BUCKET_NAME=$BUCKET_NAME
export USER_EMAIL=$USER_EMAIL
EOF

print_status "Environment file created: .env"
print_status "To load environment variables in future sessions, run: source .env"

# Verify setup
print_status "Verifying setup..."
echo "  - Checking KeyRing exists..."
if gcloud kms keyrings describe $KEYRING_NAME --location global &>/dev/null; then
    echo "    ✓ KeyRing exists"
else
    echo "    ✗ KeyRing not found"
fi

echo "  - Checking CryptoKey exists..."
if gcloud kms keys describe $CRYPTOKEY_NAME --location global --keyring $KEYRING_NAME &>/dev/null; then
    echo "    ✓ CryptoKey exists"
else
    echo "    ✗ CryptoKey not found"
fi

echo "  - Checking bucket exists..."
if gsutil ls gs://${BUCKET_NAME} &>/dev/null; then
    echo "    ✓ Bucket exists"
else
    echo "    ✗ Bucket not found"
fi

print_status "Setup completed successfully! 🎉"
print_status "Next steps:"
echo "  1. Run './scripts/single_encrypt.sh' to encrypt a single file"
echo "  2. Run './scripts/bulk_encrypt.sh' to encrypt multiple files"
echo "  3. Check your Cloud Storage bucket for encrypted files"
echo "  4. View audit logs in the GCP Console"

echo ""
print_warning "Remember: KeyRings and CryptoKeys cannot be deleted in Cloud KMS!"
print_warning "This is a feature designed for security and compliance."