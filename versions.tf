terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "tf-vpc-foundation-tfstate-327573816902"
    key            = "tf-vpc-foundation/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-vpc-foundation-tf-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}