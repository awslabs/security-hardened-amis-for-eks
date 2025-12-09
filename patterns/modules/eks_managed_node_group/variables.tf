variable "name" {
  description = "Name of the EKS managed node group"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}

variable "cluster_primary_security_group_id" {
  description = "The ID of the EKS cluster primary security group"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "cluster_service_cidr" {
  description = "The CIDR block for Kubernetes services"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "iam_role_additional_policies" {
  description = "Additional IAM policies for the node group role"
  type        = map(string)
  default = {
    AmazonSSMManagedInstanceCore     = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    AmazonInspector2ManagedCisPolicy = "arn:aws:iam::aws:policy/AmazonInspector2ManagedCisPolicy"
    AmazonEBSCSIDriverPolicy         = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }
}

variable "ami_id" {
  description = "The AMI ID for the EKS managed node group"
  type        = string
}

variable "instance_types" {
  description = "List of instance types for the EKS managed node group"
  type        = list(string)
  default     = ["m6i.large", "m5.large", "m5zn.large"]
}

variable "capacity_type" {
  description = "Type of capacity associated with the EKS Node Group"
  type        = string
  default     = "SPOT"
}

variable "force_update_version" {
  description = "Force version update if existing pods are unable to be drained"
  type        = bool
  default     = true
}

variable "enable_bootstrap_user_data" {
  description = "Enable bootstrap user data"
  type        = bool
  default     = true
}

variable "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API"
  type        = string
}

variable "cluster_auth_base64" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  type        = string
}

variable "ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "min_size" {
  description = "Minimum number of instances/nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances/nodes"
  type        = number
  default     = 1
}

variable "desired_size" {
  description = "Desired number of instances/nodes"
  type        = number
  default     = 1
}

variable "bootstrap_extra_args" {
  description = "Extra bootstrap settings for Bottlerocket nodes"
  type        = string
  default     = "" # Empty string as default if no bootstrap extra settings are needed
}

variable "pre_bootstrap_user_data" {
  description = "Extra bootstrap settings for CIS AMIs nodes"
  type        = string
  default     = "" # Empty string as default if no bootstrap extra settings are needed
}

variable "cloudinit_pre_nodeadm" {
  description = "List of cloud-init scripts to run before nodeadm initialization"
  type = list(object({
    content      = string
    content_type = optional(string)
    filename     = optional(string)
    merge_type   = optional(string)
  }))
  default = []
}