#!/bin/bash
# Quick setup script for Multi-Region DR Platform
# Prepares the environment for deployment

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header "🌍 Multi-Region DR Platform - Quick Setup"

# Make scripts executable
print_status "Making scripts executable..."
chmod +x scripts/deploy.sh
chmod +x scripts/cleanup.sh

# Create terraform.tfvars if it doesn't exist
if [ ! -f "terraform/global/terraform.tfvars" ]; then
    print_status "Creating terraform.tfvars from example..."
    cp terraform/global/terraform.tfvars.example terraform/global/terraform.tfvars 2>/dev/null || {
        print_status "Creating default terraform.tfvars..."
        cat > terraform/global/terraform.tfvars << 'EOF'
# Multi-Region DR Platform Configuration
# Customize these values for your deployment

# Basic Configuration
environment = "dev"
project_name = "dr-platform"

# Regional Configuration
primary_region = "us-east-1"
secondary_region = "us-west-2"
vpc_cidr_primary = "10.0.0.0/16"
vpc_cidr_secondary = "10.1.0.0/16"

# Notification Configuration
# Set your email to receive DR alerts and notifications
notification_email = ""  # Add your email here

# DNS Configuration (Optional)
# If you have a domain, enter it here for DNS failover
domain_name = ""  # e.g., "example.com"

# DR Features Configuration
enable_route53_health_checks = true
enable_s3_cross_region_replication = true
enable_rds_cross_region_replica = true
enable_automated_failover = false  # Set to true for production
enable_chaos_engineering = true

# DR Objectives
rto_target_minutes = 5  # Recovery Time Objective
rpo_target_minutes = 1  # Recovery Point Objective

# Health Check Configuration
health_check_failure_threshold = 3
health_check_interval_seconds = 30

# Application Configuration
application_port = 80

# Additional tags
tags = {
  Owner = "your-name"
  Team  = "platform"
  CostCenter = "learning"
}
EOF
    }
    
    echo ""
    echo "📝 IMPORTANT: Please edit terraform/global/terraform.tfvars:"
    echo "   • Set your notification_email for alerts"
    echo "   • Configure domain_name if you have one"
    echo "   • Adjust other settings as needed"
    echo ""
fi

# Create example application configurations
print_status "Creating sample application configurations..."
mkdir -p applications/sample-web-app
cat > applications/sample-web-app/Dockerfile << 'EOF'
FROM nginx:alpine

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy static content
COPY index.html /usr/share/nginx/html/
COPY health.html /usr/share/nginx/html/health

# Add health check script
COPY health-check.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/health-check.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD /usr/local/bin/health-check.sh

CMD ["nginx", "-g", "daemon off;"]
EOF

