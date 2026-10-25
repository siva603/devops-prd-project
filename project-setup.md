# Enterprise DevOps & AIOps Production Playbook

> **Target Audience**: Designed for DevOps Engineers (from fresh engineers deploying their first production system to senior architects).  
> **Dual-Architecture Blueprint**:
> 1. **AWS Free Tier Edition (\$0.00/month Budget)**: Single EBS Volume (10 GiB) for PostgreSQL StatefulSet, single worker node, automated S3 backups, and cost guardrails.
> 2. **Real IT Enterprise Edition (Multi-AZ High Availability)**: Multi-AZ EKS worker nodes across 3 Availability Zones, Multi-AZ AWS RDS PostgreSQL with synchronous standby, 3x NAT Gateways, and Multi-AZ Application Load Balancer.  
> **Command Standard**: All instructions are provided primarily for **Linux (EC2 / Ubuntu / Amazon Linux 2023)**, with matching **Windows (PowerShell)** commands included for local development.

---

## Table of Contents

1. [AWS Architecture & Cost Guardrails](#1-aws-architecture--cost-guardrails)
   - [1.1 AWS Free Tier Architecture & Guardrails (\$0.00 Standard)](#11-aws-free-tier-architecture--guardrails-000-standard)
   - [1.2 Real IT Enterprise Production Architecture (Multi-AZ & Cost Analysis)](#12-real-it-enterprise-production-architecture-multi-az--cost-analysis)
   - [1.3 Step-by-Step Migration Guide: Upgrading from Free Tier to Enterprise Multi-AZ](#13-step-by-step-migration-guide-upgrading-from-free-tier-to-enterprise-multi-az)
2. [Phase 1: Local Development, Testing & Verification](#2-phase-1-local-development-testing--verification)
   - [Files Involved & Roles](#files-involved-in-phase-1)
   - [Real-Time IT Company Test Cases (All 8 Services in the Stack)](#real-time-it-company-test-cases-all-8-services-in-the-stack)
   - [Local Step-by-Step Execution (Linux & Windows)](#local-step-by-step-execution-linux--windows)
3. [Phase 2: Source Code, Testing & CI/CD Pipeline (Trivy Security)](#3-phase-2-source-code-testing--cicd-pipeline-trivy-security)
   - [Files Involved & Roles](#files-involved-in-phase-2)
   - [CI/CD Step-by-Step Execution (Linux & Windows)](#cicd-step-by-step-execution-linux--windows)
   - [GitHub Repository Secrets Setup](#github-repository-secrets-setup)
   - [Visual Reference & Checkpoints](#ci-visual-reference--checkpoints)
4. [Phase 3: AWS Infrastructure & Enterprise IAM Setup (Company Standard)](#4-phase-3-aws-infrastructure--enterprise-iam-setup-company-standard)
   - [Files Involved & Roles](#files-involved-in-phase-3)
   - [Enterprise IAM Governance: DevOpsEngineers & CICDAutomation Groups](#enterprise-iam-governance-devopsengineers--cicdautomation-groups)
   - [Why Repository Names Must Start with the Project Prefix (`boutique-*`)](#why-repository-names-must-start-with-the-project-prefix-boutique-)
   - [Terraform Infrastructure Provisioning: Complete Pre-Flight & Execution](#terraform-infrastructure-provisioning-complete-pre-flight--execution)
   - [Storing Infrastructure State Remotely (Amazon S3 Backend - Free Tier Standard)](#storing-infrastructure-state-remotely-amazon-s3-backend---free-tier-standard)
   - [Post-Provisioning Verification Commands](#post-provisioning-verification-commands)
   - [Deep-Dive Technical Breakdown: Understanding the Core Cluster Commands](#deep-dive-technical-breakdown-understanding-the-core-cluster-commands)
5. [Phase 4: Kubernetes Deployment, GitOps (ArgoCD) & Single EBS Storage](#5-phase-4-kubernetes-deployment-gitops-argocd--single-ebs-storage)
   - [Files Involved & Roles](#files-involved-in-phase-4)
   - [Single EBS Volume Storage Configuration](#single-ebs-volume-storage-configuration)
   - [ArgoCD Deployment & Synchronization (Linux & Windows)](#argocd-deployment--synchronization-linux--windows)
6. [Phase 5: Enterprise Observability & Monitoring (Prometheus & Grafana)](#6-phase-5-enterprise-observability--monitoring-prometheus--grafana)
   - [Files Involved & Roles](#files-involved-in-phase-5)
   - [How to Log into Prometheus, Grafana & Alertmanager (Local & Production EKS)](#how-to-log-into-prometheus-grafana--alertmanager-local--production-eks)
   - [What to Check and Observe in Prometheus](#what-to-check-and-observe-in-prometheus)
   - [The 5 Real IT Enterprise Dashboards in Grafana](#the-5-real-it-enterprise-dashboards-in-grafana)
   - [Notification Configuration & How to Change It (Email / SES / SMTP)](#notification-configuration--how-to-change-it-email--ses--smtp)
   - [How to Retrieve and Query Microservice & System Logs](#how-to-retrieve-and-query-microservice--system-logs)
7. [Phase 6: Post-Production SRE Operations, Disaster Recovery & Chaos Tests](#7-phase-6-post-production-sre-operations-disaster-recovery--chaos-tests)
   - [What Real IT Companies Continuously Oversee](#what-real-it-companies-continuously-oversee)
   - [Proactive Early Alert (Disk Saturation Before Data Loss)](#proactive-early-alert-disk-saturation-before-data-loss)
   - [Table Deletion Disaster Recovery (Manual & Automated with BEFORE and AFTER Email Alerts)](#table-deletion-disaster-recovery-manual--automated-with-before-and-after-email-alerts)
   - [Rate Limiting Chaos Test (HTTP 429)](#rate-limiting-chaos-test-http-429)
   - [CPU High Utilization Stress Test (HPA Auto-scaling)](#cpu-high-utilization-stress-test-hpa-auto-scaling)
   - [Memory Utilization & Cgroup Limit Test](#memory-utilization--cgroup-limit-test)
8. [Phase 7: Cloud Cost Management & Safe Teardown](#8-phase-7-cloud-cost-management--safe-teardown)
9. [Industry Gap Analysis: Additional Topics to Add or Skip](#9-industry-gap-analysis-additional-topics-to-add-or-skip)

---

## 1. AWS Architecture & Cost Guardrails

### 1.1 AWS Free Tier Architecture & Guardrails ($0.00 Standard)

To guarantee **\$0.00 unexpected charges** on personal or lab AWS Free Tier accounts, this project applies strict architectural guardrails:

| AWS Component | Free Tier Monthly Limit | How This Project Configures It | Guardrail Action |
| :--- | :--- | :--- | :--- |
| **Amazon EBS** | 30 GB of gp2/gp3 storage | **Single 10 GiB EBS Volume** for PostgreSQL StatefulSet + **5 GiB** backup volume = 15 GiB total | Stays well below 30 GB quota. No Multi-AZ RDS fees. |
| **Amazon EKS Nodes** | 750 EC2 hours on micro/small | 1 managed worker node (`m7i-flex.large` or `t3.medium`). | Keep cluster running only during lab/testing hours or use Spot instances. |
| **Amazon S3** | 5 GB Standard Storage | Automated database dumps uploaded to S3 with 30-day lifecycle expiration. | Stored data < 500 MB. Zero storage bill. |
| **Amazon ECR** | 500 MB per month private | Multi-stage Docker images (Nginx frontend ~25MB, Node Alpine ~150MB). | Untagged image cleanup policy automatically deletes old revisions. |
| **CloudWatch** | 10 custom metrics + 5GB logs | Pod logs routed to CloudWatch via AWS FluentBit with 7-day retention. | Log retention set to 7 days (prevents infinite log storage accumulation). |

> [!TIP]
> **Single EBS Storage Strategy**: Rather than provisioning expensive managed AWS RDS Aurora instances (\$50+/month), the database runs as a single-node PostgreSQL StatefulSet bound to a **single 10 GiB EBS volume**. Point-in-time recovery and disaster resilience are achieved through automated cron-based backups synced to S3.

---

### 1.2 Real IT Enterprise Production Architecture (Multi-AZ & Cost Analysis)

In real IT enterprises (FinTech, E-commerce, Healthcare, SaaS), running on a Single Availability Zone (Single AZ) with a single EBS volume is strictly prohibited for production workloads. A hardware failure in one AWS data center could cause complete service downtime and data corruption.

#### Real IT Production Architecture Blueprint

```
                                  INTERNET
                                     │
                           ┌─────────▼─────────┐
                           │   AWS Route 53    │ (DNS with Health Checks)
                           └─────────┬─────────┘
                                     │
                           ┌─────────▼─────────┐
                           │   AWS WAF & ACM   │ (Web Application Firewall & SSL/TLS)
                           └─────────┬─────────┘
                                     │
      ┌──────────────────────────────┼──────────────────────────────┐
      │                              │                              │
┌─────▼──────────────────────────────▼──────────────────────────────▼─────┐
│             AWS Multi-AZ Application Load Balancer (ALB)                 │
└─────┬──────────────────────────────┬──────────────────────────────┬─────┘
      │                              │                              │
┌─────▼──────────────┐       ┌───────▼────────────┐       ┌─────────▼────────────┐
│ Availability Zone A│       │ Availability Zone B│       │ Availability Zone C  │
│ [Public Subnet A]  │       │ [Public Subnet B]  │       │ [Public Subnet C]    │
│  - NAT Gateway A   │       │  - NAT Gateway B   │       │  - NAT Gateway C     │
├────────────────────┤       ├────────────────────┤       ├──────────────────────┤
│ [Private Subnet A] │       │ [Private Subnet B] │       │ [Private Subnet C]   │
│  - EKS Node 1      │       │  - EKS Node 2      │       │  - EKS Node 3        │
│    • gateway pod   │       │    • gateway pod   │       │    • gateway pod     │
│    • auth pod      │       │    • auth pod      │       │    • auth pod        │
│    • products pod  │       │    • products pod  │       │    • products pod    │
│    • orders pod    │       │    • orders pod    │       │    • orders pod      │
├────────────────────┤       ├────────────────────┤       ├──────────────────────┤
│ [Database Subnet A]│       │ [Database Subnet B]│       │ [Database Subnet C]  │
│  - AWS RDS Primary │◄─────Synchronous Rep.─────►│  - AWS RDS Standby  │                      │  - RDS Read Replica  │
│    (PostgreSQL)    │       │    (Hot Standby)   │       │    (Analytics/Reads) │
└────────────────────┴───────┴────────────────────┴───────┴──────────────────────┘
```

#### Key Differences Between Free Tier and Enterprise Production

| Architectural Domain | AWS Free Tier Standard (Lab / Portfolio) | Real IT Enterprise Production Standard |
| :--- | :--- | :--- |
| **Availability Zones** | Single AZ (`us-east-1a` only) | Multi-AZ (3 Availability Zones: `us-east-1a`, `us-east-1b`, `us-east-1c`) |
| **Database Tier** | PostgreSQL StatefulSet on Single 10 GiB EBS Volume | Managed AWS RDS PostgreSQL Multi-AZ Cluster with synchronous physical replication |
| **Failover RPO / RTO** | RPO = 1 hour (backup interval), RTO = 5–10 mins | RPO = 0 seconds (zero data loss), RTO < 30 seconds (automatic failover) |
| **EKS Worker Nodes** | 1 Node (`m7i-flex.large` or `t3.medium`) | 3–6 Nodes spread across 3 AZs with `topologySpreadConstraints` |
| **Egress Networking** | Direct Internet Gateway or single NAT Gateway | 3 dedicated NAT Gateways (one per AZ) to eliminate cross-AZ latency and single points of failure |
| **Ingress & Security** | Single ALB Ingress | Multi-AZ ALB + AWS WAFv2 + AWS Shield + ACM TLS 1.3 certificates |
| **Secrets Management** | Kubernetes Secrets / S3 Encrypted | AWS Secrets Manager with automatic secret rotation + External Secrets Operator |

#### Enterprise Production AWS Monthly Cost Breakdown Table

| AWS Service | Production Configuration Specification | Estimated Monthly Cost (USD) |
| :--- | :--- | :--- |
| **Amazon EKS Control Plane** | Fully managed Kubernetes control plane with 99.95% SLA | **\$73.00** (\$0.10/hour) |
| **Amazon EC2 Worker Nodes** | 3x `m6i.large` instances (2 vCPU, 8 GiB RAM each) spanning 3 AZs | **\$209.52** (\$0.096/hr $\times$ 3 nodes $\times$ 720 hrs) |
| **AWS RDS Multi-AZ PostgreSQL** | `db.m6g.large` (2 vCPU, 8 GiB RAM), Multi-AZ synchronous standby + 100 GB gp3 storage | **\$282.40** |
| **AWS NAT Gateways** | 3x NAT Gateways (one per AZ for redundancy) + 100 GB data processing | **\$112.20** (\$0.045/hr $\times$ 3 $\times$ 720 hrs + data fees) |
| **Application Load Balancer** | Multi-AZ ALB + 15 Load Balancer Capacity Units (LCU) | **\$32.50** |
| **Amazon S3 & Automated Backups** | Daily snapshots, WAL archiving, 90-day retention | **\$8.50** |
| **CloudWatch & Container Insights** | Metrics, logs, alerting rules, dashboard storage | **\$18.00** |
| **AWS WAF & Shield Standard** | Rate limiting rules, SQL injection protection, bot control | **\$15.00** |
| **Total Enterprise Production Bill** | **High-Availability (99.99% Uptime) Production Infrastructure** | **~\$751.12 / month** |
| *Free Tier Project Bill* | *Single EBS Volume + Single Node (This Playbook default)* | **\$0.00 / month** |

---

### 1.3 Step-by-Step Migration Guide: Upgrading from Free Tier to Enterprise Multi-AZ

If your team is ready to promote this project from the Free Tier lab to an Enterprise Multi-AZ production deployment, follow these exact steps:

#### Step 1: Update Terraform Infrastructure Variables
In [`projects/Infrastructure/terraform.tfvars`](file:///c:/Users/U%20SIVA/Downloads/devops-ai-playbook-main/devops-ai-playbook-main/projects/Infrastructure/terraform.tfvars), increase the node group size and ensure 3 subnets across 3 distinct Availability Zones are declared:

```hcl
region = "us-east-1"
vpc_name = "Boutique-Enterprise-VPC"
vpc_cidr = "10.1.0.0/16"

subnets = [
  { name = "subnet-1a", cidr_block = "10.1.1.0/24", availability_zone = "us-east-1a" },
  { name = "subnet-1b", cidr_block = "10.1.2.0/24", availability_zone = "us-east-1b" },
  { name = "subnet-1c", cidr_block = "10.1.3.0/24", availability_zone = "us-east-1c" }
]

instance_types = ["m6i.large"]
desired_size   = 3
min_size       = 3
max_size       = 6
```

#### Step 2: Enable the Multi-AZ RDS Module in Terraform
Uncomment or add the RDS PostgreSQL module in [`projects/Infrastructure/main.tf`](file:///c:/Users/U%20SIVA/Downloads/devops-ai-playbook-main/devops-ai-playbook-main/projects/Infrastructure/main.tf):

```hcl
module "rds" {
  source = "./modules/rds"

  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.subnet_ids
  multi_az           = true
  instance_class     = "db.m6g.large"
  allocated_storage  = 100
  db_name            = "boutique"
}
```

#### Step 3: Configure Kubernetes Pod Topology Spread Constraints
To enforce that Kubernetes schedules microservice replicas evenly across all 3 Availability Zones, add `topologySpreadConstraints` to each deployment in [`gitops/k8s/backend/`](file:///c:/Users/U%20SIVA/Downloads/devops-ai-playbook-main/devops-ai-playbook-main/gitops/k8s/backend/):

```yaml
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
      labelSelector:
        matchLabels:
          app: gateway
```

#### Step 4: Decommission the Single EBS StatefulSet
1. Migrate data from the single EBS PostgreSQL container to the new AWS RDS endpoint using `pg_dump` and `pg_restore`.
2. Update the database host secret in [`gitops/k8s/secrets.yml`](file:///c:/Users/U%20SIVA/Downloads/devops-ai-playbook-main/devops-ai-playbook-main/gitops/k8s/secrets.yml) to point to the RDS cluster endpoint.
3. Remove `gitops/k8s/database/statefulset.yml` from `gitops/kustomization.yml`.
4. Commit to `main` — ArgoCD synchronizes changes with zero downtime.

---

## 2. Phase 1: Local Development, Testing & Verification

### Files Involved in Phase 1

```
projects/boutique-microservices/
├── docker-compose.yml              # Local container orchestration (all services + DB + monitoring)
├── frontend/
│   ├── Dockerfile                  # Multi-stage production container (Node build -> Nginx server)
│   └── nginx.conf                  # Reverse proxies /api/ requests to the API Gateway on port 3001
├── backend/
│   ├── package.json                # Central test runner executing all service unit tests
│   └── services/
│       ├── gateway/                # API Gateway with rate limiting & Prometheus metrics
│       ├── auth/                   # Authentication service with PBKDF2/Bcrypt & JWT
│       ├── product-service/        # Product catalog service with pagination & category filtering
│       ├── orders/                 # Order management service with cart calculation
│       ├── order-service/          # Secondary/legacy order processing service
│       └── user-service/           # User profile service with bearer token auth
├── test-local-flow.sh              # Linux/Bash automated local flow test suite
└── test-local-flow.ps1             # Windows PowerShell automated local flow test suite
```

---

### Real-Time IT Company Test Cases (All 8 Services in the Stack)

In production software engineering, every component in the architecture requires a formal Test Case Specification covering positive, negative, security, and edge scenarios:

#### 1. API Gateway Service (`gateway` - Port 3001)
| Test ID | Test Scenario | Input / Action | Expected Result | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-GW-01** | Liveness Probe | `GET /health` | HTTP 200, `{ status: "healthy", service: "gateway" }` | Response time < 50ms |
| **TC-GW-02** | Prometheus Metrics Scrape | `GET /metrics` | HTTP 200, Content-Type `text/plain` with `http_requests_total` | Contains valid Prometheus keys |
| **TC-GW-03** | Rate Limit Enforcement | Send 6 rapid requests to `/api/test-ratelimit` | Requests 1–5: HTTP 200; Request 6: **HTTP 429 Too Many Requests** | Header contains `Retry-After` |
| **TC-GW-04** | Route Reverse Proxying | `GET /api/products` | Gateway proxies request to `http://product-service:3003/products` | Product JSON array returned |
| **TC-GW-05** | Non-Existent Route | `GET /non-existent-endpoint` | **HTTP 404 Not Found**, `{ error: "Not Found" }` | No unhandled exception leak |

#### 2. Authentication Service (`auth` - Port 3002)
| Test ID | Test Scenario | Input / Action | Expected Result | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-AUTH-01** | Liveness Probe | `GET /health` | HTTP 200, `{ status: "healthy", service: "auth" }` | Response time < 30ms |
| **TC-AUTH-02** | User Registration (Positive) | `POST /register` with valid email & password | HTTP 201 Created, returns user ID & JWT token | User persisted in `auth_db` |
| **TC-AUTH-03** | User Registration (Negative) | `POST /register` with missing password | **HTTP 400 Bad Request**, validation error returned | Zero DB writes |
| **TC-AUTH-04** | Password Hashing Security | Hash password with PBKDF2/Bcrypt salt | Stored hash $\neq$ plaintext; verification matches | Salt work factor $\ge 10$ |

#### 3. Product Catalog Service (`product-service` - Port 3003)
| Test ID | Test Scenario | Input / Action | Expected Result | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-PROD-01** | Liveness Probe | `GET /health` | HTTP 200, `{ status: "healthy" }` | Response time < 30ms |
| **TC-PROD-02** | Catalog Retrieval | `GET /products` | HTTP 200 OK, returns JSON array of boutique clothing items | Items count $\ge 25$ |
| **TC-PROD-03** | Pagination Control | `GET /products?page=1&limit=5` | Returns exactly 5 products with pagination metadata | Page limit respected |
| **TC-PROD-04** | Category Filtering | `GET /products?category=clothing` | Returns only items matching category `clothing` | Zero category cross-leakage |

#### 4. Order Management Service (`orders` - Port 3005)
| Test ID | Test Scenario | Input / Action | Expected Result | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-ORD-01** | Liveness Probe | `GET /health` | HTTP 200, `{ status: "healthy" }` | Response time < 30ms |
| **TC-ORD-02** | Checkout Price Calculation | `POST /orders` with items: `[{price: 150, quantity: 2}]` | HTTP 201 Created, total verified as `300.00` | Calculation accurate |
| **TC-ORD-03** | Empty Cart Rejection | `POST /orders` with `items: []` | **HTTP 400 Bad Request**, rejects empty order | No DB insertion |

#### 5. Order Legacy Service (`order-service` - Port 3004)
| Test ID | Test Scenario | Input / Action | Expected Result | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-OS-01** | Liveness Probe | `GET /health` | HTTP 200, `{ status: "healthy", service: "order-service" }` | Response time < 30ms |
| **TC-OS-02** | Create Single Order | `POST /orders` with `productId: 1` | HTTP 201 Created, returns order record | Order ID generated |
| **TC-OS-03** | Missing Product ID | `POST /orders` with `{}` | **HTTP 400 Bad Request**, rejects missing field | Error message returned |
| **TC-OS-04** | Product Not Found | `POST /orders` with `productId: 999999` | **HTTP 404 Not Found**, product does not exist | Clean error response |

#### 6. User Profile Service (`user-service` - Port 3006)
| Test ID | Test Scenario | Input / Action | Expected Result | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-USER-01** | Liveness Probe | `GET /health` | HTTP 200, `{ status: "healthy" }` | Response time < 30ms |
| **TC-USER-02** | Unauthorized Access | `GET /profile` with no token | **HTTP 401 Unauthorized** | Access blocked |
| **TC-USER-03** | Authorized Profile Retrieval | `GET /profile` with `Authorization: Bearer <valid_jwt>` | HTTP 200 OK, returns customer profile details | Email matches token claims |

#### 7. Frontend UI Service (`frontend` - Port 3000)
| Test ID | Test Scenario | Input / Action | Expected Result | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-FE-01** | Web Server Liveness | `GET /` | HTTP 200 OK, HTML payload served by Nginx | Response contains `<div id="root">` |
| **TC-FE-02** | API Reverse Proxy | `GET /api/health` | Reverse proxied through Nginx to gateway on port 3001 | HTTP 200 OK |
| **TC-FE-03** | Single Page App Fallback | `GET /products/view/12` | Nginx falls back to `index.html` (SPA routing) | HTTP 200 OK |

#### 8. PostgreSQL Database Service (`database` - Port 5432)
| Test ID | Test Scenario | Input / Action | Expected Result | Pass Criteria |
| :--- | :--- | :--- | :--- | :--- |
| **TC-DB-01** | TCP Connection Ping | `pg_isready -h localhost -p 5432 -U postgres` | Exit code 0, server accepting connections | Connection established |
| **TC-DB-02** | Multi-Database Initialization | Inspect databases list | Databases `auth_db`, `products_db`, `orders_db`, `users_db` exist | 4 core databases verified |
| **TC-DB-03** | Seed Data Integrity | `SELECT count(*) FROM products` | Returns 25 products seeded from `boutique_full.sql` | Count equals 25 |
| **TC-DB-04** | Disaster Recovery Restoration | Re-apply `boutique_full.sql` | Rebuilds tables, sequences, and indexes cleanly | Restoration exit code 0 |

---

### Local Step-by-Step Execution (Linux & Windows)

#### Step 1: Install Docker Engine & Node.js 20

**Linux (Ubuntu / Debian on EC2):**
```bash
# 1. Update system packages
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg

# 2. Add Docker official GPG key and repository
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 3. Install Docker and Compose plugin
sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 4. Allow non-root execution
sudo usermod -aG docker $USER && newgrp docker

# 5. Install Node.js 20 LTS
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 6. CRITICAL FOR EC2 (t2.micro / t3.micro / t3.small): Enable 4GB Swap Memory
# AWS EC2 instances come with 0MB swap by default. React Webpack build requires ~1.5GB RAM.
# Without swap, the Linux kernel OOM-killer abruptly terminates Docker with "exit status 1"!
if [ $(free -m | awk '/^Swap:/ {print $2}') -eq 0 ]; then
    echo "Configuring 4GB Swap Space for EC2..."
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "Swap configured successfully:" && free -h
fi
```

**Windows (PowerShell):**
```powershell
# 1. Update WSL 2
wsl --update
wsl --set-default-version 2

# 2. Install Docker Desktop via Winget (or download from docker.com)
winget install Docker.DockerDesktop

# 3. Install Node.js 20 LTS
winget install OpenJS.NodeJS.LTS
```

---

#### Step 2: Run Microservice Unit Tests Across All Services

Run the automated test runner across all 6 backend services:

**Linux:**
```bash
cd projects/boutique-microservices/backend
npm test
```

**Windows:**
```powershell
cd projects\boutique-microservices\backend
npm test
```

##### Visual Reference (What You Should See - All 18 Tests Passing):
```text
> boutique-backend@1.0.0 test
> node --test services/*/tests/*.test.mjs

TAP version 13
# Subtest: Auth Service Tests
    ok 1 - GET /health returns 200 and healthy status
    ok 2 - POST /register fails with 400 when missing credentials
    ok 3 - Password hashing and verification operates securely
ok 1 - Auth Service Tests
# Subtest: Gateway Service Tests
    ok 1 - GET /health returns 200 and healthy status
    ok 2 - Rate Limiter allows initial requests and blocks 4th request with HTTP 429
    ok 3 - Non-existent route returns 404
ok 2 - Gateway Service Tests
# Subtest: Order Service (Legacy) Tests
    ok 1 - GET /health returns 200 and healthy status
    ok 2 - POST /orders with valid productId creates order
    ok 3 - POST /orders rejects missing productId with 400
    ok 4 - POST /orders returns 404 for non-existent product
ok 3 - Order Service (Legacy) Tests
# Subtest: Orders Service Tests
    ok 1 - GET /health returns 200 and healthy status
    ok 2 - POST /orders computes accurate totals and creates order
    ok 3 - POST /orders rejects empty items array
ok 4 - Orders Service Tests
# Subtest: Product Service Tests
    ok 1 - GET /health returns 200 and healthy status
    ok 2 - GET /products returns product catalog payload
ok 5 - Product Service Tests
# Subtest: User Service Tests
    ok 1 - GET /health returns 200 and healthy status
    ok 2 - GET /profile rejects unauthorized requests without token
    ok 3 - GET /profile returns user profile when bearer token present
ok 6 - User Service Tests
1..6
# tests 18
# suites 6
# pass 18
# fail 0
# cancelled 0
# skipped 0
# todo 0
```
> **Checkpoint**: All 18 tests pass with 0 failures across all 6 suites.

---

#### Step 3: Start the Full Local Stack with Docker Compose

**Linux:**
```bash
cd ../ # Navigate to projects/boutique-microservices
docker compose up -d --build
docker compose ps
```

**Windows:**
```powershell
cd ..\
docker compose up -d --build
docker compose ps
```

##### Visual Reference (All 10 Containers Up & Healthy):
```text
NAME                         IMAGE               COMMAND                  SERVICE             STATUS
boutique-frontend            frontend            "/docker-entrypoint.…"   frontend            Up 3000->80/tcp
boutique-gateway             gateway             "docker-entrypoint.s…"   gateway             Up 0.0.0.0:3001->3001/tcp
boutique-auth                auth                "docker-entrypoint.s…"   auth                Up 0.0.0.0:3002->3002/tcp
boutique-products            product-service     "docker-entrypoint.s…"   product-service     Up 0.0.0.0:3003->3003/tcp
boutique-orders              order-service       "docker-entrypoint.s…"   order-service       Up 0.0.0.0:3004->3004/tcp
boutique-order-management    orders              "docker-entrypoint.s…"   orders              Up 0.0.0.0:3005->3005/tcp
boutique-users               user-service        "docker-entrypoint.s…"   user-service        Up 0.0.0.0:3006->3006/tcp
boutique-postgres            postgres:15-alpine  "docker-entrypoint.s…"   postgres            Up (healthy) 5432/tcp
boutique-prometheus          prom/prometheus     "/bin/prometheus --c…"   prometheus          Up 0.0.0.0:9090->9090/tcp
boutique-grafana             grafana/grafana     "/run.sh"                grafana             Up 0.0.0.0:3007->3000/tcp
```

---

#### Step 4: Run the Automated Local Flow Verification Suite

**Linux:**
```bash
chmod +x ./test-local-flow.sh
./test-local-flow.sh
```

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File .\test-local-flow.ps1
```

##### Visual Reference:
```text
==========================================================
   Boutique Microservices - Local Flow Test Suite
==========================================================

[TEST 1] Testing API Gateway Health Check...
  [PASS] API Gateway is healthy

[TEST 2] Testing Prometheus Metrics...
  [PASS] Prometheus metrics collected successfully

[TEST 3] Testing Rate Limiter (Threshold: 5 req/10s)...
  [PASS] Request 6 correctly rate-limited with HTTP 429 Too Many Requests!

[TEST 4] Testing Product Catalog Retrieval...
  [PASS] Retrieved products from catalog

[TEST 5] Testing User Registration Flow...
  [PASS] Registered test user: user4821@boutique-test.com (HTTP 201)

[TEST 6] Testing Frontend UI...
  [PASS] Frontend UI is serving HTTP 200

==========================================================
   Flow Test Completed: ALL CHECKS PASSED
==========================================================
```

---

## 3. Phase 2: Source Code, Testing & CI/CD Pipeline (Trivy Security)

### Files Involved in Phase 2

```
.github/workflows/
└── ci.yml                         # Production CI pipeline with Trivy FS & Image scans
projects/boutique-microservices/backend/services/*/tests/*.test.mjs # Unit tests
```

* **[`.github/workflows/ci.yml`](file:///c:/Users/U%20SIVA/Downloads/devops-ai-playbook-main/devops-ai-playbook-main/.github/workflows/ci.yml)**: Multi-stage pipeline triggered on `push` and `pull_request` to `main`:
  * **Stage 1 (`test`)**: Executes all 18 microservice unit tests in parallel.
  * **Stage 2 (`security-fs-scan`)**: Executes **Trivy Filesystem Scan** for CVEs and hardcoded secrets.
  * **Stage 3 (`build-scan-and-push`)**: Matrix job building images prefixed with `boutique-*`, running **Trivy Image Scan**, and pushing to Amazon ECR.
  * **Stage 4 (`update-manifests`)**: Updates image tags in `gitops/k8s/` and commits back for ArgoCD GitOps sync.

---

### CI/CD Step-by-Step Execution (Linux & Windows)

#### Step 1: Initialize Git and Push to GitHub

**Linux:**
```bash
git init
git branch -M main
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/devops-ai-playbook.git
git add .
git commit -m "feat: enterprise devops platform with boutique prefixed ecr repos and multi-az support"
git push -u origin main
```

**Windows:**
```powershell
git init
git branch -M main
git remote add origin https://github.com/<YOUR_GITHUB_USERNAME>/devops-ai-playbook.git
git add .
git commit -m "feat: enterprise devops platform with boutique prefixed ecr repos and multi-az support"
git push -u origin main
```

---

### Detailed AWS Credentials & GitHub Secrets Configuration

Before your GitHub Actions pipeline can authenticate to Amazon ECR, you must retrieve your 12-digit **AWS Account ID**, verify your target **AWS Region**, generate programmatic access keys for **`github-actions-ci`** inside AWS IAM, and store them securely in GitHub Secrets.

---

#### 1. How to Find Your 12-Digit AWS Account ID

##### Method A: Via AWS Management Console (GUI)
1. In the top-right corner of the AWS Management Console navigation bar, click on your **account name / username dropdown** (located next to the region selector).
2. The dropdown menu opens showing:
   * **Account ID**: `1234-5678-9012`
3. Click the **copy icon** next to the 12-digit number (it copies to your clipboard as a 12-digit string without hyphens: `123456789012`).

##### Method B: Via Terminal / CLI (Linux on EC2 & Windows)
```bash
aws sts get-caller-identity --query Account --output text
```
* **Expected Output**: `123456789012`

---

#### 2. How to Find Your Target AWS Region

##### Method A: Via AWS Management Console (GUI)
1. Look at the top-right navigation bar of the AWS Console, directly between the global search bar and your account name.
2. It displays a geographic region name (e.g. **N. Virginia**, **Ohio**, **Oregon**).
3. Click the dropdown to view the list of regions with their exact **API Region Code**:
   * `US East (N. Virginia)` $\rightarrow$ **`us-east-1`** (Standard region used for this project)
   * `US East (Ohio)` $\rightarrow$ **`us-east-2`**
   * `US West (Oregon)` $\rightarrow$ **`us-west-2`**
   * `Europe (Ireland)` $\rightarrow$ **`eu-west-1`**
   * `Asia Pacific (Mumbai)` $\rightarrow$ **`ap-south-1`**
4. Always copy the lowercase hyphenated code: **`us-east-1`**.

##### Method B: Via Terminal / CLI
```bash
aws configure get region
```
* If you are running directly on an EC2 instance, you can query instance metadata:
  ```bash
  curl -s http://169.254.169.254/latest/meta-data/placement/region
  ```

---

#### 3. Step-by-Step Inside AWS Console: Creating the Access Key for `github-actions-ci`

Follow every setting, radio button, and checkbox below to generate your keys cleanly:

1. **Navigate to IAM**:
   * In the AWS Console search bar at the very top, type `IAM` and press Enter.
   * In the left-hand navigation menu, click **Users**.
2. **Select the User**:
   * In the user list, click directly on the blue username **`github-actions-ci`**.
3. **Open Security Credentials**:
   * On the user overview page, click the **Security credentials** tab (located next to "Permissions").
4. **Initiate Key Creation**:
   * Scroll down to the **Access keys** section.
   * Click the button labeled **Create access key** on the right side.
5. **Step 1: Access key best practices & alternatives**:
   * AWS presents use case options with radio buttons:
     * [ ] *Command Line Interface (CLI)*
     * [ ] *Local code*
     * [ ] *Application running on an AWS compute service*
     * [x] **Application running outside AWS** $\leftarrow$ **SELECT THIS OPTION** (GitHub Actions is an external automation platform).
     * [ ] *Other*
   * Scroll to the bottom of the page and check the confirmation box:
     * [x] **"I understand the above recommendation and want to proceed to create an access key."**
   * Click the orange **Next** button.
6. **Step 2: Set description tag (Optional)**:
   * In the **Description tag value** text box, enter:  
     `GitHub Actions CI/CD Pipeline for Boutique Microservices`
   * Click the orange **Create access key** button.
7. **Step 3: Retrieve and Save Credentials**:
   * You will now see two crucial values displayed on screen:
     * **Access key**: A 20-character uppercase alphanumeric string starting with `AKIA...` (e.g. `AKIAIOSFODNN7EXAMPLE`).
     * **Secret access key**: A 40-character secret string. Click **Show** or the copy icon next to it (e.g. `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`).
   * **Download the CSV backup**: Click the button **Download .csv file**. Save this file (`github-actions-ci_accessKeys.csv`) securely on your local computer.
   * Click **Done**.
   > [!WARNING]
   > AWS will **never show the Secret Access Key again** after you leave this page. If you lose it, you must delete the key and generate a new one.

---

#### 4. Step-by-Step: Adding Secrets into GitHub Repository

1. Open your web browser and go to your repository on GitHub:  
   `https://github.com/<YOUR_GITHUB_USERNAME>/devops-ai-playbook`
2. Click the **Settings** tab (the gear icon on the far right of the repository navigation bar).
3. In the left-hand menu, scroll down to the **Security** category:
   * Click **Secrets and variables** $\rightarrow$ Click **Actions**.
4. You will see the **Repository secrets** section. Click the green button: **New repository secret**.
5. Add each of the 4 secrets one by one:

##### Secret 1: `AWS_ACCESS_KEY_ID`
* **Name**: `AWS_ACCESS_KEY_ID`
* **Secret**: Paste the 20-character key from AWS starting with `AKIA...`
* Click **Add secret**.

##### Secret 2: `AWS_SECRET_ACCESS_KEY`
* Click **New repository secret**
* **Name**: `AWS_SECRET_ACCESS_KEY`
* **Secret**: Paste the 40-character secret string from AWS
* Click **Add secret**.

##### Secret 3: `AWS_REGION`
* Click **New repository secret**
* **Name**: `AWS_REGION`
* **Secret**: `us-east-1` (or your chosen region code in lowercase)
* Click **Add secret**.

##### Secret 4: `AWS_ACCOUNT_ID`
* Click **New repository secret**
* **Name**: `AWS_ACCOUNT_ID`
* **Secret**: Paste your 12-digit account number (e.g. `123456789012` with no hyphens or spaces)
* Click **Add secret**.

##### Verification in GitHub:
Once completed, your GitHub Secrets page will display:
```text
Repository secrets
AWS_ACCESS_KEY_ID        Updated just now
AWS_ACCOUNT_ID           Updated just now
AWS_REGION               Updated just now
AWS_SECRET_ACCESS_KEY    Updated just now
```
> **Checkpoint**: All 4 secrets are now securely encrypted in GitHub. `.github/workflows/ci.yml` will automatically consume these secrets during subsequent commits.

---

### CI Visual Reference & Checkpoints

##### GitHub Actions Pipeline View:
```text
Boutique CI Pipeline #14
├── [✓] Run Unit Tests (18 passed across 6 suites) ............ 48s
├── [✓] Trivy Filesystem Scan (0 Critical Vulnerabilities) .... 1m 08s
├── [✓] Build, Scan & Push (7 parallel matrix jobs) ........... 3m 22s
│   ├── [✓] boutique-auth (Trivy Scan: Clean)
│   ├── [✓] boutique-gateway (Trivy Scan: Clean)
│   ├── [✓] boutique-product-service (Trivy Scan: Clean)
│   ├── [✓] boutique-orders (Trivy Scan: Clean)
│   ├── [✓] boutique-order-service (Trivy Scan: Clean)
│   ├── [✓] boutique-user-service (Trivy Scan: Clean)
│   └── [✓] boutique-frontend (Trivy Scan: Clean)
└── [✓] GitOps Sync (Updated boutique-* image tags in k8s) .... 20s
Status: All checks have passed
```

##### Trivy Security Scan Output in CI Logs:
```text
2026-10-25T05:30:12Z INFO Number of language-specific files: 8
2026-10-25T05:30:12Z INFO Detecting vulnerabilities...
+------------------+------------------+----------+-------------------+---------------+
|     LIBRARY      |  VULNERABILITY   | SEVERITY | INSTALLED VERSION | FIXED VERSION |
+------------------+------------------+----------+-------------------+---------------+
| Total: 0 vulnerabilities found (CRITICAL: 0, HIGH: 0)                             |
+------------------+------------------+----------+-------------------+---------------+
```

---

## 4. Phase 3: AWS Infrastructure & Enterprise IAM Setup (Company Standard)

### Files Involved in Phase 3

```
projects/Infrastructure/
├── provider.tf                    # AWS provider & remote S3 backend with DynamoDB lock
├── main.tf                        # Root orchestrator: VPC, EKS, ECR, ArgoCD Helm
├── variables.tf                   # Parameter declarations
├── terraform.tfvars               # Production configuration with boutique-* repositories
└── modules/
    ├── vpc/                       # Multi-subnet VPC module
    ├── eks/                       # EKS cluster, managed node group & EBS CSI driver
    └── ecr/                       # 7 private ECR repositories prefixed with boutique-*
```

---

### Enterprise IAM Governance: DevOpsEngineers & CICDAutomation Groups

In real IT enterprises, nobody uses root AWS accounts or attaches wildcard `AdministratorAccess`. Real companies organize IAM into **User Groups** with **Least-Privilege Custom Policies**:

```
                       ┌────────────────────────────┐
                       │     AWS Account Admin      │
                       └─────────────┬──────────────┘
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         │                                                       │
┌────────▼─────────────────┐                           ┌────────▼─────────────────┐
│ Group: DevOpsEngineers   │                           │ Group: CICDAutomation    │
│ Members: Human Engineers │                           │ Members: github-actions  │
│ Policies:                │                           │ Policies:                │
│ - BoutiqueDevOpsECRPolicy│                           │ - BoutiqueCICDECRPolicy  │
│ - AmazonEKSClusterPolicy │                           │                          │
│ - AmazonVPCFullAccess    │                           │                          │
│ - BoutiqueTerraformPolicy│                           │                          │
└──────────────────────────┘                           └──────────────────────────┘
```

#### Why Repository Names Must Start with the Project Prefix (`boutique-*`)

In enterprise environments, multiple teams (e.g. Payments, Analytics, Boutique) share common AWS accounts. If repos were named generic words like `frontend` or `gateway`:
1. Another project would collide with or overwrite the repository.
2. IAM policies could not isolate permissions per project team.
3. Cost allocation tags and resource filters could not accurately track project spend.

By enforcing the prefix `boutique-*` (e.g. `boutique-frontend`, `boutique-gateway`, `boutique-auth`), IAM policies restrict both developers and automated CI/CD pipelines to touch **only** their project's repositories.

---

### Step 1: Policy Classification & Definitions (Which Ones to Create vs. Attach)

> [!IMPORTANT]
> **DO NOT CREATE AWS MANAGED POLICIES!**  
> Policies starting with `Amazon*` (e.g., `AmazonEKSClusterPolicy`, `AmazonVPCFullAccess`) **already exist** in your AWS account by default. You do **NOT** create them. You only search for them and attach them.  
> Only the custom **Inline Policies** (`Boutique*`) need to be pasted into the groups.

#### Policy Master Classification Matrix

| Policy Name | Target Group | Policy Type | Do I Need to Create It? | Exact Action |
| :--- | :--- | :--- | :---: | :--- |
| **`AmazonEKSClusterPolicy`** | `DevOpsEngineers` | **AWS Managed Policy** | **NO (DO NOT CREATE)** | Pre-exists in AWS. Just search name & attach to group. |
| **`AmazonVPCFullAccess`** | `DevOpsEngineers` | **AWS Managed Policy** | **NO (DO NOT CREATE)** | Pre-exists in AWS. Just search name & attach to group. |
| **`BoutiqueDevOpsECRPolicy`** | `DevOpsEngineers` | **Inline Policy** (Custom) | **YES (PASTE INTO GROUP)** | Click *Create inline policy* inside the group, paste JSON. |
| **`BoutiqueTerraformBootstrapPolicy`** | `DevOpsEngineers` | **Inline Policy** (Custom) | **YES (PASTE INTO GROUP)** | Click *Create inline policy* inside the group, paste JSON. |
| **`BoutiqueCICDECRPolicy`** | `CICDAutomation` | **Inline Policy** (Custom) | **YES (PASTE INTO GROUP)** | Click *Create inline policy* inside the group, paste JSON. |

---

### A. Pre-Existing Policies (AWS Managed — DO NOT CREATE)

#### 1. `AmazonEKSClusterPolicy`
* **Status**: **ALREADY EXISTS IN AWS (DO NOT CREATE)**
* **Type**: AWS Managed Policy
* **ARN**: `arn:aws:iam::aws:policy/AmazonEKSClusterPolicy`
* **What it does**: Grants the EKS control plane permissions to manage ENIs for pod networking, security groups, cross-cluster communication, and CloudWatch metrics. You will simply search and check this policy when creating the group.

#### 2. `AmazonVPCFullAccess`
* **Status**: **ALREADY EXISTS IN AWS (DO NOT CREATE)**
* **Type**: AWS Managed Policy
* **ARN**: `arn:aws:iam::aws:policy/AmazonVPCFullAccess`
* **What it does**: Allows Terraform to create and manage VPCs, subnets, route tables, Internet Gateways, NAT Gateways, and security groups. You will simply search and check this policy when creating the group.

---

### B. Inline Policies (Custom Project Policies — PASTE DIRECTLY INTO GROUP)

These policies are specific to our Boutique application and repository naming convention (`boutique-*`). You paste them as **Inline Policies** directly inside the respective group's **Permissions** tab:

#### 1. `BoutiqueDevOpsECRPolicy` (Inline Policy for `DevOpsEngineers`)
* **Status**: **INLINE POLICY (PASTE INTO GROUP)**
* **Where to paste**: Group `DevOpsEngineers` → **Permissions** tab → **Add permissions** → **Create inline policy**
* **Purpose**: Grants DevOps engineers permission to create, manage, tag, and configure lifecycle rules strictly on repositories starting with `boutique-*`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowECRAuthToken",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "DevOpsManageBoutiqueReposOnly",
      "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:PutLifecyclePolicy",
        "ecr:GetLifecyclePolicy",
        "ecr:DeleteLifecyclePolicy",
        "ecr:SetRepositoryPolicy",
        "ecr:GetRepositoryPolicy",
        "ecr:TagResource",
        "ecr:UntagResource",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:*:*:repository/boutique-*"
    }
  ]
}
```

---

#### 2. `BoutiqueTerraformBootstrapPolicy` (Inline Policy for `DevOpsEngineers`)
* **Status**: **INLINE POLICY (PASTE INTO GROUP)**
* **Where to paste**: Group `DevOpsEngineers` → **Permissions** tab → **Add permissions** → **Create inline policy**
* **Purpose**: Grants engineers permission to read/write remote state in S3 (`boutique-terraform-state-*`), manage distributed locks in DynamoDB (`boutique-terraform-locks`), and pass IAM roles to EKS:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformRemoteStateS3",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::boutique-terraform-state-*",
        "arn:aws:s3:::boutique-terraform-state-*/*"
      ]
    },
    {
      "Sid": "TerraformStateLockingDynamoDB",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/boutique-terraform-locks"
    },
    {
      "Sid": "AllowIAMPassRoleToEKS",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole",
        "iam:GetRole",
        "iam:ListAttachedRolePolicies"
      ],
      "Resource": [
        "arn:aws:iam::*:role/*eks*",
        "arn:aws:iam::*:role/*cluster*",
        "arn:aws:iam::*:role/*node*"
      ]
    }
  ]
}
```

---

#### 3. `BoutiqueCICDECRPolicy` (Inline Policy for `CICDAutomation`)
* **Status**: **INLINE POLICY (PASTE INTO GROUP)**
* **Where to paste**: Group `CICDAutomation` → **Permissions** tab → **Add permissions** → **Create inline policy**
* **Purpose**: Restricts GitHub Actions strictly to push/pull Docker images for `boutique-*` repositories without repository deletion or cluster alteration privileges:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowECRAuthToken",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "ECRPushPullBoutiqueRepositoriesOnly",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeImages"
      ],
      "Resource": "arn:aws:ecr:*:*:repository/boutique-*"
    }
  ]
}
```

---

### Step 2: Create Groups and Attach Policies (AWS CLI & Console)

#### Method A: AWS CLI (Linux EC2 & Windows PowerShell)

**Linux:**
```bash
# -------------------------------------------------------------
# 1. Create DevOpsEngineers Group & Attach Policies
# -------------------------------------------------------------
aws iam create-group --group-name DevOpsEngineers

# Attach Custom Boutique ECR Policy
aws iam put-group-policy \
  --group-name DevOpsEngineers \
  --policy-name BoutiqueDevOpsECRPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      { "Effect": "Allow", "Action": "ecr:GetAuthorizationToken", "Resource": "*" },
      { "Effect": "Allow", "Action": "ecr:*", "Resource": "arn:aws:ecr:*:*:repository/boutique-*" }
    ]
  }'

# Attach Custom Terraform Bootstrap Policy (S3 & DynamoDB state)
aws iam put-group-policy \
  --group-name DevOpsEngineers \
  --policy-name BoutiqueTerraformBootstrapPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      { "Effect": "Allow", "Action": "s3:*", "Resource": ["arn:aws:s3:::boutique-terraform-state-*", "arn:aws:s3:::boutique-terraform-state-*/*"] },
      { "Effect": "Allow", "Action": "dynamodb:*", "Resource": "arn:aws:dynamodb:*:*:table/boutique-terraform-locks" },
      { "Effect": "Allow", "Action": "iam:PassRole", "Resource": "*" }
    ]
  }'

# Attach AWS Managed Policies
aws iam attach-group-policy --group-name DevOpsEngineers --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam attach-group-policy --group-name DevOpsEngineers --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess

# -------------------------------------------------------------
# 2. Create CICDAutomation Group & Attach Policy
# -------------------------------------------------------------
aws iam create-group --group-name CICDAutomation

# Attach Custom CI/CD Push Policy
aws iam put-group-policy \
  --group-name CICDAutomation \
  --policy-name BoutiqueCICDECRPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      { "Effect": "Allow", "Action": "ecr:GetAuthorizationToken", "Resource": "*" },
      {
        "Effect": "Allow",
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages"
        ],
        "Resource": "arn:aws:ecr:*:*:repository/boutique-*"
      }
    ]
  }'
```

**Windows (PowerShell):**
```powershell
# 1. Create Groups
aws iam create-group --group-name DevOpsEngineers
aws iam create-group --group-name CICDAutomation

# 2. Attach Managed Policies to DevOpsEngineers
aws iam attach-group-policy --group-name DevOpsEngineers --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam attach-group-policy --group-name DevOpsEngineers --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess
```

---

#### Method B: AWS Management Console (GUI Steps)

1. Open **AWS Management Console** → Search for **IAM**.
2. Click **User groups** in the left sidebar → Click **Create group**.
   * Group 1: Name it `DevOpsEngineers`.
     * Under **Attach permissions policies**, search for and check:
       * `AmazonEKSClusterPolicy`
       * `AmazonVPCFullAccess`
     * Click **Create group**.
     * Once created, click on `DevOpsEngineers` → Go to **Permissions** tab → Click **Add permissions** → **Create inline policy** → Paste the `BoutiqueDevOpsECRPolicy` JSON above → Name it `BoutiqueDevOpsECRPolicy` → Save.
   * Group 2: Name it `CICDAutomation`.
     * Click **Create group**.
     * Click on `CICDAutomation` → **Permissions** tab → **Add permissions** → **Create inline policy** → Paste the `BoutiqueCICDECRPolicy` JSON above → Name it `BoutiqueCICDECRPolicy` → Save.

---

### Step 3: Create Users and Add Them to Groups

#### User 1: Human DevOps Engineer (`siva-devops`)
Human engineers need programmatic access for the EC2 terminal and optional console access:

**Linux:**
```bash
# 1. Create the user
aws iam create-user --user-name siva-devops

# 2. Add user to the DevOpsEngineers group
aws iam add-user-to-group --user-name siva-devops --group-name DevOpsEngineers

# 3. Generate Access Key and Secret Key for CLI use
aws iam create-access-key --user-name siva-devops
```

**Windows (PowerShell):**
```powershell
aws iam create-user --user-name siva-devops
aws iam add-user-to-group --user-name siva-devops --group-name DevOpsEngineers
aws iam create-access-key --user-name siva-devops
```

##### Visual Reference (Output with Credentials):
```json
{
    "AccessKey": {
        "UserName": "siva-devops",
        "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
        "Status": "Active",
        "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        "CreateDate": "2026-10-25T07:15:20Z"
    }
}
```
> [!IMPORTANT]
> Save the `AccessKeyId` and `SecretAccessKey` immediately. AWS will never show the secret key again.

---

#### User 2: CI/CD Machine User (`github-actions-ci`)
Machine users should **never** have AWS Console passwords or MFA. They only receive programmatic access keys:

**Linux & Windows:**
```bash
# 1. Create machine user
aws iam create-user --user-name github-actions-ci

# 2. Add machine user to CICDAutomation group
aws iam add-user-to-group --user-name github-actions-ci --group-name CICDAutomation

# 3. Generate Access Key for GitHub Actions
aws iam create-access-key --user-name github-actions-ci
```

---

### Step 4: How to Use These Users in This Project (Practical Application)

Now that users, groups, and policies are active, here is how each one is used in the day-to-day workflow:

#### A. How the Human Engineer (`siva-devops`) Uses Their Credentials

When you log into your EC2 Linux instance or local workstation to deploy infrastructure:

1. **Configure Your AWS CLI**:
   ```bash
   aws configure
   # AWS Access Key ID: AKIAIOSFODNN7EXAMPLE (siva-devops access key)
   # AWS Secret Access Key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
   # Default region name: us-east-1
   # Default output format: json
   ```

2. **Verify That You Are Acting as `siva-devops`**:
   ```bash
   aws sts get-caller-identity
   ```
   * Output will show: `"Arn": "arn:aws:iam::123456789012:user/siva-devops"`

3. **Deploy the Infrastructure via Terraform**:
   Because `siva-devops` belongs to `DevOpsEngineers`, they have permission to create the VPC, subnets, EKS cluster, and `boutique-*` ECR repositories:
   ```bash
   cd projects/Infrastructure
   terraform init -backend-config="bucket=boutique-terraform-state-$(aws sts get-caller-identity --query Account --output text)"
   terraform apply tfplan
   ```

4. **Connect kubectl to the EKS Cluster**:
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name eks-cluster
   kubectl get nodes
   ```

---

#### B. How the Machine User (`github-actions-ci`) Uses Their Credentials in GitHub Actions

The machine user powers automated builds, Trivy security scans, and image pushes without any human manual intervention:

1. **Add Credentials into GitHub Secrets**:
   * Go to your repository on GitHub: **Settings → Secrets and variables → Actions → New repository secret**.
   * Add the following 4 secrets:
     * `AWS_ACCESS_KEY_ID`: Paste the Access Key ID from `github-actions-ci`.
     * `AWS_SECRET_ACCESS_KEY`: Paste the Secret Access Key from `github-actions-ci`.
     * `AWS_REGION`: `us-east-1`
     * `AWS_ACCOUNT_ID`: Your 12-digit AWS Account ID.

2. **How `.github/workflows/ci.yml` Uses These Secrets**:
   Whenever code is committed to `main`, GitHub Actions automatically:
   * Assumes the identity of `github-actions-ci` via `aws-actions/configure-aws-credentials@v4`.
   * Authenticates with ECR:
     ```bash
     aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
     ```
   * Builds and pushes the 7 Docker images to the `boutique-*` repositories:
     ```bash
     docker tag gateway:${GITHUB_SHA} <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/boutique-gateway:${GITHUB_SHA}
     docker push <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/boutique-gateway:${GITHUB_SHA}
     ```
   * Because `github-actions-ci` has `BoutiqueCICDECRPolicy`, AWS allows the push to `boutique-gateway`, but will reject any attempt to delete repositories or modify other teams' infrastructure!

---

### Terraform Infrastructure Provisioning: Complete Pre-Flight & Execution

As a fresh DevOps engineer, never execute `terraform apply` blindly. Always follow the company standard pre-flight verification sequence.

#### Pre-Flight Step 1: Check if Terraform is Installed

**Linux:**
```bash
# Check if terraform binary exists
if command -v terraform &> /dev/null; then
    echo "[PASS] Terraform is installed: $(terraform -version | head -n 1)"
else
    echo "[WARN] Terraform not found! Installing now..."
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update && sudo apt install -y terraform
fi
```

**Windows:**
```powershell
# Check if terraform is available
if (Get-Command terraform -ErrorAction SilentlyContinue) {
    Write-Host "[PASS] Terraform is installed: $(terraform -version | Select-Object -First 1)" -ForegroundColor Green
} else {
    Write-Host "[WARN] Installing Terraform via winget..." -ForegroundColor Yellow
    winget install Hashicorp.Terraform
}
```

---

#### Pre-Flight Step 2: Check AWS Account Identity & Active Credentials

Run `aws sts get-caller-identity` to ensure you are connected to the correct AWS account and not executing commands against personal or wrong production accounts:

**Linux:**
```bash
aws sts get-caller-identity
```

**Windows:**
```powershell
aws sts get-caller-identity
```

##### Visual Reference (What You Should See):
```json
{
    "UserId": "AIDASAMPLEUSERIDEXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/devops-engineer"
}
```
> **Checkpoint**: Verify that the 12-digit `Account` matches your assigned AWS Account ID.

---

#### Pre-Flight Step 3: Check Active Region and Configuration

**Linux:**
```bash
aws configure get region
```

**Windows:**
```powershell
aws configure get region
```
* **Expected Output**: `us-east-1` (or your target region).

---

### Storing Infrastructure State Remotely (Amazon S3 Backend - Free Tier Standard)

In real IT companies, storing `terraform.tfstate` on a local laptop or EC2 disk is strictly prohibited. If an EC2 instance is terminated or a disk fails, all infrastructure tracking is lost forever.

By storing the state file in **Amazon S3**:
1. **Durability & Safety**: Your infrastructure state is safely backed up in S3 (99.999999999% durability).
2. **Version History**: With S3 Bucket Versioning enabled, every `terraform apply` creates a new version. You can roll back if a bad apply ever damages the state.
3. **100% Free Tier ($0.00)**: S3 offers 5 GB of standard storage in the AWS Free Tier, and a state file is typically only 50 KB–200 KB.
4. **Why Not DynamoDB?**: DynamoDB is only used in large corporate teams for distributed concurrency locks (preventing two engineers from running `terraform apply` at the exact same second). For solo DevOps engineers, staging environments, and Free Tier setups, **S3 alone is 100% sufficient and stores all state data without any DynamoDB table needed**.

#### Step 1: Bootstrap the Remote State S3 Bucket (S3 Only)

**Linux (Ubuntu EC2 / Amazon Linux):**
```bash
# 1. Fetch your AWS Account ID dynamically
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
BUCKET_NAME="boutique-terraform-state-${ACCOUNT_ID}"

echo "Creating S3 State Bucket: $BUCKET_NAME in $REGION..."
aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"

# Enable S3 Bucket Versioning (Preserves state history and rollback capability)
aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled

# Enable S3 Server-Side Encryption (AES256) at $0 cost
aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration '{
  "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" } }]
}'

# Verify bucket exists and is ready
aws s3 ls "s3://${BUCKET_NAME}"
```

**Windows (PowerShell):**
```powershell
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$REGION = "us-east-1"
$BUCKET_NAME = "boutique-terraform-state-$ACCOUNT_ID"

aws s3api create-bucket --bucket $BUCKET_NAME --region $REGION
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket $BUCKET_NAME --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3 ls "s3://$BUCKET_NAME"
```

---

#### Step 2: Initialize, Validate, and Apply Terraform

Navigate to the infrastructure directory:

**Linux:**
```bash
cd projects/Infrastructure

# 1. Initialize Terraform with the Remote S3 Backend
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
terraform init -backend-config="bucket=boutique-terraform-state-${ACCOUNT_ID}"

# 2. Format check and syntax validation
terraform fmt -check
terraform validate

# 3. Generate and inspect execution plan
terraform plan -out=tfplan

# 4. Apply the approved infrastructure plan
terraform apply tfplan
```

**Windows:**
```powershell
cd projects\Infrastructure

$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
terraform init -backend-config="bucket=boutique-terraform-state-$ACCOUNT_ID"
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```
*(Takes approximately 12–15 minutes to provision the VPC, EKS Control Plane, Node Group, and 7 ECR Repositories).*

---

### Post-Provisioning Verification Commands

After `terraform apply` finishes, run these commands to verify that all AWS infrastructure was created successfully:

#### 1. Verify EKS Cluster Status
**Linux & Windows:**
```bash
aws eks describe-cluster --name eks-cluster --region us-east-1 --query "cluster.status" --output text
```
* **Expected Output**: `ACTIVE`

#### 2. Verify Managed Node Group Status
**Linux & Windows:**
```bash
aws eks describe-nodegroup --cluster-name eks-cluster --nodegroup-name eks-node-group --region us-east-1 --query "nodegroup.status" --output text
```
* **Expected Output**: `ACTIVE`

#### 3. Verify ECR Repositories Created with `boutique-*` Prefix
**Linux & Windows:**
```bash
aws ecr describe-repositories --region us-east-1 --query "repositories[?starts_with(repositoryName, 'boutique-')].repositoryName" --output table
```
##### Visual Reference:
```text
--------------------------------
|      DescribeRepositories     |
+-------------------------------+
|  boutique-auth                |
|  boutique-frontend            |
|  boutique-gateway             |
|  boutique-order-service       |
|  boutique-orders              |
|  boutique-product-service     |
|  boutique-user-service        |
+-------------------------------+
```

---

### Deep-Dive Technical Breakdown: Understanding the Core Cluster Commands

As a fresh DevOps engineer, you will use these two commands daily. Here is what they actually do under the hood:

#### Command 1: `aws eks update-kubeconfig --region us-east-1 --name eks-cluster`

```bash
aws eks update-kubeconfig --region us-east-1 --name eks-cluster
```

##### What this command does:
1. **Queries the AWS EKS API**: Contacts the AWS EKS control plane service in region `us-east-1` and downloads:
   - The cluster's unique HTTPS API Server Endpoint (e.g. `https://ABC123XYZ.yl4.us-east-1.eks.amazonaws.com`).
   - The Certificate Authority data (`certificate-authority-data`) required to trust the cluster's TLS certificate.
2. **Modifies Local `~/.kube/config`**: Automatically merges cluster connection details into your local configuration file (`$HOME/.kube/config` on Linux, `C:\Users\<user>\.kube\config` on Windows).
3. **Injects the AWS IAM Authenticator Exec Plugin**: Instead of storing static passwords or insecure tokens, it configures `kubectl` to call `aws eks get-token` automatically every time a command runs. This generates a temporary, short-lived (15-minute) pre-signed STS URL bearer token.
4. **Sets the Active Context**: Switches your current Kubernetes context to `arn:aws:eks:us-east-1:123456789012:cluster/eks-cluster`.

##### Output Explanation:
```text
Added new context arn:aws:eks:us-east-1:123456789012:cluster/eks-cluster to /home/ubuntu/.kube/config
```

---

#### Command 2: `kubectl get nodes`

```bash
kubectl get nodes
```

##### What this command does:
1. **Reads Context & Identity**: Reads the API endpoint and generates an IAM STS authentication token via the exec plugin configured in Step 1.
2. **Contacts the Kubernetes API Server**: Sends an HTTPS `GET /api/v1/nodes` request to the EKS control plane on port 443.
3. **IAM to RBAC Translation**: The EKS API Server validates the AWS IAM identity against the Kubernetes `aws-auth` ConfigMap or EKS Access Entries. If authorized, it queries the cluster state stored in `etcd`.
4. **Inspects Kubelet Heartbeats**: Retrieves the status of all registered worker nodes. Every worker node runs a background agent called **kubelet** that continuously sends heartbeats reporting CPU, memory, container runtime, and network readiness.

##### Output Explanation:
```text
NAME                                STATUS   ROLES    AGE   VERSION
ip-10-1-1-142.ec2.internal          Ready    <none>   14m   v1.31.2-eks
ip-10-1-2-88.ec2.internal           Ready    <none>   14m   v1.31.2-eks
```
* `NAME`: Internal DNS private hostname of the EC2 worker node within the VPC.
* `STATUS Ready`: Kubelet is running, container runtime (`containerd`) is operational, and the AWS VPC CNI plugin has successfully allocated internal IPs.
* *(If status is `NotReady`, the node has booted but the VPC CNI network plugin has not yet finished initializing. Wait 60 seconds).*

---

## 5. Phase 4: Kubernetes Deployment, GitOps (ArgoCD) & Single EBS Storage

### Files Involved in Phase 4

```
gitops/
├── argo-cd.yml                     # ArgoCD Application declaration watching git repository
├── kustomization.yml               # Kustomize root manifest
├── namespace.yml                   # boutique namespace declaration
├── secrets.yml                     # DB credentials Secret
└── k8s/
    ├── database/
    │   ├── statefulset.yml         # PostgreSQL StatefulSet on Single 10 GiB EBS Volume
    │   ├── service.yml             # Headless Postgres service
    │   ├── backup-cronjob.yml      # Scheduled automated database backup CronJob
    │   └── automated-recovery.sh   # One-command disaster recovery script
    ├── backend/*.yml               # 6 backend Deployment & Service manifests (HA, probes)
    ├── frontend/deployment.yml     # Nginx React frontend Deployment & Service
    ├── hpa.yml                     # Horizontal Pod Autoscalers (2 to 10 replicas)
    ├── pdb.yml                     # PodDisruptionBudgets (Zero downtime)
    └── ingress.yml                 # AWS ALB Ingress with TLS redirection
```

---

### Single EBS Volume Storage Configuration

In [`gitops/k8s/database/statefulset.yml`](file:///c:/Users/U%20SIVA/Downloads/devops-ai-playbook-main/devops-ai-playbook-main/gitops/k8s/database/statefulset.yml):

```yaml
  volumeClaimTemplates:
    - metadata:
        name: postgres-data
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: gp2
        resources:
          requests:
            storage: 10Gi
```

* **Why Single EBS**: Free Tier accounts include **30 GB of EBS gp2/gp3** per month. Requesting **10 GiB** leaves 20 GiB of free safety margin for backups and node boot volumes, guaranteeing zero storage charges.
* **Volume Attachment**: The AWS EBS CSI driver automatically binds an Amazon EBS block volume to pod `boutique-postgres-0` in `us-east-1a`. If the pod restarts or is rescheduled, Kubernetes automatically re-attaches the same EBS block volume without data loss.

---

### ArgoCD Deployment & Synchronization (Linux & Windows)

Register the Git repository with ArgoCD:

**Linux:**
```bash
kubectl apply -f gitops/argo-cd.yml -n argocd
kubectl get application -n argocd
```

**Windows:**
```powershell
kubectl apply -f gitops\argo-cd.yml -n argocd
kubectl get application -n argocd
```

##### Visual Reference (ArgoCD Synchronization):
```text
NAME       SYNC STATUS   HEALTH STATUS   REVISION
boutique   Synced        Healthy         9b8e1f0
```

Verify that all pods in the `boutique` namespace are running:
```bash
kubectl get pods -n boutique
```

##### Visual Reference (All Pods Running):
```text
NAME                               READY   STATUS    RESTARTS   AGE
auth-789cf6d7b-k98xz               1/1     Running   0          4m
auth-789cf6d7b-p23lm               1/1     Running   0          4m
boutique-postgres-0                1/1     Running   0          5m
frontend-54bfcd9c9b-a78bx          1/1     Running   0          4m
frontend-54bfcd9c9b-r65tz          1/1     Running   0          4m
gateway-65ddbc8774-j12kl           1/1     Running   0          4m
gateway-65ddbc8774-w89px           1/1     Running   0          4m
orders-89c56bd84-m44lp             1/1     Running   0          4m
orders-89c56bd84-x11qa             1/1     Running   0          4m
order-service-6789fcdb-a11bc       1/1     Running   0          4m
product-service-6d8b9fc964-b52kp   1/1     Running   0          4m
product-service-6d8b9fc964-f98rt   1/1     Running   0          4m
user-service-7589d7cb89-c89za      1/1     Running   0          4m
user-service-7589d7cb89-n14we      1/1     Running   0          4m
```

---

## 6. Phase 5: Enterprise Observability & Monitoring (Prometheus & Grafana)

### Files Involved in Phase 5

```
gitops/k8s/
├── grafana-dashboard.yml           # ConfigMap provisioning 5 production Grafana dashboards
├── alerts-prometheus-rule.yml      # Alerting rules for disk, 5xx rate, table drops & crashlooping
└── alertmanager-config.yml         # Routing alerts to Email and Slack via SMTP/SES
```

---

### How to Log into Prometheus, Grafana & Alertmanager (Local & Production EKS)

#### Environment 1: Local Docker Compose

| Service | Browser URL | Default Username | Default Password | What it does |
| :--- | :--- | :--- | :--- | :--- |
| **Prometheus** | `http://localhost:9090` | *None (No login)* | *None* | Scrapes and stores metrics from all services |
| **Grafana** | `http://localhost:3007` | `admin` | `admin` | Visualizes metrics across 5 enterprise dashboards |

---

#### Environment 2: Production AWS EKS

In production, Prometheus and Grafana run inside private Kubernetes subnets. You access them securely via `kubectl port-forward`:

#### Step 1: Retrieve the Grafana Administrator Password

**Linux:**
```bash
kubectl get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
echo ""
```

**Windows (PowerShell):**
```powershell
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}")))
```
* **Username**: `admin`
* **Password**: The decoded string printed from the command above.

---

#### Step 2: Port-Forward Grafana

**Linux & Windows:**
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
```
* **URL**: Open `http://localhost:3000` in your web browser.
* Log in with username `admin` and the password retrieved in Step 1.

---

#### Step 3: Port-Forward Prometheus

**Linux & Windows:**
```bash
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring
```
* **URL**: Open `http://localhost:9090` in your web browser.

---

#### Step 4: Port-Forward Alertmanager

**Linux & Windows:**
```bash
kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring
```
* **URL**: Open `http://localhost:9093` in your web browser.

---

### What to Check and Observe in Prometheus

When you open Prometheus (`http://localhost:9090`):

1. **Status → Targets (`/targets`)**:
   - Check that all targets report **UP (1/1)** in green.
   - Look for: `boutique/gateway`, `boutique/auth`, `boutique/product-service`, `boutique/orders`, `boutique/user-service`, `node-exporter`, and `kubelet`.
   - If any target is `DOWN (0/1)`, click on it to inspect the connection error or verify that the pod's port and path (`/metrics`) are accessible.

2. **Alerts Tab (`/alerts`)**:
   - Displays all defined alerting rules from `gitops/k8s/alerts-prometheus-rule.yml`.
   - Statuses:
     - **Green (Inactive)**: Normal state. Everything is operating within SLO boundaries.
     - **Yellow (Pending)**: Threshold exceeded (e.g. error rate > 5%), waiting for the `for: 1m` duration to elapse before sending an alert.
     - **Red (Firing)**: Threshold exceeded for the full duration. Alertmanager is actively dispatching email notifications!

3. **Graph / Query Console**:
   - Run sample queries:
     - Microservice traffic rate: `sum(rate(http_requests_total[2m])) by (job)`
     - Pod memory usage: `sum(container_memory_working_set_bytes{namespace="boutique"}) by (pod)`
     - Single EBS free space %: `(node_filesystem_avail_bytes{mountpoint="/var/lib/postgresql/data"} / node_filesystem_size_bytes{mountpoint="/var/lib/postgresql/data"}) * 100`

---

### The 5 Real IT Enterprise Dashboards in Grafana

When you log into Grafana (`http://localhost:3000` or `http://localhost:3007`), navigate to: **Dashboards → Boutique Production Dashboards**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       ENTERPRISE GRAFANA DASHBOARDS                         │
├─────────────────────────┬─────────────────────────┬─────────────────────────┤
│ 1. SRE Golden Signals   │ 2. K8s & Free Tier EBS  │ 3. App Microservices    │
│ • Latency p95/p99 (ms)  │ • Node CPU / Memory %   │ • Node.js Event Loop Lag│
│ • Request Rate (RPS)    │ • Single EBS Disk Usage%│ • V8 Heap Memory (MB)   │
│ • 5xx Error Rate (%)    │ • Pod Restart Counts    │ • Active HTTP In-Flight │
├─────────────────────────┼─────────────────────────┴─────────────────────────┤
│ 4. PostgreSQL Database  │ 5. Cloud Cost Management                          │
│ • Active Connections    │ • Estimated AWS Monthly Burn                      │
│ • Cache Hit Ratio (%)   │ • Free Tier Storage Quota (15/30 GB)              │
│ • Query Duration (ms)   │ • Instance Hours Consumed                         │
└─────────────────────────┴───────────────────────────────────────────────────┘
```

#### What to Observe in Each Dashboard:

1. **Dashboard 1: SRE Golden Signals (Traffic, Latency, Errors, Saturation)**
   - **p95 Latency Panel**: Should remain < 200ms. If it spikes above 500ms, downstream microservices or DB locks are causing latency.
   - **5xx Error Rate**: Target is **0%**. Any sustained rate > 1% indicates unhandled backend exceptions.
   - **Throughput (RPS)**: Displays inbound requests per second across the API Gateway.

2. **Dashboard 2: Kubernetes Infrastructure & Single EBS Storage**
   - **Single EBS Disk Utilization Gauge**: Displays free vs used space on the 10 GiB volume.
     - **Green**: < 70% capacity used.
     - **Yellow**: 70%–85% capacity used (Early warning).
     - **Red**: > 85% capacity used (Critical alert: vacuum dead tuples or expand volume immediately).
   - **Node CPU & Memory Utilization**: Verifies nodes stay under 80% to avoid eviction.

3. **Dashboard 3: Application Runtime Performance**
   - **Node.js Event Loop Lag**: Should be < 20ms. If high, synchronous CPU-blocking code is running in Node.js.
   - **V8 Heap Memory**: Monitored to detect memory leaks before containers hit cgroup limits.

4. **Dashboard 4: PostgreSQL Database Performance**
   - **Active Connections**: Alert threshold is 80 connections.
   - **Buffer Cache Hit Ratio**: Must remain $> 99\%$.

5. **Dashboard 5: Cloud Cost Management & Free Tier Tracking**
   - Tracks monthly EC2 hours, EBS allocations (15/30 GB quota), and S3 lifecycle expirations.

---

### Notification Configuration & How to Change It (Email / SES / SMTP)

All notification routes are defined in [`gitops/k8s/alertmanager-config.yml`](file:///c:/Users/U%20SIVA/Downloads/devops-ai-playbook-main/devops-ai-playbook-main/gitops/k8s/alertmanager-config.yml).

#### How to Configure Your Email Credentials (Amazon SES or Gmail):

1. **Create the SMTP Password Kubernetes Secret**:

**Linux:**
```bash
kubectl create secret generic alertmanager-smtp-secret \
    --namespace monitoring \
    --from-literal=password='YOUR_SMTP_OR_GMAIL_APP_PASSWORD' \
    --dry-run=client -o yaml | kubectl apply -f -
```

**Windows (PowerShell):**
```powershell
kubectl create secret generic alertmanager-smtp-secret --namespace monitoring --from-literal=password='YOUR_SMTP_OR_GMAIL_APP_PASSWORD' --dry-run=client -o yaml | kubectl apply -f -
```

2. **Update `gitops/k8s/alertmanager-config.yml`**:
Modify the receiver configuration:
```yaml
    - name: 'Critical-OnCall-Email'
      emailConfigs:
        - to: 'your-email@company.com'
          from: 'alerts@your-verified-domain.com'
          smarthost: 'smtp.gmail.com:587' # Or email-smtp.us-east-1.amazonaws.com:587 for SES
          authUsername: 'your-email@company.com'
          authPassword:
            name: alertmanager-smtp-secret
            key: password
          sendResolved: true  # Sends follow-up email when incident is fixed!
```

3. **Apply the Changes**:
```bash
kubectl apply -f gitops/k8s/alertmanager-config.yml
```

---

### How to Retrieve and Query Microservice & System Logs

When an alert fires or a bug occurs, real DevOps engineers query logs using these methods:

#### 1. In Local Docker Compose:
```bash
# Stream logs for all services in real time
docker compose logs -f

# Stream logs for a specific service (e.g. gateway)
docker compose logs -f gateway

# View the last 50 lines of PostgreSQL logs
docker compose logs --tail=50 postgres
```

#### 2. In Kubernetes (Production EKS):
```bash
# Stream logs from all replicas of the API Gateway
kubectl logs -f deployment/gateway -n boutique --tail=100

# Stream logs from the single EBS PostgreSQL database container
kubectl logs -f boutique-postgres-0 -n boutique --tail=50

# Inspect previous container logs if a pod crashed (OOMKilled or error)
kubectl logs deployment/product-service -n boutique --previous

# Check logs across all pods matching a label
kubectl logs -l app=orders -n boutique --tail=100
```

#### 3. In AWS CloudWatch Logs:
In production, AWS FluentBit routes all container stdout/stderr streams to CloudWatch Log Groups:
* Log Group: `/aws/containerinsights/eks-cluster/application`
* Query in CloudWatch Insights:
  ```sql
  fields @timestamp, @message
  | filter kubernetes.namespace_name = 'boutique'
  | filter @message like /error|fail|exception/
  | sort @timestamp desc
  | limit 50
  ```

---

## 7. Phase 6: Post-Production SRE Operations, Disaster Recovery & Chaos Tests

### What Real IT Companies Continuously Oversee

Site Reliability Engineers (SREs) oversee three operational pillars:
1. **SLO Tracking**: Ensuring 99.9% uptime and < 200ms p95 latency.
2. **Proactive Intervention**: Resolving resource saturation *before* an outage occurs.
3. **Automated Self-Healing**: Designing systems that detect failures and recover automatically.

---

### Proactive Early Alert (Disk Saturation Before Data Loss)

When database disk usage hits 85%, the SRE investigates using these commands:

**Linux & Windows:**
```bash
# 1. Check disk utilization inside the Postgres container
kubectl exec -it boutique-postgres-0 -n boutique -- df -h /var/lib/postgresql/data

# 2. Identify the largest tables in products_db
kubectl exec -it boutique-postgres-0 -n boutique -- psql -U postgres -d products_db -c "
SELECT relname AS table_name, pg_size_pretty(pg_total_relation_size(relid)) AS total_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC LIMIT 5;"

# 3. Clean dead tuples and reclaim disk space
kubectl exec -it boutique-postgres-0 -n boutique -- psql -U postgres -d products_db -c "VACUUM FULL;"
```

---

### Table Deletion Disaster Recovery (Manual & Automated with BEFORE and AFTER Email Alerts)

This test proves your system detects catastrophic data loss, fires an email alert immediately, recovers data from backups, and sends an alert resolved notification.

#### Step 1: Simulate Accidental or Malicious Table Deletion

Drop the core `products` table:
```bash
kubectl exec -it boutique-postgres-0 -n boutique -- psql -U postgres -d products_db -c "DROP TABLE products CASCADE;"
```

Verify that the product catalog is down and returning HTTP 500:
```bash
curl -i http://localhost:3001/api/products
# HTTP/1.1 500 Internal Server Error
# {"error": "relation 'products' does not exist"}
```

---

#### Step 2: Observe the Email Alert BEFORE the Problem is Fixed (FIRING)

1. Within 30 seconds, Prometheus evaluates rule `DatabaseTableMissingOrUnhealthy` in [`gitops/k8s/alerts-prometheus-rule.yml`](file:///c:/Users/U%20SIVA/Downloads/devops-ai-playbook-main/devops-ai-playbook-main/gitops/k8s/alerts-prometheus-rule.yml).
2. The alert shifts from `Pending` to **`Firing`**.
3. Alertmanager immediately dispatches an email to the on-call SRE team:

##### Visual Reference (Alert Email BEFORE Fix - Status: FIRING):
```text
From: alertmanager@yourcompany.com
To: sre-oncall@yourcompany.com
Subject: [FIRING:1] DatabaseTableMissingOrUnhealthy - products_db in boutique

Alert Details:
- Status: FIRING
- Severity: CRITICAL
- Alert Name: DatabaseTableMissingOrUnhealthy
- Namespace: boutique
- Service: product-service
- Summary: Table 'products' or core relational tables in database are missing or returning 500 errors.
- Triggered At: 2026-10-25 05:42:10 UTC
- Action Required: Run disaster recovery restoration immediately.
```

---

#### Step 3: Execute Disaster Recovery

You can perform recovery either **manually** or via **automated self-healing**:

##### Option A: Manual Recovery Workflow
Run the automated disaster recovery script:

**Linux:**
```bash
chmod +x ./gitops/k8s/database/automated-recovery.sh
./gitops/k8s/database/automated-recovery.sh k8s
```

**Windows (PowerShell):**
```powershell
kubectl delete job boutique-db-restore -n boutique --ignore-not-found=true
kubectl apply -f .\gitops\k8s\database\restore-job.yml -n boutique
kubectl wait --for=condition=complete --timeout=120s job/boutique-db-restore -n boutique
kubectl logs -n boutique -l job-name=boutique-db-restore --tail=20
```

##### Option B: Automated Self-Healing (Synthetic Watchdog)
In real IT companies, an automated watchdog Job runs periodically. If `SELECT count(*) FROM products` fails, it automatically applies `restore-job.yml` without human intervention.

##### Visual Reference (Restoration Log):
```text
Restoring dump from boutique_full.sql...
Rebuilding auth_db schema...
Rebuilding products_db schema and inserting 25 products...
Rebuilding orders_db schema...
Database disaster recovery complete in Kubernetes boutique namespace!
```

---

#### Step 4: Verify Data Restoration

Check that all 25 products are restored in PostgreSQL:
```bash
kubectl exec -it boutique-postgres-0 -n boutique -- psql -U postgres -d products_db -c "SELECT count(*) FROM products;"
# Returns: 25
```

Query the API Gateway:
```bash
curl -s http://localhost:3001/api/products | jq .data.products[0].name
# Returns: "Midnight Silk Evening Gown"
```

---

#### Step 5: Observe the Email Alert AFTER the Problem is Fixed (RESOLVED)

Because `sendResolved: true` is configured in [`gitops/k8s/alertmanager-config.yml`](file:///c:/Users/U%20SIVA/Downloads/devops-ai-playbook-main/devops-ai-playbook-main/gitops/k8s/alertmanager-config.yml):
1. Prometheus detects that `/api/products` is returning HTTP 200 with 0 errors.
2. The alert shifts from `Firing` to **`Inactive (Resolved)`**.
3. Alertmanager automatically delivers the follow-up resolution email:

##### Visual Reference (Alert Email AFTER Fix - Status: RESOLVED):
```text
From: alertmanager@yourcompany.com
To: sre-oncall@yourcompany.com
Subject: [RESOLVED] DatabaseTableMissingOrUnhealthy - products_db in boutique

Alert Details:
- Status: RESOLVED
- Severity: CRITICAL
- Alert Name: DatabaseTableMissingOrUnhealthy
- Namespace: boutique
- Resolved At: 2026-10-25 05:45:30 UTC
- Note: Service endpoints have returned to HTTP 200 healthy state. No further action needed.
```

---

### Rate Limiting Chaos Test (HTTP 429)

Verify that the gateway protects downstream microservices during traffic bursts:

**Linux:**
```bash
kubectl run test-burst --rm -i --image=curlimages/curl -- sh -c '
for i in $(seq 1 8); do
  echo -n "Request $i: "
  curl -s -o /dev/null -w "%{http_code}\n" http://gateway.boutique:3001/api/test-ratelimit
done'
```

**Windows:**
```powershell
kubectl run test-burst --rm -i --image=curlimages/curl -- sh -c 'for i in 1 2 3 4 5 6 7 8; do curl -s -o /dev/null -w "Request $i: %{http_code}\n" http://gateway.boutique:3001/api/test-ratelimit; done'
```

##### Visual Reference:
```text
Request 1: 200
Request 2: 200
Request 3: 200
Request 4: 200
Request 5: 200
Request 6: 429  <-- Rate Limit Threshold Reached
Request 7: 429
Request 8: 429
```

---

### CPU High Utilization Stress Test (HPA Auto-scaling)

Validate horizontal autoscaling from 2 to 6+ pods under traffic load:

1. **Launch Load Generator**:
   ```bash
   kubectl run -i --tty load-generator --rm --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://product-service.boutique:3003/products; done"
   ```

2. **Watch HPA Auto-Scale (in a second terminal)**:
   ```bash
   kubectl get hpa product-service-hpa -n boutique -w
   ```

##### Visual Reference (Autoscaling Progression):
```text
NAME                  REFERENCE                    TARGETS   MINPODS   MAXPODS   REPLICAS
product-service-hpa   Deployment/product-service   14%/70%   2         10        2
product-service-hpa   Deployment/product-service   82%/70%   2         10        2
product-service-hpa   Deployment/product-service   120%/70%  2         10        4  <-- Scaled up!
product-service-hpa   Deployment/product-service   95%/70%   2         10        6  <-- Scaled up!
```

---

### Memory Utilization & Cgroup Limit Test

Verify that container memory bounds prevent memory leaks from starving worker nodes:

```bash
kubectl top pods -n boutique
kubectl describe pod -l app=product-service -n boutique | grep -A 4 Limits
```
```text
Limits:
  cpu:     500m
  memory:  512Mi
Requests:
  cpu:     100m
  memory:  128Mi
```
If a pod exceeds `512Mi`, the Linux kernel cgroup terminates the process with `OOMKilled` and Kubernetes restarts it cleanly without affecting the node.

---

## 8. Phase 7: Cloud Cost Management & Safe Teardown

To avoid incurring charges after completing experiments, follow this teardown sequence:

### Safe Teardown Commands

**Linux:**
```bash
# 1. Delete Kubernetes workloads (releases EBS volumes and load balancers)
kubectl delete -k gitops/

# 2. Wait 2 minutes for AWS to release EBS volumes and ALB
sleep 120

# 3. Destroy Terraform infrastructure
cd projects/Infrastructure
terraform destroy --auto-approve
```

**Windows:**
```powershell
# 1. Delete Kubernetes workloads
kubectl delete -k gitops/

# 2. Wait 2 minutes
Start-Sleep -Seconds 120

# 3. Destroy Terraform infrastructure
cd projects\Infrastructure
terraform destroy --auto-approve
```

#### Verify No Lingering Resources Remain in AWS:
```bash
# Check for lingering EBS volumes
aws ec2 describe-volumes --filters Name=status,Values=available --query "Volumes[*].VolumeId"

# Check for lingering NAT Gateways or Elastic IPs
aws ec2 describe-nat-gateways --filter "Name=state,Values=available"
```

---

## 9. Industry Gap Analysis: Additional Topics to Add or Skip

| Advanced DevOps Topic | What It Does | Add to Free Tier? | Recommendation |
| :--- | :--- | :---: | :--- |
| **Service Mesh (Istio / Linkerd)** | Mutual TLS (mTLS) between pods, traffic splitting, and service tracing. | **SKIP** | Exceeds Free Tier: Istio sidecars consume ~50MB RAM per pod, quickly starving single-node clusters. |
| **Distributed Tracing (OpenTelemetry + Jaeger)** | Traces request paths across all microservices with distributed span IDs. | **OPTIONAL** | Valuable for senior portfolio; lightweight agents can run with minimal overhead. |
| **HashiCorp Vault** | Dynamic secrets engine with leasing and auto-rotation. | **SKIP** | Complex to run in Free Tier. Use **External Secrets Operator** with AWS Secrets Manager instead. |
| **Chaos Engineering (Chaos Mesh)** | Injects network latency and kills pods randomly to test self-healing. | **RECOMMENDED** | Safe to run on staging clusters; validates PodDisruptionBudgets and HPA policies. |
| **Kubecost** | Real-time cost allocation and pod-level spend breakdown. | **RECOMMENDED** | Free community edition integrates seamlessly with Prometheus and Grafana. |
