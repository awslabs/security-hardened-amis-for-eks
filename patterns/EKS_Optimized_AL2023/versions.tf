terraform {
  required_version = ">= 1.3"

  backend "s3" {
    bucket  = "BUCKET_NAME"
    key     = "EKS_Optimized_AL2023"
    region  = "us-west-2"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.69.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}
