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
  default     = "EKS_Optimized_AL2023"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.name))
    error_message = "Name must only contain alphanumeric characters, hyphens, and underscores."
  }
}

variable "instance_types" {
  description = "List of EC2 instance types for the EKS managed node groups. Provide multiple types for Spot diversification."
  type        = list(string)
  default     = ["m6i.large", "m5.large", "m5zn.large"]

  validation {
    condition     = length(var.instance_types) > 0
    error_message = "At least one instance type must be provided."
  }
}

variable "capacity_type" {
  description = "Type of capacity for the EKS managed node groups. ON_DEMAND for stability (recommended for CIS scanning), SPOT for cost savings."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "capacity_type must be either ON_DEMAND or SPOT."
  }
}

variable "environment" {
  description = "Environment name applied as a tag to all resources (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.environment))
    error_message = "Environment must only contain alphanumeric characters, hyphens, and underscores."
  }
}

variable "additional_tags" {
  description = "Additional tags to merge with common_tags. Use this to add team, cost-center, project, etc."
  type        = map(string)
  default     = {}
}

################################################################################
# Standalone "AMI-only" build flags
#
# These variables enable building hardened AMIs WITHOUT creating a VPC, EKS
# cluster, or node groups. Only used when targeting null_resource.only_create_*.
# Keep defaults at false so a normal `terraform apply` doesn't trigger them.
################################################################################

variable "create_ami_level1" {
  description = "When true and only_create_hardened_ami_level_1 is targeted, build a Level 1 hardened AMI without creating VPC/EKS resources."
  type        = bool
  default     = false
}

variable "create_ami_level2" {
  description = "When true and only_create_hardened_ami_level_2 is targeted, build a Level 2 hardened AMI without creating VPC/EKS resources."
  type        = bool
  default     = false
}

variable "public_subnet_id" {
  description = "Existing public subnet ID for Packer to use during AMI-only builds. Required when create_ami_level1 or create_ami_level2 is true."
  type        = string
  default     = ""

  validation {
    condition     = var.public_subnet_id == "" || can(regex("^subnet-[a-f0-9]+$", var.public_subnet_id))
    error_message = "Must be a valid subnet ID (subnet-xxxxxxxxx) or empty string."
  }
}
