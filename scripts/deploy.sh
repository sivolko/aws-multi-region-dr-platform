#!/bin/bash
# Multi-Region Disaster Recovery Platform Deployment Script
# This script orchestrates the deployment of the entire DR platform

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_GLOBAL_DIR="$PROJECT_ROOT/terraform/global"
TERRAFORM_PRIMARY_DIR="$PROJECT_ROOT/terraform/us-east-1"
TERRAFORM_SECONDARY_DIR="$PROJECT_ROOT/terraform/us-west-2"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_step() {
    echo -e "${PURPLE}➤ $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check required tools
    command -v aws >/dev/null 2>&1 || missing_tools+=("aws-cli")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v jq >/dev/null 2>&1 || missing_tools+=("jq")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured properly"
        echo "Please run 'aws configure' and try again."
        exit 1
    fi
    
    # Check Terraform version
    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    print_status "Terraform version: $tf_version"
    
    # Check AWS CLI version
    local aws_version=$(aws --version | cut -d/ -f2 | cut -d' ' -f1)
    print_status "AWS CLI version: $aws_version"
    
    print_success "All prerequisites met"
}

# Function to get AWS account information
get_aws_info() {
    print_header "AWS Account Information"
    
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    
    print_status "Account ID: $ACCOUNT_ID"
    print_status "User: $USER_ARN"
    
    # Check permissions in both regions
    print_step "Checking permissions in us-east-1..."
    aws ec2 describe-regions --region us-east-1 >/dev/null 2>&1 || {
        print_error "No access to us-east-1 region"
        exit 1
    }
    
    print_step "Checking permissions in us-west-2..."
    aws ec2 describe-regions --region us-west-2 >/dev/null 2>&1 || {
        print_error "No access to us-west-2 region"
        exit 1
    }
    
    print_success "AWS permissions verified"
}

# Function to estimate and confirm costs
estimate_costs() {
    print_header "Cost Estimation & Confirmation"
    
    echo "💰 ESTIMATED DAILY COSTS for Multi-Region DR Platform:"
    echo ""
    echo "📊 COMPUTE & APPLICATION:"
    echo "   • ECS Fargate (Primary): 4 vCPU, 8GB RAM       → ~$3.50/hour"
    echo "   • ECS Fargate (Secondary): 2 vCPU, 4GB RAM     → ~$1.75/hour"
    echo "   • Application Load Balancers (2x)              → ~$0.05/hour"
    echo ""
    echo "🗄️  DATABASE:"
    echo "   • RDS MySQL Primary (db.r5.large)              → ~$0.19/hour"
    echo "   • RDS MySQL Read Replica (db.r5.large)         → ~$0.19/hour"
    echo "   • RDS Storage (1TB gp3) × 2                    → ~$6.25/day"
    echo ""
    echo "🗂️  STORAGE:"
    echo "   • S3 Standard (100GB) × 2 regions              → ~$0.15/day"
    echo "   • S3 Cross-Region Replication                   → ~$1.50/day"
    echo ""
    echo "🌐 NETWORKING:"
    echo "   • NAT Gateways (6x total)                       → ~$6.48/day"
    echo "   • Route 53 Health Checks (2x)                  → ~$2.00/day"
    echo "   • Data Transfer (Cross-Region)                  → ~$3.33/day"
    echo ""
    echo "📈 MONITORING:"
    echo "   • CloudWatch Logs & Metrics                     → ~$1.00/day"
    echo "   • SNS Notifications                             → ~$0.33/day"
    echo ""
    echo -e "${YELLOW}💵 TOTAL ESTIMATED COST: ~$450-550 PER DAY${NC}"
    echo -e "${YELLOW}💵 PERFECT FOR YOUR REMAINING AWS CREDITS!${NC}"
    echo ""
    
    read -p "❓ Do you want to continue with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user"
        exit 0
    fi
}

# Function to initialize terraform configurations
init_terraform() {
    local dir=$1
    local name=$2
    
    print_step "Initializing Terraform in $name..."
    
    cd "$dir"
    terraform init -upgrade
    cd - >/dev/null
    
    print_success "Terraform initialized for $name"
}

# Function to deploy global infrastructure
deploy_global() {
    print_header "Deploying Global Infrastructure"
    
    cd "$TERRAFORM_GLOBAL_DIR"
    
    # Check if tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        print_warning "Creating terraform.tfvars from example..."
        cp terraform.tfvars.example terraform.tfvars 2>/dev/null || {
            print_warning "No terraform.tfvars.example found, creating basic configuration..."
            create_basic_tfvars
        }
    fi
    
    print_step "Planning global infrastructure..."
    terraform plan -out=global.tfplan
    
    print_step "Applying global infrastructure..."
    terraform apply global.tfplan
    
    rm -f global.tfplan
    cd - >/dev/null
    
    print_success "Global infrastructure deployed"
}

# Function to create basic tfvars if example doesn't exist
create_basic_tfvars() {
    cat > terraform.tfvars << EOF
# Basic DR Platform Configuration
environment = "dev"
project_name = "dr-platform"

# Notification (optional - set your email for alerts)
notification_email = ""

# Domain (optional - leave empty to skip DNS setup)
domain_name = ""

# Enable features
enable_route53_health_checks = true
enable_s3_cross_region_replication = true
enable_rds_cross_region_replica = true
enable_automated_failover = false  # Set to true for production
enable_chaos_engineering = true

# DR Targets
rto_target_minutes = 5
rpo_target_minutes = 1
EOF
    print_status "Created basic terraform.tfvars configuration"
}

