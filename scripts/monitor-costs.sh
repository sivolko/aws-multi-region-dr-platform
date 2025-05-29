#!/bin/bash
# DR Platform Cost Monitoring Script
# Tracks AWS costs and provides cost optimization recommendations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

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

print_cost() {
    echo -e "${PURPLE}💰 $1${NC}"
}

# Function to get current date in required format
get_date() {
    local days_ago=${1:-0}
    date -d "-${days_ago} days" '+%Y-%m-%d' 2>/dev/null || date -v-${days_ago}d '+%Y-%m-%d' 2>/dev/null || date '+%Y-%m-%d'
}

# Function to get AWS account ID
get_account_id() {
    aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown"
}

# Function to check billing access
check_billing_access() {
    print_status "Checking billing API access..."
    
    if aws ce get-cost-and-usage --time-period Start=$(get_date 1),End=$(get_date 0) --granularity DAILY --metrics BlendedCost >/dev/null 2>&1; then
        print_status "✅ Billing API access confirmed"
        return 0
    else
        print_warning "❌ No billing API access - using alternative cost estimation"
        return 1
    fi
}

# Function to get today's costs
get_daily_costs() {
    print_header "Daily Cost Analysis"
    
    local today=$(get_date 0)
    local yesterday=$(get_date 1)
    
    if check_billing_access; then
        print_status "Fetching cost data for $today..."
        
        # Get today's costs by service
        local cost_output=$(aws ce get-cost-and-usage \
            --time-period Start=$yesterday,End=$today \
            --granularity DAILY \
            --metrics BlendedCost \
            --group-by Type=DIMENSION,Key=SERVICE \
            --output json 2>/dev/null || echo "{}")
        
        if [ "$cost_output" != "{}" ]; then
            echo "$cost_output" | jq -r '
                .ResultsByTime[0].Groups[] | 
                select(.Metrics.BlendedCost.Amount | tonumber > 0) |
                "\(.Keys[0]): $\(.Metrics.BlendedCost.Amount | tonumber | . * 100 | round / 100)"
            ' | sort -k2 -nr | head -10 | while read line; do
                print_cost "$line"
            done
            
            # Get total cost
            local total_cost=$(echo "$cost_output" | jq -r '.ResultsByTime[0].Total.BlendedCost.Amount // "0"')
            print_cost "TOTAL TODAY: \$$(echo "$total_cost" | awk '{printf "%.2f", $1}')"
            
        else
            print_warning "No cost data available for today"
        fi
    else
        estimate_daily_costs
    fi
}

# Function to estimate costs when billing API is not available
estimate_daily_costs() {
    print_status "Estimating costs based on running resources..."
    
    local total_estimated=0
    
    # Estimate S3 costs
    print_status "Checking S3 usage..."
    local s3_buckets=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `dr-platform`)].Name' --output text 2>/dev/null | wc -w)
    if [ "$s3_buckets" -gt 0 ]; then
        local s3_cost=0.50  # Estimated daily cost for storage + requests
        print_cost "S3 Storage ($s3_buckets buckets): ~\$$(printf "%.2f" $s3_cost)"
        total_estimated=$(echo "$total_estimated + $s3_cost" | bc -l 2>/dev/null || echo "$total_estimated")
    fi
    
    # Estimate Route 53 costs
    print_status "Checking Route 53 usage..."
    local health_checks=$(aws route53 list-health-checks --query 'HealthChecks[?contains(to_string(Tags), `dr-platform`)].Id' --output text 2>/dev/null | wc -w)
    if [ "$health_checks" -gt 0 ]; then
        local r53_cost=$(echo "$health_checks * 0.50 / 30" | bc -l 2>/dev/null || echo "0.02")  # $0.50/month per health check
        print_cost "Route 53 Health Checks ($health_checks): ~\$$(printf "%.2f" $r53_cost)"
        total_estimated=$(echo "$total_estimated + $r53_cost" | bc -l 2>/dev/null || echo "$total_estimated")
    fi
    
    # Check for ECS/RDS (would be in regional deployments)
    print_warning "Regional resources (ECS, RDS, ALB) not yet deployed - costs will be higher when added"
    
    print_cost "ESTIMATED DAILY TOTAL: ~\$$(printf "%.2f" $total_estimated)"
}

# Function to get weekly costs
get_weekly_costs() {
    print_header "Weekly Cost Trend"
    
    if ! check_billing_access; then
        print_warning "Billing API not available - skipping weekly analysis"
        return
    fi
    
    local today=$(get_date 0)
    local week_ago=$(get_date 7)
    
    print_status "Fetching weekly cost data..."
    
    local weekly_output=$(aws ce get-cost-and-usage \
        --time-period Start=$week_ago,End=$today \
        --granularity DAILY \
        --metrics BlendedCost \
        --output json 2>/dev/null || echo "{}")
    
    if [ "$weekly_output" != "{}" ]; then
        echo "$weekly_output" | jq -r '.ResultsByTime[] | "\(.TimePeriod.Start): $\(.Total.BlendedCost.Amount | tonumber | . * 100 | round / 100)"' | while read line; do
            print_cost "$line"
        done
        
        # Calculate weekly total
        local weekly_total=$(echo "$weekly_output" | jq -r '[.ResultsByTime[].Total.BlendedCost.Amount | tonumber] | add')
        print_cost "WEEKLY TOTAL: \$$(echo "$weekly_total" | awk '{printf "%.2f", $1}')"
        
        # Project monthly cost
        local monthly_projection=$(echo "$weekly_total * 4.33" | bc -l 2>/dev/null || echo "$weekly_total")
        print_cost "MONTHLY PROJECTION: \$$(printf "%.2f" $monthly_projection)"
    fi
}

