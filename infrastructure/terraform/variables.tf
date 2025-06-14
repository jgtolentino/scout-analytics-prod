variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "service_name" {
  description = "Service name prefix"
  type        = string
  default     = "scout-analytics"
}

variable "retailbot_image" {
  description = "Docker image for RetailBot API"
  type        = string
}

variable "dashboard_image" {
  description = "Docker image for Dashboard"
  type        = string
}

variable "database_username" {
  description = "RDS master username"
  type        = string
  sensitive   = true
}

variable "database_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}