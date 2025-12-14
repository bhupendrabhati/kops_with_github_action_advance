# IDP: Terraform + kOps + nginx (ap-south-1)

This repository contains an end-to-end Internal Developer Platform (IDP) demo built with:

- **Terraform** — provisioning AWS infrastructure (S3 state bucket for kOps, IAM, VPC, optional ECR)
- **kOps** — creating and managing a Kubernetes cluster
- **kubectl** — deploying a demo nginx application (NodePort) to the cluster
---

**What it creates:**
- S3 bucket to store kOps state (with versioning & encryption)
- IAM user + least-privilege policy for kOps (outputs access key)
- Minimal VPC (2 public subnets) — optional, you can use default VPC

**How to use:**
1. Install: terraform, awscli, kops, kubectl
2. Copy `terraform.tfvars.example` → `terraform.tfvars` and edit variables if needed.
3. `terraform init`
4. `terraform apply -auto-approve`
5. Set environment variables using Terraform outputs:
   ```bash
   export AWS_REGION=ap-south-1
   export AWS_ACCESS_KEY_ID=<from tf output>
   export AWS_SECRET_ACCESS_KEY=<from tf output>
   export KOPS_STATE_STORE=s3://<kops-state-bucket-name>
   ```
6. Create cluster (gossip DNS):
   ```bash
   kops create cluster --name my-idp.k8s.local --state ${KOPS_STATE_STORE} --zones ap-south-1a,ap-south-1b --node-count 2 --node-size t3.small --master-size t3.medium --yes
   kops validate cluster --state ${KOPS_STATE_STORE} --name my-idp.k8s.local
   ```

## Repo structure (what you'll find)
```
infra-kops/                             # Terraform code (creates kops S3 bucket, IAM, VPC, etc.)
    policies/
        kops_iam_policy                 # JSON source file
        kops_iam_policy_notes           # Text File
    scripts/                            # helpers: open_nodeport.sh, close_nodeport.sh, build_and_push_ecr.sh
       bootstrap.sh                     # Bootstrap Script
    iam_kops.tf                         # IAM Policies
    nginx-deploy.yaml                   # example nginx deployment
    nginx-svc.yaml                      # example nginx service (NodePort)
    outputs.tf                          # Terrafrom Outputs
    providers.tf                        # Provider is AWS 
    random.tf                           # Suffix Random numbers for S3 bucket
    README.md                           # This file or Current File
    s3_kops.tf                          # S3 bucket policies
    terraform.tfvars.example            # Some other variables Defined here
    variables.tf                        # Variables for main.tf
    vpc_minimal.tf                      # VPC Configuration
```

---

## Quick Summary (one-liner)
1. Run `terraform apply` to create S3 bucket + IAM + network.  
2. Use `kops` with `KOPS_STATE_STORE` pointing to the bucket to create a cluster.  
3. Deploy nginx using `kubectl` (YAML) or `helm` (chart).  
4. Access via `kubectl port-forward` or NodePort (open SG for your IP).  
5. Tear down: `helm uninstall`/`kubectl delete` → `kops delete cluster` → `terraform destroy` (empty S3 versions if needed).

---

## Prerequisites (local)
- AWS CLI configured (`aws configure`) with permissions for S3, EC2, IAM, ECR, ASG, ELB
- terraform (v1.x)
- kops (latest)
- kubectl (compatible with k8s)
- docker (if building images)
- jq
---

## Step-by-step (complete instructions)

> **Set variables used below** (adjust values if you used different names)
```bash
# Example values used in this repo
export AWS_REGION="ap-south-1"
export CLUSTER_NAME="my-idp.k8s.local"
```

### 1) Provision infra with Terraform
```bash
cd infra-kops
terraform init
terraform apply -auto-approve
# capture outputs (kops state bucket)
terraform output -json > tf_outputs.json
jq -r .kops_state_bucket.value tf_outputs.json
```
Note output keys: `kops_state_bucket`, `cluster_name`, `region`.

### 2) Configure environment for kOps
```bash
export KOPS_STATE_STORE="s3://$(jq -r .kops_state_bucket.value tf_outputs.json)"
export CLUSTER_NAME="$(jq -r .cluster_name.value tf_outputs.json || echo my-idp.k8s.local)"
export AWS_REGION="ap-south-1"
```

### 3) Create the kOps cluster
```bash
kops create cluster --name ${CLUSTER_NAME} --state ${KOPS_STATE_STORE}   --zones ap-south-1a,ap-south-1b --node-count 2 --node-size t3.small   --master-size t3.medium --yes

# Export kubeconfig and wait for nodes
kops export kubecfg ${CLUSTER_NAME} --state ${KOPS_STATE_STORE}
kubectl get nodes -o wide
kops validate cluster --state ${KOPS_STATE_STORE} || true
```

