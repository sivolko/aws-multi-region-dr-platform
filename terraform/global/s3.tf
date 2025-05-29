# S3 Bucket for Primary Region
resource "aws_s3_bucket" "primary_bucket" {
  provider = aws.primary
  bucket   = "${var.project_name}-primary-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name   = "${var.project_name}-primary-bucket"
    Region = var.primary_region
    Role   = "primary"
  })
}

# S3 Bucket for Secondary Region
resource "aws_s3_bucket" "secondary_bucket" {
  provider = aws.secondary
  bucket   = "${var.project_name}-secondary-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name   = "${var.project_name}-secondary-bucket"
    Region = var.secondary_region
    Role   = "secondary"
  })
}

# Random ID for unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket Versioning - Primary
resource "aws_s3_bucket_versioning" "primary_versioning" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Versioning - Secondary
resource "aws_s3_bucket_versioning" "secondary_versioning" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Encryption - Primary
resource "aws_s3_bucket_server_side_encryption_configuration" "primary_encryption" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.dr_platform_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Encryption - Secondary
resource "aws_s3_bucket_server_side_encryption_configuration" "secondary_encryption" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.dr_platform_key.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block - Primary
resource "aws_s3_bucket_public_access_block" "primary_pab" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Public Access Block - Secondary
resource "aws_s3_bucket_public_access_block" "secondary_pab" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Cross-Region Replication Configuration
resource "aws_s3_bucket_replication_configuration" "replication" {
  count    = var.enable_s3_cross_region_replication ? 1 : 0
  provider = aws.primary
  role     = aws_iam_role.s3_replication_role[0].arn
  bucket   = aws_s3_bucket.primary_bucket.id

  rule {
    id     = "replicate_everything"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.secondary_bucket.arn
      storage_class = "STANDARD_IA"
      
      encryption_configuration {
        replica_kms_key_id = aws_kms_key.dr_platform_key.arn
      }
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.primary_versioning,
    aws_s3_bucket_versioning.secondary_versioning
  ]
}

# S3 Lifecycle Configuration - Primary
resource "aws_s3_bucket_lifecycle_configuration" "primary_lifecycle" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary_bucket.id

  rule {
    id     = "transition_to_ia_and_glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# S3 Lifecycle Configuration - Secondary
resource "aws_s3_bucket_lifecycle_configuration" "secondary_lifecycle" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.secondary_bucket.id

  rule {
    id     = "transition_to_ia_and_glacier"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

# CloudWatch Alarms for S3 Replication Monitoring
resource "aws_cloudwatch_metric_alarm" "s3_replication_failure" {
  count               = var.enable_s3_cross_region_replication && var.notification_email != "" ? 1 : 0
  provider            = aws.primary
  alarm_name          = "${var.project_name}-s3-replication-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name        = "ReplicationLatency"
  namespace          = "AWS/S3"
  period             = "300"
  statistic          = "Average"
  threshold          = "900"  # 15 minutes
  alarm_description  = "This metric monitors S3 cross-region replication latency"
  alarm_actions      = [aws_sns_topic.dr_notifications[0].arn]

  dimensions = {
    SourceBucket      = aws_s3_bucket.primary_bucket.bucket
    DestinationBucket = aws_s3_bucket.secondary_bucket.bucket
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-s3-replication-alarm"
  })
}

# S3 Bucket Notifications for monitoring uploads
resource "aws_s3_bucket_notification" "primary_bucket_notification" {
  count    = var.notification_email != "" ? 1 : 0
  provider = aws.primary
  bucket   = aws_s3_bucket.primary_bucket.id

  topic {
    topic_arn = aws_sns_topic.dr_notifications[0].arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_sns_topic_policy.s3_notification_policy]
}

# SNS Topic Policy to allow S3 to publish
resource "aws_sns_topic_policy" "s3_notification_policy" {
  count = var.notification_email != "" ? 1 : 0
  arn   = aws_sns_topic.dr_notifications[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.dr_notifications[0].arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Outputs for S3 buckets
output "primary_s3_bucket" {
  description = "Primary S3 bucket name"
  value       = aws_s3_bucket.primary_bucket.bucket
}

output "secondary_s3_bucket" {
  description = "Secondary S3 bucket name"
  value       = aws_s3_bucket.secondary_bucket.bucket
}

output "primary_s3_bucket_arn" {
  description = "Primary S3 bucket ARN"
  value       = aws_s3_bucket.primary_bucket.arn
}

output "secondary_s3_bucket_arn" {
  description = "Secondary S3 bucket ARN"
  value       = aws_s3_bucket.secondary_bucket.arn
}