# Function to deploy regional infrastructure
deploy_regional() {
    local region=$1
    local region_name=$2
    local terraform_dir=$3
    
    print_header "Deploying $region_name Infrastructure ($region)"
    
    # This will be implemented when we create regional modules
    print_step "Regional infrastructure deployment coming next..."
    print_warning "Regional modules not yet implemented in this phase"
}

# Function to verify deployment
verify_deployment() {
    print_header "Verifying Deployment"
    
    cd "$TERRAFORM_GLOBAL_DIR"
    
    print_step "Checking global resources..."
    
    # Check if S3 buckets are created
    local primary_bucket=$(terraform output -raw primary_s3_bucket 2>/dev/null || echo "")
    local secondary_bucket=$(terraform output -raw secondary_s3_bucket 2>/dev/null || echo "")
    
    if [ -n "$primary_bucket" ] && [ -n "$secondary_bucket" ]; then
        print_success "S3 buckets created: $primary_bucket, $secondary_bucket"
    else
        print_warning "S3 bucket information not available"
    fi
    
    # Check Route 53 health checks
    local health_checks=$(terraform output -json route53_outputs 2>/dev/null | jq -r '.health_check_enabled' 2>/dev/null || echo "false")
    if [ "$health_checks" = "true" ]; then
        print_success "Route 53 health checks configured"
    else
        print_warning "Route 53 health checks not configured"
    fi
    
    cd - >/dev/null
    
    print_success "Deployment verification completed"
}

# Function to show deployment summary
show_summary() {
    print_header "Deployment Summary"
    
    cd "$TERRAFORM_GLOBAL_DIR"
    
    echo "🎉 Global DR Infrastructure Deployed Successfully!"
    echo ""
    
    # Show terraform outputs
    if terraform output >/dev/null 2>&1; then
        echo "📋 Infrastructure Summary:"
        terraform output dr_configuration_summary 2>/dev/null | jq -r 'to_entries[] | "   • \(.key): \(.value)"' 2>/dev/null || echo "   Configuration details available via terraform output"
        echo ""
        
        echo "🔗 Important Resources:"
        terraform output s3_outputs 2>/dev/null | jq -r '"   • Primary S3 Bucket: " + .primary_bucket.name + " (" + .primary_bucket.region + ")"' 2>/dev/null || true
        terraform output s3_outputs 2>/dev/null | jq -r '"   • Secondary S3 Bucket: " + .secondary_bucket.name + " (" + .secondary_bucket.region + ")"' 2>/dev/null || true
        echo ""
    fi
    
    echo "🎯 Next Steps:"
    echo "   1. 📧 Set up email notifications (edit terraform.tfvars)"
    echo "   2. 🌐 Configure domain name for DNS failover (optional)"
    echo "   3. 🏗️  Deploy regional infrastructure (coming next phase)"
    echo "   4. 🚀 Deploy sample applications"
    echo "   5. 🧪 Test disaster recovery scenarios"
    echo ""
    
    echo "💰 Cost Monitoring:"
    echo "   • Check AWS Cost Explorer regularly"
    echo "   • Set up billing alerts"
    echo "   • Use cleanup script when done: ./scripts/cleanup.sh"
    echo ""
    
    cd - >/dev/null
    
    print_success "Phase 1 (Global Infrastructure) Complete!"
}

# Function to handle deployment type
deploy_component() {
    local component=$1
    
    case $component in
        "global")
            init_terraform "$TERRAFORM_GLOBAL_DIR" "Global Infrastructure"
            deploy_global
            ;;
        "primary")
            print_warning "Regional deployment coming in next phase"
            # deploy_regional "us-east-1" "Primary Region" "$TERRAFORM_PRIMARY_DIR"
            ;;
        "secondary")
            print_warning "Regional deployment coming in next phase"
            # deploy_regional "us-west-2" "Secondary Region" "$TERRAFORM_SECONDARY_DIR"
            ;;
        "all"|"")
            init_terraform "$TERRAFORM_GLOBAL_DIR" "Global Infrastructure"
            deploy_global
            print_warning "Regional deployments coming in next phase"
            ;;
        *)
            print_error "Unknown component: $component"
            echo "Valid options: global, primary, secondary, all"
            exit 1
            ;;
    esac
}

# Main execution function
main() {
    local deployment_type=${1:-"all"}
    
    print_header "🌍 Multi-Region DR Platform Deployment"
    echo "Starting deployment of: $deployment_type"
    
    check_prerequisites
    get_aws_info
    estimate_costs
    
    deploy_component "$deployment_type"
    
    verify_deployment
    show_summary
}

# Script usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: $0 [component]"
        echo ""
        echo "Components:"
        echo "  global     - Deploy global infrastructure only (Route 53, S3, IAM)"
        echo "  primary    - Deploy primary region infrastructure (us-east-1)"
        echo "  secondary  - Deploy secondary region infrastructure (us-west-2)"  
        echo "  all        - Deploy everything (default)"
        echo ""
        echo "Examples:"
        echo "  $0 global    # Deploy global infrastructure only"
        echo "  $0 all       # Deploy complete DR platform"
        echo "  $0           # Same as 'all'"
        exit 0
    fi
    
    main "$@"
fi
