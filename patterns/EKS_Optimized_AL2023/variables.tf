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
  default     = "EKS_Optimized_AL2023"
}

variable "create_ami_level1" {
  description = "Flag to create Level 1 Hardened AMI"
  type        = bool
  default     = false
}

variable "create_ami_level2" {
  description = "Flag to create Level 2 Hardened AMI"
  type        = bool
  default     = false
}

variable "public_subnet_id" {
  description = "Public subnet ID for AMI creation"
  type        = string
  default     = ""
}