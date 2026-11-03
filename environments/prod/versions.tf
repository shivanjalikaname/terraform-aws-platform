terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.71"
    }
  }

  # Native S3 state locking (Terraform 1.10+), no DynamoDB table needed.
  # Create the bucket once, e.g. with the remote-state-bootstrap module in shivanjalikaname/devops-toolkit.
  backend "s3" {
    bucket       = "example-terraform-state-123456789012"
    key          = "platform/prod/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = local.tags
  }
}
