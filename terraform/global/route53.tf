# Route 53 Hosted Zone (if domain is provided)
resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name

  tags = merge(var.tags, {
    Name = "${var.project_name}-hosted-zone"
  })
}

# Health Check for Primary Region
resource "aws_route53_health_check" "primary_health_check" {
  count                           = var.enable_route53_health_checks ? 1 : 0
  fqdn                           = var.domain_name != "" ? "primary.${var.domain_name}" : "primary-${var.project_name}.example.com"
  port                           = var.application_port
  type                           = "HTTP"
  resource_path                  = "/health"
  failure_threshold              = var.health_check_failure_threshold
  request_interval               = var.health_check_interval_seconds
  cloudwatch_logs_region         = var.primary_region
  cloudwatch_alarm_region        = var.primary_region
  insufficient_data_health_status = "Failure"

  tags = merge(var.tags, {
    Name = "${var.project_name}-primary-health-check"
    Region = var.primary_region
  })
}

# Health Check for Secondary Region
resource "aws_route53_health_check" "secondary_health_check" {
  count                           = var.enable_route53_health_checks ? 1 : 0
  fqdn                           = var.domain_name != "" ? "secondary.${var.domain_name}" : "secondary-${var.project_name}.example.com"
  port                           = var.application_port
  type                           = "HTTP"
  resource_path                  = "/health"
  failure_threshold              = var.health_check_failure_threshold
  request_interval               = var.health_check_interval_seconds
  cloudwatch_logs_region         = var.secondary_region
  cloudwatch_alarm_region        = var.secondary_region
  insufficient_data_health_status = "Failure"

  tags = merge(var.tags, {
    Name = "${var.project_name}-secondary-health-check"
    Region = var.secondary_region
  })
}

# Primary A Record with Health Check
resource "aws_route53_record" "primary" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = var.enable_route53_health_checks ? aws_route53_health_check.primary_health_check[0].id : null
  set_identifier  = "primary"
  ttl            = 60

  # This will be populated by regional infrastructure
  records = ["1.2.3.4"]  # Placeholder - will be updated by ALB

  depends_on = [aws_route53_zone.main]
}

# Secondary A Record (Failover)
resource "aws_route53_record" "secondary" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = var.enable_route53_health_checks ? aws_route53_health_check.secondary_health_check[0].id : null
  set_identifier  = "secondary"
  ttl            = 60

  # This will be populated by regional infrastructure
  records = ["5.6.7.8"]  # Placeholder - will be updated by ALB

  depends_on = [aws_route53_zone.main]
}

# CloudWatch Alarms for Health Checks
resource "aws_cloudwatch_metric_alarm" "primary_health_check_alarm" {
  count               = var.enable_route53_health_checks && var.notification_email != "" ? 1 : 0
  alarm_name          = "${var.project_name}-primary-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "HealthCheckStatus"
  namespace          = "AWS/Route53"
  period             = "60"
  statistic          = "Minimum"
  threshold          = "1"
  alarm_description  = "This metric monitors primary region health check"
  alarm_actions      = [aws_sns_topic.dr_notifications[0].arn]
  ok_actions         = [aws_sns_topic.dr_notifications[0].arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary_health_check[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-primary-health-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "secondary_health_check_alarm" {
  count               = var.enable_route53_health_checks && var.notification_email != "" ? 1 : 0
  alarm_name          = "${var.project_name}-secondary-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "HealthCheckStatus"
  namespace          = "AWS/Route53"
  period             = "60"
  statistic          = "Minimum"
  threshold          = "1"
  alarm_description  = "This metric monitors secondary region health check"
  alarm_actions      = [aws_sns_topic.dr_notifications[0].arn]
  ok_actions         = [aws_sns_topic.dr_notifications[0].arn]

  dimensions = {
    HealthCheckId = aws_route53_health_check.secondary_health_check[0].id
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-secondary-health-alarm"
  })
}

# Output important information
output "route53_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : null
}

output "route53_name_servers" {
  description = "Route 53 name servers"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : null
}

output "primary_health_check_id" {
  description = "Primary region health check ID"
  value       = var.enable_route53_health_checks ? aws_route53_health_check.primary_health_check[0].id : null
}

output "secondary_health_check_id" {
  description = "Secondary region health check ID"
  value       = var.enable_route53_health_checks ? aws_route53_health_check.secondary_health_check[0].id : null
}