### 4) Deploy nginx (YAML)
```bash
# from repository root
kubectl apply -f nginx-deploy.yaml
kubectl apply -f nginx-svc.yaml
kubectl get pods,svc -o wide

# quick test locally (port-forward)
kubectl port-forward svc/nginx-demo 8080:80
# then open http://localhost:8080
```

### 5) Access externally via NodePort (optional, for demo)
1. Get your public IP:
```bash
MY_IP=$(curl -s https://ifconfig.me)
```
2. Find a node instance ID (match node external IP to EC2 instance), then get its SG:
```bash
kubectl get nodes -o wide
# find external IP, then in AWS:
aws ec2 describe-instances --filters "Name=ip-address,Values=<NODE_PUBLIC_IP>" --query 'Reservations[0].Instances[0].InstanceId' --output text
aws ec2 describe-instances --instance-ids <INSTANCE_ID> --query 'Reservations[0].Instances[0].SecurityGroups' --output json
```
3. Add temporary SG ingress for NodePort (example 30080):
```bash
aws ec2 authorize-security-group-ingress --group-id sg-XXXXX --protocol tcp --port 30080 --cidr ${MY_IP}/32
# test http://<NODE_PUBLIC_IP>:30080
# remove when done:
aws ec2 revoke-security-group-ingress --group-id sg-XXXXX --protocol tcp --port 30080 --cidr ${MY_IP}/32
```

### 6) Tear down (order is important)
1. Delete app resources:
```bash
kubectl delete -f nginx-deploy.yaml -f nginx-svc.yaml --ignore-not-found
kubectl delete namespace demo --ignore-not-found
```
2. Delete kOps cluster (this removes EC2, ASG, ELB, instance profiles):
```bash
kops delete cluster ${CLUSTER_NAME} --state ${KOPS_STATE_STORE} --yes
# wait until EC2 instances are terminated
aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=owned" --query "Reservations[].Instances[].InstanceId" --output text
```
3. Terraform destroy:
```bash
cd infra-kops
terraform destroy -auto-approve
```
4. If `terraform destroy` fails with `BucketNotEmpty` on the S3 kOps state bucket:
- The bucket is versioned. Delete versions and delete markers before retrying (script included in `scripts/`).
- Quick check:
```bash
aws s3api list-object-versions --bucket <bucket-name> --output json | jq '. | {versions:(.Versions|length), deleteMarkers:(.DeleteMarkers|length)}'
```
- Use the included `scripts/empty_s3_versioned_bucket.sh` or follow the one-by-one delete commands.

---

## Helpful scripts (in `scripts/`)
- `open_nodeport.sh <instance-id> <port>` — opens SG for your public IP
- `close_nodeport.sh <instance-id> <port>` — revokes SG rule
- `build_and_push_ecr.sh` — builds and pushes frontend/backend images to ECR
- `empty_s3_versioned_bucket.sh` — empties versioned S3 bucket (use prior to `terraform destroy` if required)

---

## Troubleshooting
- `kops` errors: check IAM roles, instance profile, and API access.
- `kubectl` can't connect: make sure `kops export kubecfg` was run and `KUBECONFIG` is set properly.
- `terraform destroy` BucketNotEmpty: remove S3 versions (see scripts).
- NodePort unreachable: ensure SG allows traffic from your public IP.

---

## Security recommendations
- Use GitHub OIDC for CI (no long-lived secrets).
- Keep state bucket private and enable encryption + bucket policies.
- Use private nodes and ALB/Ingress for production workloads.

---

## Cleanup checklist (final verification)
```bash
# no clusters in kops state store
kops get clusters --state ${KOPS_STATE_STORE} || true

# no EC2 instances linked to the cluster
aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/${CLUSTER_NAME},Values=owned" --query "Reservations[].Instances[].InstanceId" --output text

# S3 bucket removed or empty
aws s3 ls ${KOPS_STATE_STORE} || true
```
--- 

**Note:** This repo is intended for demo and learning. For production you must harden IAM, use private subnets, etc.

---
---
---
# IDP: Terraform + kOps + Kubernetes (AWS)

This project demonstrates a production-style Internal Developer Platform (IDP)
using Terraform, kOps, and GitHub Actions to provision Kubernetes clusters on AWS.

---
## Folder Structure
```text

.
├── infra-backend-s3/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── infra-terraform/
│   ├── backend.tf          # NO hardcoded bucket
│   ├── providers.tf
│   ├── variables.tf
│   ├── terraform.tfvars    # local-only
│   ├── vpc.tf
│   ├── iam_kops.tf
│   ├── outputs.tf
│   └── scripts/
│       ├── provision.sh
│       └── destroy.sh
│
├── kops/
│   ├── cluster.yaml.tmpl
│   └── scripts/
│       ├── create.sh
│       └── delete.sh
│
├── scripts/
│   ├── confirm_destroy.sh
│   └── delete_bucket.sh
│
├── apps/
│   └── nginx/
│       ├── nginx-deploy.yaml
│       └── nginx-svc.yaml
│
└── .github/
    └── workflows/
        ├── infra-provision.yml
        └── kops-provision.yml


```
---

