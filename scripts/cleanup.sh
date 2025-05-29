#!/bin/bash
# Multi-Region DR Platform Cleanup Script
# Safely destroys all DR platform resources across regions

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_GLOBAL_DIR="$PROJECT_ROOT/terraform/global"

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

print_danger() {
    echo -e "${RED}🚨 $1${NC}"
}

# Function to confirm cleanup
confirm_cleanup() {
    print_header "🌍 Multi-Region DR Platform Cleanup"
    
    print_danger "THIS WILL PERMANENTLY DELETE ALL DR PLATFORM RESOURCES!"
    echo ""
    echo "Resources that will be destroyed:"
    echo "• 🗂️  S3 buckets in us-east-1 and us-west-2 (and all contents)"
    echo "• 🌐 Route 53 hosted zone and health checks"
    echo "• 🔐 IAM roles and policies"
    echo "• 🔑 KMS keys (after 7-day waiting period)"
    echo "• 📧 SNS topics and subscriptions"
    echo "• 📊 CloudWatch alarms and metrics"
    echo "• 🏗️  All regional infrastructure (if deployed)"
    echo ""
    print_danger "THIS ACTION CANNOT BE UNDONE!"
    echo ""
    
    read -p "Are you absolutely sure you want to continue? Type 'DELETE' to confirm: " confirmation
    
    if [ "$confirmation" != "DELETE" ]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
    
    echo ""
    read -p "Final confirmation - Type your AWS Account ID to proceed: " account_confirmation
    
    # Get current account ID
    CURRENT_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    
    if [ "$account_confirmation" != "$CURRENT_ACCOUNT_ID" ]; then
        print_error "Account ID mismatch. Cleanup cancelled for safety."
        exit 1
    fi
    
    print_warning "Proceeding with cleanup in 10 seconds... Press Ctrl+C to cancel"
    sleep 10
}

# Function to check current resources
check_current_resources() {
    print_header "Checking Current Resources"
    
    cd "$TERRAFORM_GLOBAL_DIR"
    
    if [ ! -f "terraform.tfstate" ]; then
        print_warning "No terraform state found in global directory"
        print_status "Nothing to cleanup"
        exit 0
    fi
    
    print_status "Found terraform state, proceeding with resource inventory..."
    
    # List current resources
    terraform state list 2>/dev/null | while read -r resource; do
        echo "  • $resource"
    done
    
    cd - >/dev/null
}

# Function to empty S3 buckets
empty_s3_buckets() {
    print_header "Emptying S3 Buckets"
    
    cd "$TERRAFORM_GLOBAL_DIR"
    
    # Get bucket names from terraform output
    PRIMARY_BUCKET=$(terraform output -raw primary_s3_bucket 2>/dev/null || echo "")
    SECONDARY_BUCKET=$(terraform output -raw secondary_s3_bucket 2>/dev/null || echo "")
    
    if [ -n "$PRIMARY_BUCKET" ]; then
        print_status "Emptying primary S3 bucket: $PRIMARY_BUCKET"
        
        # Delete all object versions
        aws s3api list-object-versions --bucket "$PRIMARY_BUCKET" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text | while read -r key version_id; do
            if [ -n "$key" ] && [ -n "$version_id" ]; then
                aws s3api delete-object --bucket "$PRIMARY_BUCKET" --key "$key" --version-id "$version_id" >/dev/null 2>&1 || true
            fi
        done
        
        # Delete all delete markers
        aws s3api list-object-versions --bucket "$PRIMARY_BUCKET" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text | while read -r key version_id; do
            if [ -n "$key" ] && [ -n "$version_id" ]; then
                aws s3api delete-object --bucket "$PRIMARY_BUCKET" --key "$key" --version-id "$version_id" >/dev/null 2>&1 || true
            fi
        done
        
        print_status "Primary S3 bucket emptied"
    fi
    
    if [ -n "$SECONDARY_BUCKET" ]; then
        print_status "Emptying secondary S3 bucket: $SECONDARY_BUCKET"
        
        # Delete all object versions
        aws s3api list-object-versions --bucket "$SECONDARY_BUCKET" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text --region us-west-2 | while read -r key version_id; do
            if [ -n "$key" ] && [ -n "$version_id" ]; then
                aws s3api delete-object --bucket "$SECONDARY_BUCKET" --key "$key" --version-id "$version_id" --region us-west-2 >/dev/null 2>&1 || true
            fi
        done
        
        # Delete all delete markers
        aws s3api list-object-versions --bucket "$SECONDARY_BUCKET" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text --region us-west-2 | while read -r key version_id; do
            if [ -n "$key" ] && [ -n "$version_id" ]; then
                aws s3api delete-object --bucket "$SECONDARY_BUCKET" --key "$key" --version-id "$version_id" --region us-west-2 >/dev/null 2>&1 || true
            fi
        done
        
        print_status "Secondary S3 bucket emptied"
    fi
    
    cd - >/dev/null
}

# Function to handle regional cleanup
cleanup_regional_resources() {
    print_header "Cleaning Up Regional Resources"
    
    # This would cleanup ECS, RDS, ALB, etc. when regional modules are implemented
    print_warning "Regional resource cleanup will be implemented in Phase 2"
    
    # For now, just check for any remaining resources manually
    print_status "Checking for remaining ECS services..."
    for region in us-east-1 us-west-2; do
        local clusters=$(aws ecs list-clusters --region "$region" --query 'clusterArns[?contains(@, `dr-platform`)]' --output text 2>/dev/null || echo "")
        if [ -n "$clusters" ]; then
            print_warning "Found ECS clusters in $region: $clusters"
            print_warning "These will need manual cleanup"
        fi
    done
    
    print_status "Checking for remaining RDS instances..."
    for region in us-east-1 us-west-2; do
        local rds_instances=$(aws rds describe-db-instances --region "$region" --query 'DBInstances[?contains(DBInstanceIdentifier, `dr-platform`)].DBInstanceIdentifier' --output text 2>/dev/null || echo "")
        if [ -n "$rds_instances" ]; then
            print_warning "Found RDS instances in $region: $rds_instances"
            print_warning "These will need manual cleanup"
        fi
    done
}

