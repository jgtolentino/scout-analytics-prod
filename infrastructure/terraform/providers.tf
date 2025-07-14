terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.3"
    }
  }

  backend "s3" {
    bucket         = "scout-analytics-tfstate"
    key            = "production/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "scout-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "Scout Analytics"
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }
}