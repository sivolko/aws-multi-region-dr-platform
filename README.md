# 🌍 Multi-Region Disaster Recovery Platform

**Enterprise-grade disaster recovery platform with automated failover, real-time replication, and chaos engineering.** Perfect for maximizing AWS credits while learning production DR strategies!

## 🎯 Project Objectives

- ✅ Deploy production workloads across multiple AWS regions
- ✅ Implement automated disaster recovery with <5min RTO
- ✅ Real-time database and storage replication
- ✅ DNS-based traffic routing and failover
- ✅ Comprehensive monitoring and alerting
- ✅ Chaos engineering and DR testing automation
- ✅ Cost optimization strategies for multi-region deployments

## 🏗️ Architecture Overview

```
                    ┌─────────────────┐
                    │   Route 53      │
                    │  Health Checks  │
                    │   & Failover    │
                    └─────────┬───────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
    ┌─────────────────┐              ┌─────────────────┐
    │  PRIMARY REGION │              │ SECONDARY REGION│
    │   (us-east-1)   │◄────────────►│   (us-west-2)   │
    │                 │              │                 │
    │ ┌─────────────┐ │              │ ┌─────────────┐ │
    │ │     ALB     │ │              │ │     ALB     │ │
    │ └──────┬──────┘ │              │ └──────┬──────┘ │
    │        │        │              │        │        │
    │ ┌──────▼──────┐ │              │ ┌──────▼──────┐ │
    │ │  ECS Cluster│ │              │ │  ECS Cluster│ │
    │ │   (Active)  │ │              │ │  (Standby)  │ │
    │ └──────┬──────┘ │              │ └──────┬──────┘ │
    │        │        │              │        │        │
    │ ┌──────▼──────┐ │   Replication│ ┌──────▼──────┐ │
    │ │ RDS Primary │ ├──────────────┤ │ RDS Replica │ │
    │ │  (MySQL)    │ │              │ │   (MySQL)   │ │
    │ └─────────────┘ │              │ └─────────────┘ │
    │                 │              │                 │
    │ ┌─────────────┐ │   Cross-Reg  │ ┌─────────────┐ │
    │ │ S3 Primary  │ ├──────────────┤ │ S3 Replica  │ │
    │ │  Bucket     │ │  Replication │ │   Bucket    │ │
    │ └─────────────┘ │              │ └─────────────┘ │
    │                 │              │                 │
    │ ┌─────────────┐ │              │ ┌─────────────┐ │
    │ │ CloudWatch  │ │              │ │ CloudWatch  │ │
    │ │ Monitoring  │ │              │ │ Monitoring  │ │
    │ └─────────────┘ │              │ └─────────────┘ │
    └─────────────────┘              └─────────────────┘
            │                                │
            └────────────┬───────────────────┘
                         │
                ┌────────▼────────┐
                │  Lambda Functions│
                │ DR Orchestration │
                │ Chaos Testing    │
                │ Health Monitoring│
                └──────────────────┘
```

## 💰 Cost Breakdown (Expected: $400-550/day)

| Component | Primary Region | Secondary Region | Daily Cost |
|-----------|---------------|------------------|------------|
| **Compute** | | | |
| ECS Fargate (4 vCPU, 8GB) | $3.50/hour | $1.75/hour | $126/day |
| ALB | $0.025/hour | $0.025/hour | $1.20/day |
| **Database** | | | |
| RDS MySQL (db.r5.large) | $0.192/hour | $0.096/hour | $6.91/day |
| RDS Storage (1TB gp3) | $125/month | $62.5/month | $6.25/day |
| **Storage** | | | |
| S3 Standard (100GB) | $2.30/month | $2.30/month | $0.15/day |
| S3 Cross-Region Replication | $0.015/GB | - | $1.50/day |
| **Networking** | | | |
| NAT Gateway | $0.045/hour × 2 | $0.045/hour × 2 | $4.32/day |
| Route 53 Health Checks | $0.50/check × 4 | - | $2.00/day |
| Data Transfer | $50/month | $50/month | $3.33/day |
| **Monitoring** | | | |
| CloudWatch Logs | $20/month | $10/month | $1.00/day |
| SNS/Lambda | $5/month | $5/month | $0.33/day |
| **TOTAL DAILY** | **~$300** | **~$150** | **$450-550** |

## 🌟 Key Features

### ✅ **High Availability & Resilience**
- Multi-AZ deployments in both regions
- Auto-scaling application tier
- Database read replicas with automatic failover
- S3 cross-region replication with versioning

### ✅ **Automated Disaster Recovery**
- Route 53 health checks with DNS failover
- Lambda-powered DR orchestration
- Automated RDS promotion
- Application scaling in DR region

### ✅ **Monitoring & Alerting**
- Real-time health monitoring
- DR process monitoring
- Cost tracking and alerts
- Performance metrics dashboards

### ✅ **Chaos Engineering**
- Automated failure injection
- DR testing schedules
- Recovery time measurement
- Runbook automation

