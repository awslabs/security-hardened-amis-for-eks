variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
  default     = "1.34"
}

variable "name" {
  description = "Name Prefix"
  type        = string
  default     = "BOTTLEROCKET"
}

variable "cis_bootstrape_image" {
  description = "Flag to create CIS Hardened Bootstrap Image"
  type        = bool
  default     = false
}

variable "ecr_repository_name" {
  description = "ECR Repository Name"
  type        = string
  default     = "bottlerocket-cis-bootstrap-image"
}

variable "image_tag" {
  description = "CIS Level 2 Bootstrape Image Tag"
  type        = string
  default     = "latest"
}