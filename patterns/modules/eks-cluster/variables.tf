variable "create" {
  description = "Controls if resources should be created (affects nearly all resources)"
  type        = bool
  default     = true
}

variable "name" {
  type        = string
  description = "The projects name."
  default     = "cis-cluster"
}

variable "cluster_version" {
  type        = string
  description = "EKS Cluster version."
  default     = "1.32"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "cluster_addons" {
  description = "Map of cluster addon configurations to enable for the cluster. Addon name can be the map keys or set with `name`"
  type        = any
  default = {
    kube-proxy = {}
    vpc-cni = {
      most_recent    = true
      before_compute = true
      resolve_conflicts_on_create = "OVERWRITE" ## Addon Deployment was failing due to a Conflict. By Default OVERWRITE was on Update.
    }
  }
}