# Function to analyze costs by region
analyze_regional_costs() {
    print_header "Regional Cost Breakdown"
    
    if ! check_billing_access; then
        print_warning "Billing API not available - showing resource distribution instead"
        show_resource_distribution
        return
    fi
    
    local today=$(get_date 0)
    local yesterday=$(get_date 1)
    
    print_status "Analyzing costs by region..."
    
    local regional_output=$(aws ce get-cost-and-usage \
        --time-period Start=$yesterday,End=$today \
        --granularity DAILY \
        --metrics BlendedCost \
        --group-by Type=DIMENSION,Key=REGION \
        --output json 2>/dev/null || echo "{}")
    
    if [ "$regional_output" != "{}" ]; then
        echo "$regional_output" | jq -r '
            .ResultsByTime[0].Groups[] | 
            select(.Metrics.BlendedCost.Amount | tonumber > 0) |
            "\(.Keys[0]): $\(.Metrics.BlendedCost.Amount | tonumber | . * 100 | round / 100)"
        ' | sort -k2 -nr | while read line; do
            print_cost "$line"
        done
    fi
}

# Function to show resource distribution when billing API is unavailable
show_resource_distribution() {
    print_status "Resource distribution across regions:"
    
    for region in us-east-1 us-west-2; do
        print_status "Region: $region"
        
        # Count S3 buckets
        local s3_count=$(aws s3api list-buckets --region $region --query 'Buckets[?contains(Name, `dr-platform`)].Name' --output text 2>/dev/null | wc -w || echo "0")
        echo "  • S3 Buckets: $s3_count"
        
        # Count ECS clusters (if any)
        local ecs_count=$(aws ecs list-clusters --region $region --query 'clusterArns[?contains(@, `dr-platform`)]' --output text 2>/dev/null | wc -w || echo "0")
        echo "  • ECS Clusters: $ecs_count"
        
        # Count RDS instances (if any)
        local rds_count=$(aws rds describe-db-instances --region $region --query 'DBInstances[?contains(DBInstanceIdentifier, `dr-platform`)].DBInstanceIdentifier' --output text 2>/dev/null | wc -w || echo "0")
        echo "  • RDS Instances: $rds_count"
    done
}

# Function to provide cost optimization recommendations
cost_optimization_recommendations() {
    print_header "Cost Optimization Recommendations"
    
    print_status "💡 Immediate Cost Savings:"
    echo "  1. Use S3 Intelligent Tiering for automatic cost optimization"
    echo "  2. Enable S3 lifecycle policies to move old data to cheaper storage"
    echo "  3. Use single NAT gateway per region if high availability isn't critical"
    echo "  4. Consider Reserved Instances for predictable workloads"
    echo "  5. Set up CloudWatch billing alerts"
    
    print_status "💡 DR-Specific Optimizations:"
    echo "  1. Keep secondary region resources at minimum scale until needed"
    echo "  2. Use cross-region replication only for critical data"
    echo "  3. Consider using Aurora Global Database for better cost/performance"
    echo "  4. Implement automated scaling policies"
    echo "  5. Use spot instances for non-critical workloads"
    
    print_status "💡 Monitoring and Alerts:"
    echo "  1. Set up cost budgets with alerts"
    echo "  2. Use AWS Cost Explorer for detailed analysis"
    echo "  3. Tag all resources properly for cost allocation"
    echo "  4. Review costs weekly during initial deployment"
    echo "  5. Set up automated cleanup for test resources"
}

