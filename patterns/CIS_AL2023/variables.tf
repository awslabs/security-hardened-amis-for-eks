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
  default     = "CIS_AL2023"
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

variable "branch" {
  description = "EKS AMI Branch TAG" ## For Example: https://github.com/awslabs/amazon-eks-ami/releases/tag/v20251120 ## Check and Update During Monthly Release.
  type        = string
  default     = "v20251120" 
}

variable "cis_ami_name_level_1" {
  description = "CIS AMI Name which will be use to Search the CIS AMI from Market Place" ## Check and Update During Monthly Release.
  type        = string
  default     = "CIS Amazon Linux 2023 Benchmark - Level 1 - v11*"
}

variable "cis_ami_name_level_2" {
  description = "CIS AMI Name which will be use to Search the CIS AMI from Market Place" ## Check and Update During Monthly Release v07 if needed.
  type        = string
  default     = "CIS Amazon Linux 2023 Benchmark - Level 2 - v11*"
}