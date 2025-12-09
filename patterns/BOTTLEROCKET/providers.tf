terraform {
  required_version = ">= 1.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.23.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.4"
    }

    helm = {
      source = "hashicorp/helm"
      version = "2.17.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.38.0"
    }

  }
}

# AWS Provider configuration
provider "aws" {
  region = var.aws_region
}

# AuthN so Helm Can Install Charts
provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name]
    }

  }
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name]
  }

}

# Get AWS account ID
data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}
