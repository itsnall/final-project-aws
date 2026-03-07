terraform {
  required_version = ">= 1.0.0"

  # Konfigurasi Backend (Pastikan Bucket & DynamoDB sudah dibuat di Console)
  backend "s3" {
    bucket         = "eduflow-tfstate-final-project"
    key            = "final/terraform.tfstate"
    region         = "ap-southeast-1" # Sesuaikan region
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}