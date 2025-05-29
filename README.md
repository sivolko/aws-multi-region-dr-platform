# 🌍 Multi-Region Disaster Recovery Platform

**Enterprise-grade disaster recovery platform with automated failover, real-time replication, and chaos engineering.** Perfect for maximizing AWS credits while learning production DR strategies!

## 🎯 Project Status

### ✅ **Phase 1: COMPLETE & READY TO DEPLOY**
- Global Infrastructure (Route 53, S3, IAM, KMS)
- Automated deployment scripts
- Cost monitoring tools
- DR testing automation
- Sample applications
- Comprehensive documentation

### ⏳ **Phase 2: Regional Infrastructure** 
- ECS clusters with applications
- RDS multi-region setup
- Load balancers and networking
- Advanced monitoring dashboards

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
    │ │  Bucket ✅  │ │  Replication │ │   Bucket ✅ │ │
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
                │ Chaos Testing ✅ │
                │ Health Monitoring│
                └──────────────────┘
```

## 💰 Cost Breakdown (Expected: $450-550/day)

| Component | Primary Region | Secondary Region | Daily Cost |
|-----------|----------------|------------------|------------|
| **Current Phase 1 Resources** | | | |
| S3 Cross-Region Replication | $2.30/month | $2.30/month | $0.15/day |
| Route 53 Health Checks (2x) | $0.50/check × 2 | - | $0.03/day |
| KMS Keys | $1.00/month | - | $0.03/day |
| Lambda Functions | $0.20/1M requests | - | $0.01/day |
| SNS Notifications | $0.50/1M requests | - | $0.01/day |
| **Phase 1 Subtotal** | | | **~$0.25/day** |
| | | | |
| **Phase 2 Resources (When Added)** | | | |
| ECS Fargate (4 vCPU, 8GB) | $3.50/hour | $1.75/hour | $126/day |
| ALB | $0.025/hour | $0.025/hour | $1.20/day |
| RDS MySQL (db.r5.large) | $0.192/hour | $0.096/hour | $6.91/day |
| RDS Storage (1TB gp3) | $125/month | $62.5/month | $6.25/day |
| NAT Gateway | $0.045/hour × 2 | $0.045/hour × 2 | $4.32/day |
| Data Transfer | $50/month | $50/month | $3.33/day |
| CloudWatch Logs | $20/month | $10/month | $1.00/day |
| **Phase 2 Subtotal** | | | **~$450/day** |
| | | | |
| **TOTAL WHEN COMPLETE** | **~$300** | **~$150** | **$450-550/day** |

## 🚀 Quick Start (5 minutes to deployment!)

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

### Step 2: Configure (Optional)
```bash
# Edit terraform/global/terraform.tfvars to set your email for alerts
# Default configuration works fine for testing!
```

### Step 3: Deploy Phase 1
```bash
# Deploy global infrastructure (Route 53, S3, IAM, KMS)
./scripts/deploy.sh global
```

### Step 4: Test Your Deployment
```bash
# Run comprehensive DR tests
./scripts/failover-test.sh all

# Monitor costs
./scripts/monitor-costs.sh

# Check infrastructure status
terraform -chdir=terraform/global output
```

## 📁 Complete Project Structure

```
├── terraform/                   ✅ Complete Infrastructure as Code
│   ├── global/                 ✅ Global resources (Route 53, S3, IAM, KMS)
│   │   ├── main.tf             ✅ Provider configuration
│   │   ├── variables.tf        ✅ Input variables
│   │   ├── route53.tf          ✅ DNS failover setup
│   │   ├── iam-sns.tf          ✅ Security and notifications
│   │   ├── s3.tf               ✅ Cross-region replication
│   │   └── outputs.tf          ✅ Infrastructure outputs
│   ├── us-east-1/              ⏳ Primary region (Phase 2)
│   ├── us-west-2/              ⏳ Secondary region (Phase 2)
│   └── modules/                ⏳ Reusable modules (Phase 2)
├── applications/               ✅ Sample applications
│   └── sample-web-app/         ✅ Nginx-based test app
├── dr-automation/              ✅ Disaster recovery automation
│   ├── failover-lambda/        ✅ Automated failover functions
│   ├── health-checks/          ✅ Custom health monitoring
│   └── chaos-engineering/      ✅ Failure injection tools
├── monitoring/                 ✅ Monitoring configurations
│   ├── cloudwatch-dashboards/  ✅ Custom dashboards
│   └── alerts/                 ✅ CloudWatch alarms
├── scripts/                    ✅ Complete automation toolkit
│   ├── deploy.sh               ✅ Automated deployment
│   ├── cleanup.sh              ✅ Safe resource cleanup
│   ├── failover-test.sh        ✅ DR testing suite
│   └── monitor-costs.sh        ✅ Cost tracking tools
└── docs/                       ✅ Comprehensive documentation
    └── runbooks/               ✅ Emergency procedures
