# Cloud KMS

This repository contains a complete implementation of a Google Cloud Platform (GCP) lab focused on **Cloud Key Management Service (KMS)** for encrypting data and managing encryption keys. The project demonstrates advanced security features including secure Cloud Storage setup, key management, and audit logging. 

## Video

https://youtu.be/pAgyV0L7FsM

## 🎯 Project Overview 

This lab project covers:
- Setting up secure Cloud Storage buckets
- Managing encryption keys using Cloud KMS
- Encrypting and decrypting data programmatically
- Bulk encryption of email corpus data
- IAM permissions management for KMS resources
- Viewing Cloud Storage audit logs

## 📚 What You'll Learn

- How to encrypt data and manage encryption keys using Cloud KMS
- Working with KeyRings and CryptoKeys
- Using Cloud KMS REST API for encryption/decryption
- Implementing bulk encryption workflows
- Managing IAM permissions for cryptographic operations
- Monitoring KMS activities through audit logs

## 🛠️ Prerequisites

- Google Cloud Platform account with billing enabled
- Basic familiarity with command line interfaces
- Understanding of encryption concepts
- Chrome browser (recommended for GCP Console)

## 🚀 Setup Instructions

### 1. Initial Setup

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable cloudkms.googleapis.com
gcloud services enable storage.googleapis.com
```

### 2. Create Cloud Storage Bucket

```bash
# Set bucket name (replace with your unique name)
BUCKET_NAME="your-project-id-enron_corpus"

# Create the bucket
gsutil mb gs://${BUCKET_NAME}
```

### 3. Create KMS Resources

```bash
# Set environment variables
KEYRING_NAME=test
CRYPTOKEY_NAME=qwiklab

# Create KeyRing
gcloud kms keyrings create $KEYRING_NAME --location global

# Create CryptoKey
gcloud kms keys create $CRYPTOKEY_NAME --location global \
    --keyring $KEYRING_NAME \
    --purpose encryption
```

## 📋 Lab Tasks

### Task 1: Download Sample Data

```bash
# Download sample email from Enron corpus
gsutil cp gs://enron_emails/allen-p/inbox/1. .

# Verify content
tail 1.
```

### Task 2: Single File Encryption

```bash
# Base64 encode the email content
PLAINTEXT=$(cat 1. | base64 -w0)

# Encrypt using KMS API
curl -v "https://cloudkms.googleapis.com/v1/projects/$PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:encrypt" \
  -d "{\"plaintext\":\"$PLAINTEXT\"}" \
  -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type: application/json" \
| jq .ciphertext -r > 1.encrypted

# Upload encrypted file to Cloud Storage
gsutil cp 1.encrypted gs://${BUCKET_NAME}
```

### Task 3: Verify Decryption

```bash
# Decrypt the file to verify encryption worked
curl -v "https://cloudkms.googleapis.com/v1/projects/$PROJECT_ID/locations/global/keyRings/$KEYRING_NAME/cryptoKeys/$CRYPTOKEY_NAME:decrypt" \
  -d "{\"ciphertext\":\"$(cat 1.encrypted)\"}" \
  -H "Authorization:Bearer $(gcloud auth application-default print-access-token)" \
  -H "Content-Type:application/json" \
| jq .plaintext -r | base64 -d
```

### Task 4: Configure IAM Permissions

```bash
# Get current user email
USER_EMAIL=$(gcloud auth list --limit=1 2>/dev/null | grep '@' | awk '{print $2}')

# Grant KMS admin permissions
gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
    --location global \
    --member user:$USER_EMAIL \
    --role roles/cloudkms.admin

# Grant encrypt/decrypt permissions
gcloud kms keyrings add-iam-policy-binding $KEYRING_NAME \
    --location global \
    --member user:$USER_EMAIL \
    --role roles/cloudkms.cryptoKeyEncrypterDecrypter
```

### Task 5: Bulk Encryption

Use the provided script to encrypt multiple files:

```bash
# Download allen-p email directory
gsutil -m cp -r gs://enron_emails/allen-p .

# Run bulk encryption script
./scripts/bulk_encrypt.sh
```

## 📁 Repository Structure

```
├── README.md                 # This file
├── scripts/
│   ├── setup.sh             # Initial setup script
│   ├── bulk_encrypt.sh      # Bulk encryption script
│   ├── single_encrypt.sh    # Single file encryption
│   └── verify_decrypt.sh    # Decryption verification
├── docs/
│   ├── SETUP.md            # Detailed setup guide
│   ├── API_USAGE.md        # KMS API usage examples
│   └── TROUBLESHOOTING.md  # Common issues and solutions
└── examples/
    ├── sample_encrypt.json  # Sample API request
    └── sample_response.json # Sample API response
```

## 🔐 Security Considerations

- **KeyRings and CryptoKeys cannot be deleted** in Cloud KMS - plan your naming strategy carefully
- Use least-privilege IAM policies for production environments
- Consider using Customer-Managed Encryption Keys (CMEK) for enhanced control
- Enable audit logging for compliance and monitoring
- Rotate encryption keys regularly for production use

## 🔍 Viewing Audit Logs

1. Navigate to **Cloud Overview > Activity** in the GCP Console
2. Click **View Log Explorer**
3. Select **Cloud KMS Key Ring** as the Resource Type
4. Review all KeyRing creation and modification activities

## 📊 Monitoring and Logging

The project includes comprehensive logging for:
- KeyRing and CryptoKey creation
- Encryption and decryption operations
- IAM policy modifications
- API call patterns and frequencies

## 🐛 Troubleshooting

### Common Issues

**Authentication Errors:**
```bash
# Re-authenticate if needed
gcloud auth application-default login
```

**Permission Denied:**
```bash
# Verify project permissions
gcloud auth list
gcloud config list project
```

**API Not Enabled:**
```bash
# Enable KMS API
gcloud services enable cloudkms.googleapis.com
```

## 🔗 Additional Resources

- [Cloud KMS Documentation](https://cloud.google.com/kms/docs)
- [Cloud KMS REST API Reference](https://cloud.google.com/kms/docs/reference/rest)
- [Cloud Storage Security Guide](https://cloud.google.com/storage/docs/security)
- [GCP IAM Best Practices](https://cloud.google.com/iam/docs/using-iam-securely)

## 📝 Notes

- This project uses the Enron email corpus for demonstration purposes
- Encryption operations may take time for large datasets
- Cloud KMS pricing applies for key operations
- Server-side encryption in Cloud Storage is recommended for production use

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is provided as-is for educational purposes as part of Google Cloud Platform training materials.

---

**⚠️ Important:** This lab uses temporary credentials and is designed for learning purposes. Do not use personal Google Cloud accounts to avoid unexpected charges.