## 🚀 Architecture Overview

- Terraform creates AWS base infrastructure (VPC, IAM).
- A single S3 bucket is used for:
  - Terraform remote backend
  - kOps cluster state
- DynamoDB provides Terraform state locking.
- kOps creates and manages the Kubernetes cluster.
- GitHub Actions orchestrate the full lifecycle.
- A demo NGINX application is deployed on Kubernetes.

---

## 📁 Repository Structure

---
---
---

infra-backend-s3/ → Creates S3 backend + DynamoDB lock

infra-terraform/ → Creates VPC + IAM (no subnets)

kops/ → kOps cluster creation & deletion

apps/nginx/ → Sample Kubernetes application

.github/workflows/ → CI/CD automation

scripts/ → Safety & cleanup helpers

---
---
---


---

## 🧱 Infrastructure Flow

1. **Backend Setup**
   - Create S3 bucket and DynamoDB table using `infra-backend-s3`

2. **Base Infrastructure**
   - Provision VPC and IAM using Terraform

3. **Kubernetes Cluster**
   - Create cluster using kOps
   - Choose environment, node sizes, and counts dynamically

4. **Application Deployment**
   - Deploy NGINX using Kubernetes manifests

5. **Cleanup**
   - Delete kOps cluster
   - Destroy Terraform infra
   - Delete backend S3 bucket (only after confirmation)

---

## ⚙️ GitHub Actions Workflows

### Infra Provision
- Inputs: environment, region, backend bucket
- Creates base AWS infrastructure

### KOPS Provision
- Inputs:
  - Environment (dev/stage/prod)
  - Control plane count (1–3)
  - Worker count (1–5)
  - Instance types
- Creates Kubernetes cluster non-interactively

---

## 🔐 Safety Features

- No hardcoded secrets
- Explicit destroy confirmation
- Backend deleted last
- Single source of truth for state

---

## 🧪 Demo Application

NGINX is deployed as:
- Deployment (2 replicas)
- NodePort service

---

## 📌 Notes

- Terraform backend bucket must exist before running workflows
- `terraform.tfvars` is for local testing only
- CI/CD overrides variables dynamically

---

## 🧠 Skills Demonstrated

- Terraform backend & locking
- kOps cluster lifecycle
- GitHub Actions CI/CD
- Kubernetes fundamentals
- Production safety patterns

---

## ARCHITECTURE DIAGRAM 

```text
Developer
   |
   v
GitHub Actions
   |
   +--> Terraform (infra-terraform)
   |       |
   |       +--> VPC + IAM
   |
   +--> kOps
           |
           +--> EC2 Masters (1–3)
           +--> EC2 Workers (1–5)
           |
           +--> Kubernetes API
                    |
                    +--> NGINX App

State Management:
- S3 (Terraform backend + kOps state)
- DynamoDB (Terraform locking)

```
---

## HOW TO EXPLAIN THIS IN INTERVIEWS (STEP-BY-STEP)

## “Tell me about your project”

### Answer:

```text
I built a production-style Kubernetes platform on AWS using Terraform and kOps.

Terraform is responsible only for base infrastructure like VPC and IAM.
The Kubernetes cluster itself is fully managed by kOps.

I use a single S3 bucket for both Terraform backend state and kOps state,
with DynamoDB for Terraform locking.

Everything is automated using GitHub Actions, where I can dynamically choose
the environment, instance sizes, and number of control plane and worker nodes.

The platform includes safety features like explicit destroy confirmation
and ordered cleanup, and I deploy a demo NGINX application to validate the cluster.
```
### That answer is strong.

---

## “How do you handle failures?”
### Answer:

CI/CD does not roll back automatically, so I implemented explicit rollback logic
using GitHub Actions conditions.

If Terraform fails, the pipeline automatically runs terraform destroy.
If kOps fails, the cluster is deleted automatically.

Full cleanup is protected by explicit confirmation to avoid accidental deletion.

---

## “Why kOps instead of EKS?”
### Answer:

kOps gives me full control over the Kubernetes control plane and infrastructure.
It’s closer to how Kubernetes works internally and is excellent for understanding
cluster lifecycle, networking, and etcd management.

---

## “EXPLAIN THIS TO HR” (NON-TECHNICAL)
### Answer:

I built an automated cloud platform that can create and delete Kubernetes clusters
on AWS safely and reliably.

The system is fully automated and uses best practices to avoid mistakes,
such as automatically cleaning up resources if something goes wrong.

It’s designed like real company systems, where infrastructure is created,
validated, and removed in a controlled way using automation pipelines.

---