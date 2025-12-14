#!/bin/bash
set -e

# -------- REQUIRED ENV CHECKS --------
: "${STATE_BUCKET:?Need STATE_BUCKET}"
: "${CONFIRM_DESTROY:?Need CONFIRM_DESTROY}"

if [[ "$CONFIRM_DESTROY" != "yes" ]]; then
  echo "❌ Backend bucket deletion not confirmed."
  echo "👉 Set CONFIRM_DESTROY=yes to proceed."
  exit 1
fi

echo "🪣 Deleting Terraform backend S3 bucket"
echo "  Bucket: s3://$STATE_BUCKET"

# Empty the bucket (including versioned objects, if any)
aws s3 rm "s3://$STATE_BUCKET" --recursive

# Delete the bucket
aws s3 rb "s3://$STATE_BUCKET"

echo "✅ Backend bucket deleted successfully"