# Function to set up cost alerts
setup_cost_alerts() {
    print_header "Setting Up Cost Alerts"
    
    local account_id=$(get_account_id)
    local alert_email=""
    
    read -p "Enter email for cost alerts: " alert_email
    
    if [ -z "$alert_email" ]; then
        print_warning "No email provided - skipping alert setup"
        return
    fi
    
    print_status "Creating cost budget and alerts..."
    
    # Create SNS topic for cost alerts
    local cost_topic_arn=$(aws sns create-topic --name "dr-platform-cost-alerts" --query 'TopicArn' --output text 2>/dev/null || echo "")
    
    if [ -n "$cost_topic_arn" ]; then
        # Subscribe email to topic
        aws sns subscribe --topic-arn "$cost_topic_arn" --protocol email --notification-endpoint "$alert_email" >/dev/null 2>&1
        
        print_status "Cost alert topic created: $cost_topic_arn"
        print_status "Check your email to confirm subscription"
        
        # Create budget (if budgets API is available)
        cat > budget-definition.json << EOF
{
    "BudgetName": "DR-Platform-Daily-Budget",
    "BudgetLimit": {
        "Amount": "50",
        "Unit": "USD"
    },
    "TimeUnit": "DAILY",
    "BudgetType": "COST",
    "CostFilters": {
        "TagKey": ["Project"],
        "TagValue": ["multi-region-dr-platform"]
    }
}
EOF
        
        cat > budget-notifications.json << EOF
[
    {
        "Notification": {
            "NotificationType": "ACTUAL",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 80
        },
        "Subscribers": [
            {
                "SubscriptionType": "EMAIL",
                "Address": "$alert_email"
            }
        ]
    },
    {
        "Notification": {
            "NotificationType": "FORECASTED",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 100
        },
        "Subscribers": [
            {
                "SubscriptionType": "EMAIL",
                "Address": "$alert_email"
            }
        ]
    }
]
EOF
        
        if aws budgets create-budget --account-id "$account_id" --budget file://budget-definition.json --notifications-with-subscribers file://budget-notifications.json >/dev/null 2>&1; then
            print_status "✅ Budget alerts configured successfully"
        else
            print_warning "Budget creation failed - may need additional permissions"
        fi
        
        # Cleanup temp files
        rm -f budget-definition.json budget-notifications.json
        
    else
        print_error "Failed to create SNS topic for cost alerts"
    fi
}

# Function to generate cost report
generate_cost_report() {
    print_header "Generating Cost Report"
    
    local timestamp=$(date)
    local report_file="dr-cost-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Multi-Region DR Platform - Cost Report"
        echo "====================================="
        echo ""
        echo "Report Date: $timestamp"
        echo "AWS Account: $(get_account_id)"
        echo ""
        
        echo "Daily Cost Summary:"
        get_daily_costs 2>&1 | grep -E "(💰|TOTAL)" | sed 's/💰 /  /'
        echo ""
        
        if check_billing_access >/dev/null 2>&1; then
            echo "Weekly Cost Trend:"
            get_weekly_costs 2>&1 | grep -E "(💰|TOTAL|PROJECTION)" | sed 's/💰 /  /'
            echo ""
        fi
        
        echo "Cost Optimization Recommendations:"
        echo "1. Review resource utilization regularly"
        echo "2. Implement automated scaling policies"
        echo "3. Use appropriate storage classes for S3"
        echo "4. Consider Reserved Instances for predictable workloads"
        echo "5. Set up proper cost monitoring and alerts"
        echo ""
        
        echo "Resource Summary:"
        show_resource_distribution 2>&1
        echo ""
        
        echo "Next Review Date: $(date -d '+7 days' '+%Y-%m-%d' 2>/dev/null || date -v+7d '+%Y-%m-%d')"
        
    } > "$report_file"
    
    print_status "Cost report generated: $report_file"
    
    # Upload to S3 if available
    local primary_bucket=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `dr-platform-primary`)].Name' --output text 2>/dev/null | head -1)
    if [ -n "$primary_bucket" ]; then
        if aws s3 cp "$report_file" "s3://$primary_bucket/reports/" >/dev/null 2>&1; then
            print_status "Report uploaded to S3: s3://$primary_bucket/reports/$report_file"
        fi
    fi
}

# Main execution function
main() {
    local action=${1:-"report"}
    
    print_header "💰 DR Platform Cost Monitoring"
    echo "Action: $action"
    
    case $action in
        "daily")
            get_daily_costs
            ;;
        "weekly")
            get_weekly_costs
            ;;
        "regional")
            analyze_regional_costs
            ;;
        "optimize")
            cost_optimization_recommendations
            ;;
        "alerts")
            setup_cost_alerts
            ;;
        "report"|"")
            get_daily_costs
            get_weekly_costs
            analyze_regional_costs
            cost_optimization_recommendations
            generate_cost_report
            ;;
        *)
            print_error "Unknown action: $action"
            echo "Valid options: daily, weekly, regional, optimize, alerts, report"
            exit 1
            ;;
    esac
    
    print_header "💰 Cost Monitoring Complete"
}

# Script usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: $0 [action]"
        echo ""
        echo "Actions:"
        echo "  daily      - Show today's costs"
        echo "  weekly     - Show weekly cost trend"
        echo "  regional   - Analyze costs by region"
        echo "  optimize   - Show cost optimization recommendations"
        echo "  alerts     - Set up cost alerts"
        echo "  report     - Generate comprehensive cost report (default)"
        echo ""
        echo "Examples:"
        echo "  $0 daily    # Show today's costs"
        echo "  $0 report   # Generate full cost report"
        echo "  $0          # Same as 'report'"
        echo ""
        echo "Note: Requires billing API access for detailed cost data"
        exit 0
    fi
    
    main "$@"
fi
