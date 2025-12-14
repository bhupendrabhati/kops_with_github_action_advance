#!/bin/bash
set -e

# -------- REQUIRED ENV CHECKS --------
: "${CLUSTER_NAME:?Need CLUSTER_NAME}"
: "${STATE_BUCKET:?Need STATE_BUCKET}"
: "${KOPS_STATE_STORE:?Need KOPS_STATE_STORE}"
: "${CONTROL_PLANE_COUNT:?Need CONTROL_PLANE_COUNT}"
: "${WORKER_COUNT:?Need WORKER_COUNT}"
: "${CONTROL_PLANE_SIZE:?Need CONTROL_PLANE_SIZE}"
: "${WORKER_SIZE:?Need WORKER_SIZE}"
: "${ENVIRONMENT:?Need ENVIRONMENT}"
: "${SSH_CIDR:?Need SSH_CIDR}"

# -------- VALIDATION --------
if (( CONTROL_PLANE_COUNT < 1 || CONTROL_PLANE_COUNT > 3 )); then
  echo "❌ Control plane count must be between 1 and 3"
  exit 1
fi

if (( WORKER_COUNT < 1 || WORKER_COUNT > 5 )); then
  echo "❌ Worker count must be between 1 and 5"
  exit 1
fi

# -------- LOG CONFIG --------
echo "🚀 Creating kOps cluster"
echo "  Cluster     : $CLUSTER_NAME"
echo "  Environment : $ENVIRONMENT"
echo "  Masters     : $CONTROL_PLANE_COUNT x $CONTROL_PLANE_SIZE"
echo "  Workers     : $WORKER_COUNT x $WORKER_SIZE"

# -------- CONTROL PLANE DISTRIBUTION --------
CP_A=0; CP_B=0; CP_C=0
if (( CONTROL_PLANE_COUNT >= 1 )); then CP_A=1; fi
if (( CONTROL_PLANE_COUNT >= 2 )); then CP_B=1; fi
if (( CONTROL_PLANE_COUNT == 3 )); then CP_C=1; fi

export CP_A CP_B CP_C

# -------- RENDER YAML --------
envsubst < kops/cluster.yaml.tmpl > /tmp/cluster.yaml

# -------- APPLY --------
kops replace -f /tmp/cluster.yaml --name "$CLUSTER_NAME"
kops update cluster --yes --admin
kops validate cluster --wait 10m
