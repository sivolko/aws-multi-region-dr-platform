# Global Outputs for Multi-Region DR Platform

# Route 53 Outputs
output "route53_outputs" {
  description = "Route 53 configuration details"
  value = {
    zone_id                    = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : null
    name_servers               = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : null
    domain_name                = var.domain_name
    primary_health_check_id    = var.enable_route53_health_checks ? aws_route53_health_check.primary_health_check[0].id : null
    secondary_health_check_id  = var.enable_route53_health_checks ? aws_route53_health_check.secondary_health_check[0].id : null
    health_check_enabled       = var.enable_route53_health_checks
  }
}

# IAM Outputs
output "iam_outputs" {
  description = "IAM roles and policies for DR platform"
  value = {
    dr_lambda_role_arn      = aws_iam_role.dr_lambda_role.arn
    ecs_task_role_arn       = aws_iam_role.ecs_task_role.arn
    ecs_execution_role_arn  = aws_iam_role.ecs_execution_role.arn
    s3_replication_role_arn = var.enable_s3_cross_region_replication ? aws_iam_role.s3_replication_role[0].arn : null
  }
}

# S3 Outputs
output "s3_outputs" {
  description = "S3 bucket information for both regions"
  value = {
    primary_bucket = {
      name               = aws_s3_bucket.primary_bucket.bucket
      arn                = aws_s3_bucket.primary_bucket.arn
      region             = var.primary_region
      domain_name        = aws_s3_bucket.primary_bucket.bucket_domain_name
      hosted_zone_id     = aws_s3_bucket.primary_bucket.hosted_zone_id
    }
    secondary_bucket = {
      name               = aws_s3_bucket.secondary_bucket.bucket
      arn                = aws_s3_bucket.secondary_bucket.arn
      region             = var.secondary_region
      domain_name        = aws_s3_bucket.secondary_bucket.bucket_domain_name
      hosted_zone_id     = aws_s3_bucket.secondary_bucket.hosted_zone_id
    }
    cross_region_replication_enabled = var.enable_s3_cross_region_replication
  }
}

# SNS and Notification Outputs
output "notification_outputs" {
  description = "SNS and notification configuration"
  value = {
    sns_topic_arn         = var.notification_email != "" ? aws_sns_topic.dr_notifications[0].arn : null
    notification_email    = var.notification_email
    notifications_enabled = var.notification_email != ""
  }
}

# Encryption Outputs
output "encryption_outputs" {
  description = "KMS encryption configuration"
  value = {
    kms_key_arn   = aws_kms_key.dr_platform_key.arn
    kms_key_id    = aws_kms_key.dr_platform_key.key_id
    kms_key_alias = aws_kms_alias.dr_platform_key_alias.name
  }
}

# Configuration Summary
output "dr_configuration_summary" {
  description = "Summary of DR configuration"
  value = {
    project_name                      = var.project_name
    environment                       = var.environment
    primary_region                    = var.primary_region
    secondary_region                  = var.secondary_region
    rto_target_minutes               = var.rto_target_minutes
    rpo_target_minutes               = var.rpo_target_minutes
    health_check_failure_threshold   = var.health_check_failure_threshold
    health_check_interval_seconds    = var.health_check_interval_seconds
    automated_failover_enabled       = var.enable_automated_failover
    chaos_engineering_enabled        = var.enable_chaos_engineering
    s3_cross_region_replication      = var.enable_s3_cross_region_replication
    rds_cross_region_replica         = var.enable_rds_cross_region_replica
  }
}

# AWS Account Information
output "aws_account_info" {
  description = "AWS account information"
  value = {
    account_id = data.aws_caller_identity.current.account_id
    user_id    = data.aws_caller_identity.current.user_id
    arn        = data.aws_caller_identity.current.arn
  }
}

# Availability Zones
output "availability_zones" {
  description = "Available AZs in both regions"
  value = {
    primary_region_azs   = data.aws_availability_zones.primary.names
    secondary_region_azs = data.aws_availability_zones.secondary.names
  }
}