```

## 🛡️ What You Get Right Now (Phase 1)

### ✅ **Global Infrastructure**
- Route 53 DNS with health checks and failover
- S3 cross-region replication (us-east-1 ↔ us-west-2)
- KMS encryption for all resources
- IAM roles with least-privilege access
- SNS notifications for alerts

### ✅ **Automation & Testing**
- One-click deployment script
- Comprehensive DR testing suite
- Cost monitoring and optimization
- Automated cleanup procedures
- Chaos engineering framework

### ✅ **Security & Compliance**
- Encryption at rest and in transit
- Cross-region replication monitoring
- Health check automation
- Audit logging and notifications
- Security best practices

### ✅ **Monitoring & Alerting**
- CloudWatch dashboards
- Real-time cost tracking
- Health status monitoring
- DR testing reports
- Performance metrics

## 🧪 Testing Your DR Platform

```bash
# Test S3 cross-region replication
./scripts/failover-test.sh s3

# Test Route 53 health checks
./scripts/failover-test.sh health

# Test DNS resolution
./scripts/failover-test.sh dns

# Run complete test suite
./scripts/failover-test.sh all

# Generate test report
./scripts/failover-test.sh > dr-test-results.txt
```

## 💰 Cost Management

```bash
# Monitor daily costs
./scripts/monitor-costs.sh daily

# Set up cost alerts
./scripts/monitor-costs.sh alerts

# Generate cost report
./scripts/monitor-costs.sh report

# Cost optimization recommendations
./scripts/monitor-costs.sh optimize
```

## 📚 Learning Outcomes

### **Phase 1 (Available Now)**
- **DNS-based Failover**: Route 53 health checks and routing
- **Cross-Region Replication**: S3 automated data synchronization
- **Infrastructure Automation**: Terraform at enterprise scale
- **Cost Optimization**: Multi-region resource management
- **Security Best Practices**: Encryption, IAM, and compliance
- **Monitoring & Alerting**: CloudWatch and SNS integration

### **Phase 2 (Coming Next)**
- **Container Orchestration**: ECS multi-region deployment
- **Database Replication**: RDS cross-region setup
- **Load Balancing**: ALB with health checks
- **Application Scaling**: Auto-scaling across regions
- **Advanced Monitoring**: Custom dashboards and metrics

## 🧹 Cleanup & Cost Control

```bash
# Safe cleanup with confirmation
./scripts/cleanup.sh

# Check remaining resources
aws s3 ls | grep dr-platform
aws route53 list-health-checks

# Monitor costs after cleanup
./scripts/monitor-costs.sh daily
```

## 🎯 **Ready to Deploy?**

**Phase 1 is complete and ready to deploy!** This will consume minimal credits (~$0.25/day) while teaching you enterprise DR patterns.

```bash
git clone https://github.com/sivolko/aws-multi-region-dr-platform.git
cd aws-multi-region-dr-platform && ./setup.sh && ./scripts/deploy.sh global
```

## 🌟 **What's Next?**

1. **Deploy Phase 1**: Global infrastructure and DR automation
2. **Learn the Patterns**: Test failover scenarios and monitoring
3. **Phase 2 Coming**: Regional infrastructure with ECS and RDS
4. **Scale Your Knowledge**: Apply patterns to your own projects

## 📋 **Quick Commands Reference**

```bash
# Deploy everything
./setup.sh && ./scripts/deploy.sh global

# Test DR capabilities
./scripts/failover-test.sh all

# Monitor costs
./scripts/monitor-costs.sh report

# Cleanup when done
./scripts/cleanup.sh
```

---

**🚀 Start Building Enterprise DR Today!**

Perfect for learning production disaster recovery patterns while maximizing your AWS credits! **Phase 1 is ready to deploy right now.**

*Built for practical learning and real-world application* 🛡️🌍
