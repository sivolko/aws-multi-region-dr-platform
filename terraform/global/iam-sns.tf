# SNS Topic for DR Notifications
resource "aws_sns_topic" "dr_notifications" {
  count = var.notification_email != "" ? 1 : 0
  name  = "${var.project_name}-dr-notifications"

  tags = merge(var.tags, {
    Name = "${var.project_name}-dr-notifications"
  })
}

# SNS Topic Subscription
resource "aws_sns_topic_subscription" "email_notification" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.dr_notifications[0].arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# IAM Role for Lambda DR Functions
resource "aws_iam_role" "dr_lambda_role" {
  name = "${var.project_name}-dr-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-dr-lambda-role"
  })
}

# IAM Policy for DR Lambda Functions
resource "aws_iam_role_policy" "dr_lambda_policy" {
  name = "${var.project_name}-dr-lambda-policy"
  role = aws_iam_role.dr_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:PromoteReadReplica",
          "rds:ModifyDBInstance",
          "rds:CreateDBInstanceReadReplica"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:GetChange",
          "route53:ListResourceRecordSets"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeClusters",
          "ecs:ListServices"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.notification_email != "" ? aws_sns_topic.dr_notifications[0].arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      }
    ]
  })
}

# IAM Role for ECS Tasks
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-ecs-task-role"
  })
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-ecs-execution-role"
  })
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Policy for ECS Tasks (application permissions)
resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "${var.project_name}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*",
          "arn:aws:s3:::${var.project_name}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = var.notification_email != "" ? aws_sns_topic.dr_notifications[0].arn : "*"
      }
    ]
  })
}

# IAM Role for S3 Cross-Region Replication
resource "aws_iam_role" "s3_replication_role" {
  count = var.enable_s3_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-s3-replication-role"
  })
}

# IAM Policy for S3 Cross-Region Replication
resource "aws_iam_role_policy" "s3_replication_policy" {
  count = var.enable_s3_cross_region_replication ? 1 : 0
  name  = "${var.project_name}-s3-replication-policy"
  role  = aws_iam_role.s3_replication_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*/*"
      }
    ]
  })
}

# KMS Key for Encryption
resource "aws_kms_key" "dr_platform_key" {
  description             = "KMS key for DR platform encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow use of the key"
        Effect = "Allow"
        Principal = {
          AWS = [
            aws_iam_role.dr_lambda_role.arn,
            aws_iam_role.ecs_task_role.arn,
            aws_iam_role.ecs_execution_role.arn
          ]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-kms-key"
  })
}

resource "aws_kms_alias" "dr_platform_key_alias" {
  name          = "alias/${var.project_name}-key"
  target_key_id = aws_kms_key.dr_platform_key.key_id
}

# Outputs
output "sns_topic_arn" {
  description = "SNS topic ARN for DR notifications"
  value       = var.notification_email != "" ? aws_sns_topic.dr_notifications[0].arn : null
}

output "dr_lambda_role_arn" {
  description = "IAM role ARN for DR Lambda functions"
  value       = aws_iam_role.dr_lambda_role.arn
}

output "ecs_task_role_arn" {
  description = "IAM role ARN for ECS tasks"
  value       = aws_iam_role.ecs_task_role.arn
}

output "ecs_execution_role_arn" {
  description = "IAM role ARN for ECS task execution"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "s3_replication_role_arn" {
  description = "IAM role ARN for S3 cross-region replication"
  value       = var.enable_s3_cross_region_replication ? aws_iam_role.s3_replication_role[0].arn : null
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = aws_kms_key.dr_platform_key.arn
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = aws_kms_key.dr_platform_key.key_id
}
