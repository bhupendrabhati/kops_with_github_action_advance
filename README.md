# Internal Developer Platform (IDP) using Terraform + kOps + Kubernetes (AWS)

This repository demonstrates a production-style Internal Developer Platform (IDP)
built using Terraform, kOps, Kubernetes, and GitHub Actions on AWS.

The project automates infrastructure provisioning, Kubernetes cluster lifecycle,
application deployment, and safe cleanup using CI/CD pipelines.

---

## 🚀 What This Project Does

- Creates a secure S3 backend + DynamoDB lock for Terraform & kOps
- Provisions AWS infrastructure (VPC, IAM) using Terraform
- Creates Kubernetes clusters using kOps
- Deploys applications using kubectl
- Automates everything with GitHub Actions
- Implements rollback and safety mechanisms for failures

---

## 🧱 Architecture Overview

```
Developer
   |
   v
GitHub Actions
   |
   ├── Terraform (infra-backend-s3)
   │       └── S3 Backend + DynamoDB Lock
   |
   ├── Terraform (infra-terraform)
   │       └── VPC + IAM (kOps user)
   |
   ├── kOps
   │       ├── Control Plane (1–3 EC2)
   │       └── Worker Nodes (1–5 EC2)
   |
   └── Kubernetes
           └── Demo NGINX Application
```


**State Management**
- S3 → Terraform backend + kOps state
- DynamoDB → Terraform state locking

---

## 📁 Repository Structure
```
.
├── infra-backend-s3/        # Creates S3 backend + DynamoDB
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── infra-terraform/         # Base AWS infrastructure
│   ├── backend.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── terraform.tfvars    # Local testing only
│   ├── vpc.tf
│   ├── iam_kops.tf
│   ├── outputs.tf
│   └── scripts/
│       ├── provision.sh
│       └── destroy.sh
│
├── kops/                   # Kubernetes cluster lifecycle
│   ├── cluster.yaml.tmpl
│   └── scripts/
│       ├── create.sh
│       └── delete.sh
│
├── apps/
│   └── nginx/
│       ├── nginx-deploy.yaml
│       └── nginx-svc.yaml
│
├── scripts/                # Safety & cleanup helpers
│   ├── confirm_destroy.sh
│   └── delete_bucket.sh
│
└── .github/
    └── workflows/
        ├── backend-provision.yml
        ├── infra-provision.yml
        ├── kops-provision.yml
        ├── app-deploy.yml
        └── full-cleanup.yml
```
---

## ⚙️ GitHub Actions Workflow Flow

### 1️⃣ Backend Provision
Creates:
- S3 bucket for Terraform & kOps state
- DynamoDB table for locking

Workflow:
```
.github/workflows/backend-provision.yml
```
---

### 2️⃣ Infrastructure Provision
Creates:
- VPC
- IAM user and policy for kOps

Rollback:
- Automatically runs `terraform destroy` if apply fails

Workflow:
```
.github/workflows/infra-provision.yml
```

---

### 3️⃣ Kubernetes Provision (kOps)
Creates:
- Kubernetes cluster
- Control plane nodes (1–3)
- Worker nodes (1–5)

Rollback:
- Automatically deletes the cluster if provisioning fails

Workflow:
```
.github/workflows/kops-provision.yml
```

---

### 4️⃣ Application Deployment
Deploys:
- NGINX Deployment (2 replicas)
- NodePort Service

Workflow:
```
.github/workflows/app-deploy.yml
```

Uses:
- `kops export kubeconfig`
- `kubectl apply`

---

### 5️⃣ Full Cleanup (Protected)
Deletes (in order):
1. Kubernetes cluster
2. Terraform infrastructure
3. Backend S3 bucket (last)

Requires explicit confirmation:
    ```
    CONFIRM_DESTROY = yes
    ```

Workflow
```
.github/workflows/full-cleanup.yml
```

---

## 🔐 Safety & Best Practices

- No hardcoded secrets
- Explicit destroy confirmation
- Ordered cleanup
- Terraform state locking
- Rollback on failures

---

## 🧠 Interview Explanations

### 🔹 Technical (DevOps / Cloud)

> I built a Kubernetes platform on AWS using Terraform and kOps.
Terraform provisions base infrastructure, while kOps manages the Kubernetes cluster lifecycle.
Everything is automated using GitHub Actions with rollback and safety controls.

---

### 🔹 Failure Handling

> If Terraform fails, the pipeline automatically destroys created resources.
If kOps fails, the cluster is deleted.
Full cleanup requires manual confirmation to prevent accidental deletion.

---

### 🔹 Why kOps (Not EKS)?

> kOps provides full control over Kubernetes internals like etcd, networking,
and node lifecycle, making it ideal for understanding Kubernetes deeply.

---

### 🔹 HR / Non-Technical Explanation

> I built an automated cloud system that safely creates and deletes infrastructure.
It prevents mistakes by using automation and ensures cleanup if something goes wrong.

---

## 📌 Skills Demonstrated

- Terraform backend & locking
- Kubernetes lifecycle with kOps
- GitHub Actions CI/CD
- Rollback & safety patterns
- Kubernetes application deployment
- AWS infrastructure fundamentals

---

## ⚠️ Note

This project is for learning and demonstration purposes.
Production systems require hardened IAM, private networking, and managed ingress.

---