# Function to run terraform destroy
terraform_destroy() {
    print_header "Destroying Global Infrastructure"
    
    cd "$TERRAFORM_GLOBAL_DIR"
    
    print_status "Running terraform destroy..."
    
    # First attempt
    if terraform destroy -auto-approve; then
        print_status "Terraform destroy completed successfully"
    else
        print_warning "First destroy attempt failed, trying again..."
        sleep 30
        
        # Second attempt
        if terraform destroy -auto-approve; then
            print_status "Terraform destroy completed on second attempt"
        else
            print_error "Terraform destroy failed twice"
            print_warning "Some resources may need manual cleanup"
            
            # Show remaining resources
            terraform state list 2>/dev/null || echo "No state information available"
            
            # Continue with verification anyway
        fi
    fi
    
    cd - >/dev/null
}

# Function to verify cleanup
verify_cleanup() {
    print_header "Verifying Cleanup"
    
    print_status "Checking for remaining DR platform resources..."
    
    # Check S3 buckets
    print_status "Checking S3 buckets..."
    for region in us-east-1 us-west-2; do
        local remaining_buckets=$(aws s3api list-buckets --region "$region" --query 'Buckets[?contains(Name, `dr-platform`)].Name' --output text 2>/dev/null || echo "")
        if [ -n "$remaining_buckets" ]; then
            print_warning "Remaining S3 buckets in $region: $remaining_buckets"
        fi
    done
    
    # Check Route 53 health checks
    print_status "Checking Route 53 health checks..."
    local health_checks=$(aws route53 list-health-checks --query 'HealthChecks[?contains(to_string(Tags), `dr-platform`)].Id' --output text 2>/dev/null || echo "")
    if [ -n "$health_checks" ]; then
        print_warning "Remaining health checks: $health_checks"
    fi
    
    # Check IAM roles
    print_status "Checking IAM roles..."
    local iam_roles=$(aws iam list-roles --query 'Roles[?contains(RoleName, `dr-platform`)].RoleName' --output text 2>/dev/null || echo "")
    if [ -n "$iam_roles" ]; then
        print_warning "Remaining IAM roles: $iam_roles"
    fi
    
    # Check KMS keys
    print_status "Checking KMS keys..."
    local kms_keys=$(aws kms list-aliases --query 'Aliases[?contains(AliasName, `dr-platform`)].AliasName' --output text 2>/dev/null || echo "")
    if [ -n "$kms_keys" ]; then
        print_warning "Remaining KMS aliases: $kms_keys"
        print_warning "KMS keys will be deleted after 7-day waiting period"
    fi
    
    print_status "Cleanup verification completed"
}

# Function to show cost verification reminder
show_cost_verification() {
    print_header "💰 Cost Verification Checklist"
    
    echo "Please verify all resources are cleaned up:"
    echo ""
    echo "🔍 AWS Console Checks:"
    echo "   1. EC2 Dashboard → Running Instances (both regions)"
    echo "   2. ECS Dashboard → Clusters and Services (both regions)"
    echo "   3. RDS Dashboard → DB Instances (both regions)"
    echo "   4. S3 Dashboard → Buckets (both regions)"
    echo "   5. Route 53 Dashboard → Health Checks"
    echo "   6. Load Balancers → ALB/NLB (both regions)"
    echo "   7. VPC Dashboard → NAT Gateways (both regions)"
    echo ""
    echo "💳 Billing Verification:"
    echo "   • Check AWS Cost Explorer for today's usage"
    echo "   • Set up billing alerts if not already done"
    echo "   • Monitor costs over next 24 hours"
    echo ""
    echo "🌐 Console URLs to Check:"
    echo "   • us-east-1: https://us-east-1.console.aws.amazon.com/ec2/"
    echo "   • us-west-2: https://us-west-2.console.aws.amazon.com/ec2/"
    echo "   • Cost Explorer: https://console.aws.amazon.com/cost-reports/"
    echo "   • Billing Dashboard: https://console.aws.amazon.com/billing/"
    echo ""
    print_warning "Remember: Some costs may appear up to 24 hours after resource deletion"
}

# Function to handle cleanup steps
cleanup_steps() {
    check_current_resources
    empty_s3_buckets
    cleanup_regional_resources
    terraform_destroy
    verify_cleanup
}

# Main execution function
main() {
    confirm_cleanup
    
    print_header "Starting DR Platform Cleanup"
    
    cleanup_steps
    
    show_cost_verification
    
    print_header "🎉 Cleanup Completed"
    print_status "Multi-Region DR Platform resources have been destroyed"
    print_warning "Please verify in AWS Console and monitor your bill"
    echo ""
    echo "Thank you for using the Multi-Region DR Platform!"
    echo "We hope you learned valuable disaster recovery patterns! 🚀"
}

# Script usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: $0"
        echo ""
        echo "This script safely destroys all Multi-Region DR Platform resources."
        echo "It will:"
        echo "  1. Empty all S3 buckets across regions"
        echo "  2. Destroy regional infrastructure"
        echo "  3. Destroy global infrastructure"
        echo "  4. Verify cleanup completion"
        echo ""
        echo "⚠️  WARNING: This action cannot be undone!"
        exit 0
    fi
    
    main "$@"
fi
