# Define required providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS provider
provider "aws" {
  region     = "us-east-1"  # Specify your desired AWS region
}

# Create an ECR repository
resource "aws_ecr_repository" "app_ecr_repo" {
  name = "app-repo"
  force_delete = true
}
