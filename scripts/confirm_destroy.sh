#!/bin/bash
set -e

: "${CONFIRM_DESTROY:?Need CONFIRM_DESTROY (set to 'yes' to proceed)}"

if [[ "$CONFIRM_DESTROY" != "yes" ]]; then
  echo "❌ Destroy not confirmed."
  echo "👉 Set CONFIRM_DESTROY=yes to allow destruction."
  exit 1
fi

echo "✅ Destroy confirmed. Proceeding..."
