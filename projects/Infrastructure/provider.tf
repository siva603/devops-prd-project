terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Enterprise Standard: Remote State Storage with S3 and DynamoDB State Locking
  # Real IT companies never store terraform.tfstate locally.
  # Pass bucket dynamically: terraform init -backend-config="bucket=boutique-terraform-state-<ACCOUNT_ID>"
  backend "s3" {
    key            = "boutique/infrastructure/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "boutique-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
