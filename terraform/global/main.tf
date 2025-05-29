terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Default provider (for global resources)
provider "aws" {
  region = "us-east-1"
  alias  = "primary"
  
  default_tags {
    tags = {
      Project     = "multi-region-dr-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
      CostCenter  = "disaster-recovery"
    }
  }
}

# Secondary region provider
provider "aws" {
  region = "us-west-2"
  alias  = "secondary"
  
  default_tags {
    tags = {
      Project     = "multi-region-dr-platform"
      Environment = var.environment
      ManagedBy   = "terraform"
      CostCenter  = "disaster-recovery"
    }
  }
}

# Get current AWS account information
data "aws_caller_identity" "current" {}

# Get available AZs for primary region
data "aws_availability_zones" "primary" {
  provider = aws.primary
  state    = "available"
}

# Get available AZs for secondary region  
data "aws_availability_zones" "secondary" {
  provider = aws.secondary
  state    = "available"
}