cat > applications/sample-web-app/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Multi-Region DR Platform</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 0; 
            padding: 20px; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container { 
            max-width: 800px; 
            margin: 0 auto; 
            text-align: center;
            padding: 50px 20px;
        }
        .region-badge {
            background: rgba(255,255,255,0.2);
            padding: 10px 20px;
            border-radius: 25px;
            display: inline-block;
            margin: 20px 0;
        }
        .status { 
            background: #4CAF50; 
            padding: 10px; 
            border-radius: 5px; 
            margin: 20px 0;
        }
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 30px 0;
        }
        .metric {
            background: rgba(255,255,255,0.1);
            padding: 20px;
            border-radius: 10px;
        }
        .footer {
            margin-top: 50px;
            font-size: 14px;
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌍 Multi-Region DR Platform</h1>
        <div class="region-badge" id="region-badge">
            📍 Region: <span id="region">Loading...</span>
        </div>
        
        <div class="status">
            ✅ Application Status: Healthy
        </div>
        
        <h3>Platform Features</h3>
        <div class="metrics">
            <div class="metric">
                <h4>🔄 Auto Failover</h4>
                <p>DNS-based automatic failover with Route 53</p>
            </div>
            <div class="metric">
                <h4>📊 Real-time Replication</h4>
                <p>Cross-region data synchronization</p>
            </div>
            <div class="metric">
                <h4>🛡️ High Availability</h4>
                <p>Multi-AZ deployment across regions</p>
            </div>
            <div class="metric">
                <h4>📈 Monitoring</h4>
                <p>Comprehensive health checks & alerts</p>
            </div>
        </div>
        
        <h3>DR Objectives</h3>
        <p><strong>RTO:</strong> &lt; 5 minutes | <strong>RPO:</strong> &lt; 1 minute</p>
        
        <div class="footer">
            <p>Deployment Time: <span id="timestamp"></span></p>
            <p>Instance ID: <span id="instance-id">Container</span></p>
        </div>
    </div>

    <script>
        // Detect region from metadata or environment
        async function detectRegion() {
            try {
                // Try to get region from instance metadata (if running on EC2)
                const response = await fetch('http://169.254.169.254/latest/meta-data/placement/region', {
                    timeout: 1000
                });
                if (response.ok) {
                    const region = await response.text();
                    document.getElementById('region').textContent = region;
                    document.getElementById('region-badge').style.background = 
                        region.includes('east') ? 'rgba(52, 152, 219, 0.8)' : 'rgba(231, 76, 60, 0.8)';
                } else {
                    throw new Error('Metadata not available');
                }
            } catch (error) {
                // Fallback to environment variable or default
                document.getElementById('region').textContent = 'us-east-1 (Primary)';
            }
        }
        
        // Set timestamp
        document.getElementById('timestamp').textContent = new Date().toISOString();
        
        // Initialize
        detectRegion();
    </script>
</body>
</html>
EOF

cat > applications/sample-web-app/health.html << 'EOF'
{
  "status": "healthy",
  "timestamp": "2025-05-30T00:00:00Z",
  "region": "us-east-1",
  "version": "1.0.0",
  "checks": {
    "database": "ok",
    "storage": "ok",
    "external_services": "ok"
  }
}
EOF

cat > applications/sample-web-app/health-check.sh << 'EOF'
#!/bin/sh
# Health check script for container

# Check if nginx is running
if ! pgrep nginx > /dev/null; then
    echo "Nginx is not running"
    exit 1
fi

# Check if health endpoint responds
if ! curl -f http://localhost/health > /dev/null 2>&1; then
    echo "Health endpoint not responding"
    exit 1
fi

echo "Health check passed"
exit 0
EOF

cat > applications/sample-web-app/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    server {
        listen 80;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        
        location /health {
            alias /usr/share/nginx/html/health;
            add_header Content-Type application/json;
        }
        
        # Additional health check endpoint
        location /healthz {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF

# Create DR automation directory structure
print_status "Creating DR automation structure..."
mkdir -p dr-automation/failover-lambda
mkdir -p dr-automation/health-checks
mkdir -p dr-automation/chaos-engineering

# Create example failover Lambda function
cat > dr-automation/failover-lambda/failover.py << 'EOF'
"""
Automated Disaster Recovery Failover Lambda Function
Handles automated failover scenarios for the DR platform
"""

import json
import boto3
import os
import logging
from datetime import datetime
from typing import Dict, Any

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
route53 = boto3.client('route53')
rds = boto3.client('rds')
ecs = boto3.client('ecs')
sns = boto3.client('sns')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for DR failover automation
    """
    try:
        logger.info(f"Failover event received: {json.dumps(event)}")
        
        # Determine failover type
        failover_type = event.get('failover_type', 'dns_only')
        source_region = event.get('source_region', 'us-east-1')
        target_region = event.get('target_region', 'us-west-2')
        
        # Execute failover based on type
        if failover_type == 'dns_only':
            result = execute_dns_failover(source_region, target_region)
        elif failover_type == 'full_failover':
            result = execute_full_failover(source_region, target_region)
        elif failover_type == 'database_failover':
            result = execute_database_failover(source_region, target_region)
        else:
            raise ValueError(f"Unknown failover type: {failover_type}")
        
        # Send notification
        send_failover_notification(result, failover_type)
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
        
    except Exception as e:
        logger.error(f"Failover failed: {str(e)}")
        send_error_notification(str(e))
        raise e

def execute_dns_failover(source_region: str, target_region: str) -> Dict[str, Any]:
    """
    Execute DNS-based failover by updating Route 53 records
    """
    logger.info(f"Executing DNS failover from {source_region} to {target_region}")
    
    # Get hosted zone ID
    hosted_zone_id = os.environ.get('HOSTED_ZONE_ID')
    domain_name = os.environ.get('DOMAIN_NAME')
    
    if not hosted_zone_id or not domain_name:
        raise ValueError("HOSTED_ZONE_ID and DOMAIN_NAME must be set")
    
    # Update DNS records to point to secondary region
    change_batch = {
        'Changes': [
            {
                'Action': 'UPSERT',
                'ResourceRecordSet': {
                    'Name': domain_name,
                    'Type': 'A',
                    'SetIdentifier': 'primary',
                    'Failover': {'Type': 'SECONDARY'},
                    'TTL': 60,
                    'ResourceRecords': [{'Value': '0.0.0.0'}]  # Will be updated with actual ALB IP
                }
            }
        ]
    }
    
    response = route53.change_resource_record_sets(
        HostedZoneId=hosted_zone_id,
        ChangeBatch=change_batch
    )
    
    return {
        'failover_type': 'dns_only',
        'source_region': source_region,
        'target_region': target_region,
        'change_id': response['ChangeInfo']['Id'],
        'status': 'completed',
        'timestamp': datetime.utcnow().isoformat()
    }

def execute_database_failover(source_region: str, target_region: str) -> Dict[str, Any]:
    """
    Execute database failover by promoting read replica
    """
    logger.info(f"Executing database failover from {source_region} to {target_region}")
    
    # Get RDS instance identifiers
    primary_db_identifier = os.environ.get('PRIMARY_DB_IDENTIFIER')
    replica_db_identifier = os.environ.get('REPLICA_DB_IDENTIFIER')
    
    if not replica_db_identifier:
        raise ValueError("REPLICA_DB_IDENTIFIER must be set")
    
    # Promote read replica
    rds_target = boto3.client('rds', region_name=target_region)
    
    response = rds_target.promote_read_replica(
        DBInstanceIdentifier=replica_db_identifier
    )
    
    return {
        'failover_type': 'database_failover',
        'source_region': source_region,
        'target_region': target_region,
        'promoted_instance': replica_db_identifier,
        'status': 'in_progress',
        'timestamp': datetime.utcnow().isoformat()
    }

def execute_full_failover(source_region: str, target_region: str) -> Dict[str, Any]:
    """
    Execute full failover including DNS, database, and application scaling
    """
    logger.info(f"Executing full failover from {source_region} to {target_region}")
    
    results = []
    
    # 1. Scale up secondary region ECS services
    ecs_target = boto3.client('ecs', region_name=target_region)
    cluster_name = os.environ.get('ECS_CLUSTER_NAME', 'dr-platform-cluster')
    service_name = os.environ.get('ECS_SERVICE_NAME', 'dr-platform-service')
    
    try:
        ecs_target.update_service(
            cluster=cluster_name,
            service=service_name,
            desiredCount=3  # Scale up for production load
        )
        results.append("ECS service scaled up in target region")
    except Exception as e:
        logger.warning(f"ECS scaling failed: {e}")
        results.append(f"ECS scaling failed: {e}")
    
    # 2. Execute database failover
    try:
        db_result = execute_database_failover(source_region, target_region)
        results.append(f"Database failover initiated: {db_result['promoted_instance']}")
    except Exception as e:
        logger.warning(f"Database failover failed: {e}")
        results.append(f"Database failover failed: {e}")
    
    # 3. Execute DNS failover
    try:
        dns_result = execute_dns_failover(source_region, target_region)
        results.append(f"DNS failover completed: {dns_result['change_id']}")
    except Exception as e:
        logger.warning(f"DNS failover failed: {e}")
        results.append(f"DNS failover failed: {e}")
    
    return {
        'failover_type': 'full_failover',
        'source_region': source_region,
        'target_region': target_region,
        'results': results,
        'status': 'completed',
        'timestamp': datetime.utcnow().isoformat()
    }

def send_failover_notification(result: Dict[str, Any], failover_type: str) -> None:
    """
    Send SNS notification about failover completion
    """
    topic_arn = os.environ.get('SNS_TOPIC_ARN')
    if not topic_arn:
        return
    
    subject = f"🚨 DR Failover Completed - {failover_type}"
    
    message = f"""
Disaster Recovery Failover Completed

Failover Type: {failover_type}
Source Region: {result.get('source_region')}
Target Region: {result.get('target_region')}
Status: {result.get('status')}
Timestamp: {result.get('timestamp')}

Details: {json.dumps(result, indent=2)}

Please verify application functionality in the target region.
    """
    
    try:
        sns.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
        logger.info("Failover notification sent")
    except Exception as e:
        logger.error(f"Failed to send notification: {e}")

def send_error_notification(error_message: str) -> None:
    """
    Send SNS notification about failover failure
    """
    topic_arn = os.environ.get('SNS_TOPIC_ARN')
    if not topic_arn:
        return
    
    subject = "❌ DR Failover Failed"
    
    message = f"""
Disaster Recovery Failover Failed

Error: {error_message}
Timestamp: {datetime.utcnow().isoformat()}

Please investigate immediately and consider manual failover procedures.
    """
    
    try:
        sns.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message
        )
    except Exception as e:
        logger.error(f"Failed to send error notification: {e}")
EOF

# Create monitoring setup
print_status "Creating monitoring configurations..."
mkdir -p monitoring/cloudwatch-dashboards
mkdir -p monitoring/alerts

cat > monitoring/cloudwatch-dashboards/dr-platform-dashboard.json << 'EOF'
{
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/Route53", "HealthCheckStatus", "HealthCheckId", "primary-health-check" ],
                    [ "...", "secondary-health-check" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "Route 53 Health Check Status",
                "yAxis": {
                    "left": {
                        "min": 0,
                        "max": 1
                    }
                }
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/S3", "BucketSizeBytes", "BucketName", "dr-platform-primary", "StorageType", "StandardStorage" ],
                    [ "...", "dr-platform-secondary", "...", "..." ]
                ],
                "period": 86400,
                "stat": "Average",
                "region": "us-east-1",
                "title": "S3 Bucket Size",
                "yAxis": {
                    "left": {
                        "min": 0
                    }
                }
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "dr-platform-primary" ],
                    [ "...", "dr-platform-replica" ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "RDS Connections"
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/ECS", "CPUUtilization", "ServiceName", "dr-platform-service", "ClusterName", "dr-platform-cluster" ],
                    [ ".", "MemoryUtilization", ".", ".", ".", "." ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "us-east-1",
                "title": "ECS Service Metrics - Primary Region"
            }
        },
        {
            "type": "log",
            "properties": {
                "query": "SOURCE '/aws/lambda/dr-platform-failover'\n| fields @timestamp, @message\n| filter @message like /ERROR/\n| sort @timestamp desc\n| limit 100",
                "region": "us-east-1",
                "title": "Failover Lambda Errors"
            }
        }
    ]
}
EOF

print_header "🎉 Setup Completed!"

echo ""
echo "📋 Next Steps:"
echo "   1. 📧 Edit terraform/global/terraform.tfvars (set your email)"
echo "   2. 🚀 Deploy platform: ./scripts/deploy.sh"
echo "   3. 🧪 Test applications: docker build in applications/"
echo "   4. 📊 Monitor: Check CloudWatch dashboards"
echo "   5. 🧹 Cleanup: ./scripts/cleanup.sh when done"
echo ""
echo "💡 Tips:"
echo "   • Set notification_email in terraform.tfvars for alerts"
echo "   • Configure domain_name for proper DNS failover"
echo "   • Monitor costs regularly during deployment"
echo ""
echo "🌟 You're ready to build enterprise-grade disaster recovery!"
