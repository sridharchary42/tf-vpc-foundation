variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix/tag every resource."
  type        = string
  default     = "tf-vpc-foundation"
}

variable "environment" {
  description = "Environment tag — dev/staging/prod."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "IP range for the whole VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}