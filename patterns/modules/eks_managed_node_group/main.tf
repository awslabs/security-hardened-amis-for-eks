module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "21.10.0"

  name                              = var.name
  cluster_name                      = var.cluster_name
  kubernetes_version                = var.kubernetes_version
  subnet_ids                        = var.subnet_ids
  cluster_primary_security_group_id = var.cluster_primary_security_group_id
  vpc_security_group_ids           = var.vpc_security_group_ids
  cluster_service_cidr             = var.cluster_service_cidr  # Must match the cluster_service_ipv4_cidr
  iam_role_additional_policies     = var.iam_role_additional_policies

  ami_id                      = var.ami_id
  instance_types              = var.instance_types
  capacity_type               = var.capacity_type
  force_update_version        = var.force_update_version
  enable_bootstrap_user_data  = var.enable_bootstrap_user_data
  pre_bootstrap_user_data     = var.pre_bootstrap_user_data
  cluster_endpoint            = var.cluster_endpoint
  cluster_auth_base64         = var.cluster_auth_base64
  ami_type                    = var.ami_type

  min_size     = var.min_size
  max_size     = var.max_size
  desired_size = var.desired_size
  create_launch_template = true
  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # Enforce IMDSv2
    http_put_response_hop_limit = 2          # Set hop limit to 2
    instance_metadata_tags      = "enabled"
  }
}
