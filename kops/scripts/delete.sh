#!/bin/bash
set -e

# -------- REQUIRED ENV CHECKS --------
: "${CLUSTER_NAME:?Need CLUSTER_NAME}"
: "${STATE_BUCKET:?Need STATE_BUCKET}"
: "${KOPS_STATE_STORE:?Need KOPS_STATE_STORE}"

echo "🗑️ Deleting kOps cluster"
echo "  Cluster     : $CLUSTER_NAME"
echo "  State Store : $KOPS_STATE_STORE"

kops delete cluster --name "$CLUSTER_NAME" --yes
