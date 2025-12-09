
data "aws_ssm_parameter" "vpc_id" {
  name = "/${var.name}/vpc_id"
}

data "aws_ssm_parameter" "private_subnets" {
  name = "/${var.name}/private_subnets"
}

################################################################################
# EKS CLUSTER
################################################################################


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.10.0"
  name = var.name
  kubernetes_version = var.cluster_version
  endpoint_public_access = true
  
  # Give the Terraform identity admin access to the cluster
  # which will allow resources to be deployed into the cluster
  
  enable_cluster_creator_admin_permissions = true
  vpc_id = data.aws_ssm_parameter.vpc_id.value
  subnet_ids = tolist(split(",", data.aws_ssm_parameter.private_subnets.value))
  tags = var.tags
  addons = var.cluster_addons
}