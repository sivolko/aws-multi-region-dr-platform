variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "dr-platform"
}

variable "domain_name" {
  description = "Domain name for the application (optional - will create if provided)"
  type        = string
  default     = ""
}

variable "enable_route53_health_checks" {
  description = "Enable Route 53 health checks for failover"
  type        = bool
  default     = true
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for DR"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr_primary" {
  description = "CIDR block for primary region VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_cidr_secondary" {
  description = "CIDR block for secondary region VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "enable_s3_cross_region_replication" {
  description = "Enable S3 cross-region replication"
  type        = bool
  default     = true
}

variable "enable_rds_cross_region_replica" {
  description = "Enable RDS cross-region read replica"
  type        = bool
  default     = true
}

variable "rto_target_minutes" {
  description = "Recovery Time Objective target in minutes"
  type        = number
  default     = 5
}

variable "rpo_target_minutes" {
  description = "Recovery Point Objective target in minutes"
  type        = number
  default     = 1
}

variable "health_check_failure_threshold" {
  description = "Number of consecutive health check failures before failover"
  type        = number
  default     = 3
}

variable "health_check_interval_seconds" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "enable_automated_failover" {
  description = "Enable automated failover (be careful!)"
  type        = bool
  default     = false
}

variable "notification_email" {
  description = "Email address for DR notifications"
  type        = string
  default     = ""
}

variable "enable_chaos_engineering" {
  description = "Enable chaos engineering components"
  type        = bool
  default     = true
}

variable "application_port" {
  description = "Application port for health checks"
  type        = number
  default     = 80
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
