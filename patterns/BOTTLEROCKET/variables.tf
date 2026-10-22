variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "Must be a valid AWS region identifier (e.g., us-west-2)."
  }
}

variable "cluster_version" {
  description = "EKS Cluster Version"
  type        = string
  default     = "1.37"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.cluster_version))
    error_message = "Cluster version must match the pattern 'MAJOR.MINOR' (e.g., 1.35)."
  }
}

variable "name" {
  description = "Name Prefix"
  type        = string
  default     = "BOTTLEROCKET"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.name))
    error_message = "Name must only contain alphanumeric characters, hyphens, and underscores."
  }
}

variable "ecr_repository_name" {
  description = "ECR Repository Name"
  type        = string
  default     = "bottlerocket-cis-bootstrap-image"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._/-]*$", var.ecr_repository_name))
    error_message = "ECR repository name must contain only lowercase letters, numbers, dots, hyphens, underscores, and forward slashes."
  }
}

variable "image_tag" {
  description = "CIS Level 2 Bootstrap Image Tag. If empty, a content-hash of the Dockerfile is used (recommended for IMMUTABLE repos)."
  type        = string
  default     = ""

  validation {
    condition     = var.image_tag == "" || can(regex("^[a-zA-Z0-9._-]+$", var.image_tag))
    error_message = "Image tag must only contain alphanumeric characters, dots, hyphens, and underscores (or be empty for auto-hash)."
  }
}
