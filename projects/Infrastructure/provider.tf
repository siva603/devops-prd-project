terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote State Storage in Amazon S3 (100% S3 Only - Free Tier Friendly)
  # Pass bucket dynamically: terraform init -backend-config="bucket=boutique-terraform-state-<ACCOUNT_ID>"
  backend "s3" {
    key     = "boutique/infrastructure/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.region
}