# Next Steps Instructions
output "next_steps" {
  description = "Next steps after global infrastructure deployment"
  value = {
    step_1 = "Deploy regional infrastructure: terraform apply -target=module.primary_region"
    step_2 = "Deploy secondary region: terraform apply -target=module.secondary_region"
    step_3 = "Deploy applications: ./scripts/deploy-apps.sh"
    step_4 = "Test failover: ./scripts/failover-test.sh"
    step_5 = "Monitor dashboards: Check CloudWatch and Route 53 health checks"
    step_6 = "Set up alerting: Subscribe to SNS topic for notifications"
  }
}

# Important DNS Configuration Notice
output "dns_configuration_notice" {
  description = "Important DNS configuration information"
  value = var.domain_name != "" ? {
    message = "IMPORTANT: Update your domain registrar's name servers to:"
    name_servers = aws_route53_zone.main[0].name_servers
    note = "This is required for DNS failover to work properly"
  } : {
    message = "No domain configured - using health checks with placeholder FQDNs"
    note = "Configure domain_name variable to enable proper DNS failover"
  }
}

# Cost Estimation
output "estimated_monthly_costs" {
  description = "Estimated monthly costs for the DR platform"
  value = {
    route53_health_checks = "$0.50 per health check × ${var.enable_route53_health_checks ? 2 : 0} = $${var.enable_route53_health_checks ? 1.00 : 0.00}"
    s3_storage_primary    = "~$2.30 per 100GB (Standard)"
    s3_storage_secondary  = "~$2.30 per 100GB (Standard)"
    s3_replication_costs  = var.enable_s3_cross_region_replication ? "~$0.015 per GB transferred" : "Not enabled"
    kms_key_usage        = "$1.00 per month per key"
    sns_notifications    = "$0.50 per 1M requests"
    lambda_executions    = "$0.20 per 1M requests"
    data_transfer_costs  = "Variable - $0.09 per GB (cross-region)"
    note                 = "Regional infrastructure costs will be additional (ECS, RDS, ALB, etc.)"
  }
}

# Monitoring and Alerting URLs
output "monitoring_urls" {
  description = "Important monitoring URLs"
  value = {
    route53_console     = "https://console.aws.amazon.com/route53/v2/home"
    s3_primary_console  = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.primary_bucket.bucket}?region=${var.primary_region}"
    s3_secondary_console = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.secondary_bucket.bucket}?region=${var.secondary_region}"
    cloudwatch_primary  = "https://${var.primary_region}.console.aws.amazon.com/cloudwatch/home?region=${var.primary_region}"
    cloudwatch_secondary = "https://${var.secondary_region}.console.aws.amazon.com/cloudwatch/home?region=${var.secondary_region}"
    iam_console         = "https://console.aws.amazon.com/iam/home"
    kms_console         = "https://console.aws.amazon.com/kms/home"
  }
}

# Security Checklist
output "security_checklist" {
  description = "Security implementation status"
  value = {
    encryption_at_rest = {
      s3_buckets      = "✅ KMS encrypted"
      kms_key_rotation = "✅ Enabled"
      status          = "Implemented"
    }
    access_control = {
      iam_roles_principle = "✅ Least privilege implemented"
      s3_public_access   = "✅ Blocked"
      status            = "Implemented"
    }
    monitoring = {
      cloudwatch_alarms    = "✅ Health check failures"
      sns_notifications   = var.notification_email != "" ? "✅ Configured" : "⚠️  No email provided"
      s3_replication_monitoring = var.enable_s3_cross_region_replication ? "✅ Enabled" : "⚠️  Not enabled"
      status = "Partially implemented"
    }
    data_protection = {
      s3_versioning       = "✅ Enabled"
      cross_region_backup = var.enable_s3_cross_region_replication ? "✅ Enabled" : "⚠️  Not enabled"
      lifecycle_policies  = "✅ Configured"
      status             = "Implemented"
    }
  }
}