### ✅ **Security & Compliance**
- Encryption at rest and in transit
- VPC isolation in both regions
- IAM least-privilege access
- Audit logging and compliance reporting

## 📁 Project Structure

```
├── terraform/
│   ├── global/                 # Global resources (Route 53, IAM)
│   ├── us-east-1/             # Primary region infrastructure
│   ├── us-west-2/             # Secondary region infrastructure
│   └── modules/               # Reusable Terraform modules
├── applications/
│   ├── web-app/               # Sample web application
│   ├── api-service/           # REST API service
│   └── worker-service/        # Background job processor
├── dr-automation/
│   ├── failover-lambda/       # Automated failover functions
│   ├── health-checks/         # Custom health monitoring
│   └── chaos-engineering/     # Failure injection tools
├── monitoring/
│   ├── cloudwatch-dashboards/ # Custom dashboards
│   ├── alerts/                # CloudWatch alarms
│   └── synthetic-tests/       # Canary monitoring
├── scripts/
│   ├── deploy.sh              # Full deployment automation
│   ├── failover-test.sh       # DR testing automation
│   ├── cleanup.sh             # Resource cleanup
│   └── cost-monitor.sh        # Cost tracking tools
└── docs/
    ├── runbooks/              # DR procedures
    ├── architecture/          # Design documents
    └── troubleshooting/       # Common issues guide
```

## 🚀 Quick Start (15 minutes to deployment!)

### Prerequisites
```bash
# Install required tools
brew install awscli terraform jq
# or
sudo apt-get install awscli terraform jq

# Configure AWS credentials with multi-region access
aws configure
```

### Step 1: Clone and Setup
```bash
git clone https://github.com/sivolko/aws-multi-region-dr-platform.git
cd aws-multi-region-dr-platform
chmod +x setup.sh && ./setup.sh
```

### Step 2: Deploy Infrastructure
```bash
# Deploy global resources first
./scripts/deploy.sh global

# Deploy primary region
./scripts/deploy.sh primary

# Deploy secondary region  
./scripts/deploy.sh secondary

# Or deploy everything at once
./scripts/deploy.sh all
```

### Step 3: Deploy Applications
```bash
# Deploy sample applications to both regions
./scripts/deploy-apps.sh
```

### Step 4: Test Disaster Recovery
```bash
# Run automated DR test
./scripts/failover-test.sh

# Manual failover trigger
./scripts/trigger-failover.sh
```

## 🎓 Learning Outcomes

### **Enterprise Architecture Patterns**
- Multi-region deployment strategies
- Disaster recovery design patterns
- High availability architectures
- Cost optimization techniques

### **DevOps & Automation**
- Infrastructure as Code at scale
- Automated DR orchestration
- Chaos engineering practices
- Monitoring and observability

### **AWS Services Mastery**
- Route 53 advanced routing
- RDS cross-region replication
- S3 cross-region replication
- ECS/Fargate multi-region
- Lambda for automation
- CloudWatch advanced monitoring

### **Business Continuity**
- RTO/RPO calculation and measurement
- DR testing methodologies
- Cost vs. resilience trade-offs
- Compliance and audit requirements

## 🧪 Chaos Engineering Scenarios

The platform includes automated chaos tests:

1. **Primary Region Failure**: Simulate complete region outage
2. **Database Failure**: Test RDS failover scenarios
3. **Network Partitioning**: Simulate connectivity issues
4. **Application Scaling**: Test under high load
5. **Storage Corruption**: S3 disaster recovery
6. **DNS Poisoning**: Route 53 failover testing

## 📊 Monitoring Dashboards

Pre-built CloudWatch dashboards for:
- **Application Health**: Response times, error rates
- **Infrastructure Metrics**: CPU, memory, network
- **DR Readiness**: Replication lag, backup status
- **Cost Analysis**: Resource utilization, spend trends
- **Security Events**: Failed logins, suspicious activity

## 🧹 Cleanup & Cost Control

```bash
# Safe cleanup with confirmation
./scripts/cleanup.sh

# Emergency cleanup (force delete everything)
./scripts/emergency-cleanup.sh

# Cost monitoring during deployment
./scripts/monitor-costs.sh
```

## 🚨 Important Cost Warnings

- **Multi-region = 2x base costs**
- **Data transfer charges apply**
- **Always cleanup when done testing**
- **Monitor costs every few hours**
- **Set up billing alerts before deploying**

---

## 🎯 **Ready to Build Enterprise DR?**

This platform will consume **$400-550 per day** - perfect for maximizing your AWS credits while learning production disaster recovery patterns used by Fortune 500 companies!

```bash
git clone https://github.com/sivolko/aws-multi-region-dr-platform.git
cd aws-multi-region-dr-platform && ./setup.sh && ./scripts/deploy.sh all
```

**Let's build some bulletproof infrastructure!** 🛡️🌍
