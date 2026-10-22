################################################################################
# Local Values
################################################################################
locals {
  # Common tags applied to all resources for cost allocation, ownership tracking,
  # and resource discovery. Override or extend via var.additional_tags.
  common_tags = merge(
    {
      ManagedBy   = "Terraform"
      Pattern     = "CIS_AL2023"
      Environment = var.environment
    },
    var.additional_tags
  )

  # Hash of all template_files used to override upstream amazon-eks-ami files.
  # Changes to any of these files force update_template to re-run.
  template_files_hash = sha1(join("", [
    for f in fileset("${path.module}/template_files", "**") :
    filesha1("${path.module}/template_files/${f}")
  ]))

  # Resolve hardened AMI IDs from the most recent matching image. If no
  # matching AMI exists yet (e.g. first plan, or after image deregistration
  # during destroy), fall back to a placeholder. Real consumption gates on
  # the null_resource that creates the AMI, so this only applies in transient
  # plan-time states.
  ami_id_level_1 = length(data.aws_ami_ids.cis_amazon_linux_2023_benchmark_level_1.ids) > 0 ? data.aws_ami_ids.cis_amazon_linux_2023_benchmark_level_1.ids[0] : "ami-00000000000000000"
  ami_id_level_2 = length(data.aws_ami_ids.cis_amazon_linux_2023_benchmark_level_2.ids) > 0 ? data.aws_ami_ids.cis_amazon_linux_2023_benchmark_level_2.ids[0] : "ami-00000000000000000"

  # Shared cloud-init script for both node groups (kubelet 10250 + nftables).
  cloudinit_pre_nodeadm = [
    {
      content_type = "text/x-shellscript; charset=\"us-ascii\""
      content      = <<-EOT
            #!/usr/bin/env bash
            set -ex # Added to log execution to /var/log/cloud-init-output.log

            # Update iptables
            iptables -I INPUT 1 -p tcp --dport 10250 -j ACCEPT

            # Update nftables - No backslashes before semicolons
            nft add rule inet filter input tcp dport 10250 accept
            nft chain inet filter forward { policy accept \; }
            nft chain inet filter output { policy accept \; }

          EOT
    }
  ]
}

################################################################################
# VPC and Networking Resources
################################################################################
module "vpc" {
  source = "../modules/vpc"
  name   = var.name
  azs    = slice(data.aws_availability_zones.available.names, 0, 3)
  tags   = local.common_tags
}

################################################################################
# Create Packer Role
################################################################################
module "packer_role" {
  source     = "../modules/packer-role"
  name       = var.name
  account_id = data.aws_caller_identity.current.account_id
}

################################################################################
# Resource to clone repo and update template.json and Cleanup.sh
#
# Triggers fire when var.branch changes or any local template_files/* is
# modified. Replaces the previous timestamp() trigger which ran on every
# apply.
################################################################################
resource "null_resource" "update_template" {
  triggers = {
    branch              = var.branch
    template_files_hash = local.template_files_hash
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if [ ! -d "amazon-eks-ami" ]; then
        git clone https://github.com/awslabs/amazon-eks-ami.git --branch "$BRANCH"
      fi
      cd amazon-eks-ami
      # As of amazon-eks-ami v20261012 the al2023 build is HCL2 (template.pkr.hcl +
      # variables-default.pkrvars.hcl). The upstream template now natively supports
      # remote_folder/working_dir/expect_disconnect, so we no longer override the
      # template or variables files; remote_folder is passed as a make -var in the
      # build steps below. We only overlay our sudo'd provisioner scripts.
      cp ../template_files/install-worker.sh templates/al2023/provisioners/install-worker.sh
      cp ../template_files/cache-pause-container templates/al2023/runtime/bin/cache-pause-container
      cp ../template_files/cache-pause-container.sh templates/al2023/provisioners/cache-pause-container.sh
      cp ../template_files/configure-selinux.sh templates/al2023/provisioners/configure-selinux.sh
      cp ../template_files/generate-version-info.sh templates/al2023/provisioners/generate-version-info.sh
      cp ../template_files/install-efa.sh templates/al2023/provisioners/install-efa.sh
      cp ../template_files/set-clocksource.sh templates/al2023/provisioners/set-clocksource.sh
      cp ../template_files/limit-c-states.sh templates/al2023/provisioners/limit-c-states.sh
      cp ../template_files/cleanup.sh templates/al2023/provisioners/cleanup.sh
    EOT
    environment = {
      BRANCH = var.branch
    }
  }
}

################################################################################
# Create Hardened AMI CIS_Amazon_Linux_2023_Benchmark_Level_1
#
# Triggers fire when the upstream branch, template files, or related vars
# change. Builds are intentionally not triggered on every apply (the previous
# timestamp() trigger caused 20-30 min Packer runs on no-op applies).
################################################################################
resource "null_resource" "create_hardened_ami_level_1" {
  depends_on = [module.vpc, null_resource.update_template, module.packer_role]

  triggers = {
    branch              = var.branch
    template_files_hash = local.template_files_hash
    aws_region          = var.aws_region
    cis_ami_name        = var.cis_ami_name_level_1
    name                = var.name
    cluster_version     = var.cluster_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      packer plugins install github.com/hashicorp/amazon || true

      cd amazon-eks-ami
      timestamp=$(date +%s)
      ami_name="CIS_Amazon_Linux_2023_Benchmark_Level_1-$timestamp"

      AMI_ID=$(aws ec2 describe-images \
        --owners aws-marketplace \
        --filters "Name=architecture,Values=x86_64" "Name=name,Values=$CIS_AMI_NAME" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --region "$AWS_REGION" \
        --output text)

      PACKER_BINARY=packer make k8s="$CLUSTER_VERSION" \
        os_distro=al2023 \
        aws_region="$AWS_REGION" \
        source_ami_id="$AMI_ID" \
        source_ami_owners=679593333241 \
        source_ami_filter_name="$CIS_AMI_NAME" \
        AMI_VARIANT=amazon-eks-cis \
        subnet_id="$SUBNET_ID" \
        associate_public_ip_address=true \
        remote_folder=/home/ec2-user \
        ami_name="$ami_name" \
        iam_instance_profile="$INSTANCE_PROFILE" \
        pause_container_image="$PAUSE_IMAGE" \
        run_tags="Name=$RESOURCE_NAME"

      AMI_ID_Level_1=$(jq -r '(.builds | reverse[]) | select(.custom_data.source_ami_name | contains("Level 1")) | .artifact_id | split(":")[1]' manifest.json | head -n1)
      echo "Built Level 1 AMI: $AMI_ID_Level_1"
    EOT
    environment = {
      AWS_REGION       = var.aws_region
      SUBNET_ID        = module.vpc.public_subnets[0]
      CIS_AMI_NAME     = var.cis_ami_name_level_1
      RESOURCE_NAME    = var.name
      INSTANCE_PROFILE = module.packer_role.instance_profile_name
      PAUSE_IMAGE      = "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/eks/pause:3.10"
      CLUSTER_VERSION  = var.cluster_version
    }
  }
}

################################################################################
# Create Hardened AMI CIS_Amazon_Linux_2023_Benchmark_Level_2
################################################################################
resource "null_resource" "create_hardened_ami_level_2" {
  depends_on = [module.vpc, null_resource.update_template, module.packer_role]

  triggers = {
    branch              = var.branch
    template_files_hash = local.template_files_hash
    aws_region          = var.aws_region
    cis_ami_name        = var.cis_ami_name_level_2
    name                = var.name
    cluster_version     = var.cluster_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      packer plugins install github.com/hashicorp/amazon || true

      cd amazon-eks-ami
      timestamp=$(date +%s)
      ami_name="CIS_Amazon_Linux_2023_Benchmark_Level_2-$timestamp"

      AMI_ID=$(aws ec2 describe-images \
        --owners aws-marketplace \
        --filters "Name=architecture,Values=x86_64" "Name=name,Values=$CIS_AMI_NAME" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --region "$AWS_REGION" \
        --output text)

      PACKER_BINARY=packer make k8s="$CLUSTER_VERSION" \
        os_distro=al2023 \
        aws_region="$AWS_REGION" \
        source_ami_id="$AMI_ID" \
        source_ami_owners=679593333241 \
        source_ami_filter_name="$CIS_AMI_NAME" \
        subnet_id="$SUBNET_ID" \
        associate_public_ip_address=true \
        remote_folder=/home/ec2-user \
        ami_name="$ami_name" \
        iam_instance_profile="$INSTANCE_PROFILE" \
        pause_container_image="$PAUSE_IMAGE" \
        run_tags="Name=$RESOURCE_NAME"

      AMI_ID_Level_2=$(jq -r '(.builds | reverse[]) | select(.custom_data.source_ami_name | contains("Level 2")) | .artifact_id | split(":")[1]' manifest.json | head -n1)
      echo "Built Level 2 AMI: $AMI_ID_Level_2"
    EOT
    environment = {
      AWS_REGION       = var.aws_region
      SUBNET_ID        = module.vpc.public_subnets[0]
      CIS_AMI_NAME     = var.cis_ami_name_level_2
      RESOURCE_NAME    = var.name
      INSTANCE_PROFILE = module.packer_role.instance_profile_name
      PAUSE_IMAGE      = "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/eks/pause:3.10"
      CLUSTER_VERSION  = var.cluster_version
    }
  }
}

################################################################################
# EKS Cluster
################################################################################
module "eks_cluster" {
  source          = "../modules/eks-cluster"
  depends_on      = [module.vpc]
  name            = var.name
  cluster_version = var.cluster_version
  tags            = local.common_tags
}

################################################################################
# EKS Managed Node Group For AL2023 CIS Level 1
################################################################################
module "eks_managed_node_group_level_1" {
  source     = "../modules/eks_managed_node_group"
  depends_on = [module.eks_cluster, null_resource.create_hardened_ami_level_1]

  name                              = "CISAL2023BL1"
  cluster_name                      = module.eks_cluster.cluster_name
  cluster_version                   = module.eks_cluster.cluster_version
  kubernetes_version                = module.eks_cluster.cluster_version
  subnet_ids                        = module.vpc.private_subnets
  cluster_primary_security_group_id = module.eks_cluster.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks_cluster.node_security_group_id]
  cluster_service_cidr              = module.eks_cluster.cluster_service_cidr
  ami_id                            = local.ami_id_level_1
  ami_type                          = "AL2023_x86_64_STANDARD"
  cluster_endpoint                  = module.eks_cluster.cluster_endpoint
  cluster_auth_base64               = module.eks_cluster.cluster_certificate_authority_data
  cloudinit_pre_nodeadm             = local.cloudinit_pre_nodeadm
  instance_types                    = var.instance_types
  capacity_type                     = var.capacity_type
  tags                              = merge(local.common_tags, { CISLevel = "Level_1" })
}

################################################################################
# EKS Managed Node Group For AL2023 CIS Level 2
################################################################################
module "eks_managed_node_group_level_2" {
  source     = "../modules/eks_managed_node_group"
  depends_on = [module.eks_cluster, null_resource.create_hardened_ami_level_2]

  name                              = "CISAL2023BL2"
  cluster_name                      = module.eks_cluster.cluster_name
  cluster_version                   = module.eks_cluster.cluster_version
  kubernetes_version                = module.eks_cluster.cluster_version
  subnet_ids                        = module.vpc.private_subnets
  cluster_primary_security_group_id = module.eks_cluster.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks_cluster.node_security_group_id]
  cluster_service_cidr              = module.eks_cluster.cluster_service_cidr
  ami_id                            = local.ami_id_level_2
  ami_type                          = "AL2023_x86_64_STANDARD"
  cluster_endpoint                  = module.eks_cluster.cluster_endpoint
  cluster_auth_base64               = module.eks_cluster.cluster_certificate_authority_data
  cloudinit_pre_nodeadm             = local.cloudinit_pre_nodeadm
  instance_types                    = var.instance_types
  capacity_type                     = var.capacity_type
  tags                              = merge(local.common_tags, { CISLevel = "Level_2" })
}

################################################################################
# EKS Add-ons
################################################################################
module "eks_blueprints_addons" {
  depends_on = [module.eks_cluster, module.eks_managed_node_group_level_1, module.eks_managed_node_group_level_2]
  source     = "../modules/eks-addons"

  cluster_name      = module.eks_cluster.cluster_name
  cluster_endpoint  = module.eks_cluster.cluster_endpoint
  cluster_version   = module.eks_cluster.cluster_version
  oidc_provider_arn = module.eks_cluster.oidc_provider_arn
  tags              = local.common_tags
}

################################################################################
# Run CIS SCAN AWS Inspector
#
# Triggers are tied to meaningful state (node group identities) rather than
# timestamp() so the scan only re-runs when the thing being scanned actually
# changes. To force an ad-hoc scan, taint the resource:
#   terraform apply -replace=null_resource.run_cis_scan
################################################################################
resource "null_resource" "run_cis_scan" {
  depends_on = [module.eks_managed_node_group_level_1, module.eks_managed_node_group_level_2]
  triggers = {
    cluster_name     = var.name
    node_group_id_l1 = module.eks_managed_node_group_level_1.node_group_id
    node_group_id_l2 = module.eks_managed_node_group_level_2.node_group_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      echo "Initiating CIS scan using AWS Inspector..."
      echo "Account ID: $ACCOUNT_ID"
      SCAN_ARN=$(aws inspector2 create-cis-scan-configuration \
        --scan-name "$RESOURCE_NAME" \
        --schedule "oneTime={}" \
        --security-level LEVEL_2 \
        --targets "accountIds=$ACCOUNT_ID,targetResourceTags={eks:cluster-name=$RESOURCE_NAME}" \
        --region "$AWS_REGION" \
        --query 'scanArn' \
        --output text)

      if [ -z "$SCAN_ARN" ]; then
        echo "Error: Failed to create CIS scan configuration"
        exit 1
      fi

      echo "Successfully created CIS scan"
    EOT
    environment = {
      AWS_REGION    = var.aws_region
      RESOURCE_NAME = var.name
      ACCOUNT_ID    = data.aws_caller_identity.current.account_id
    }
  }
}

################################################################################
# Standalone AMI-only builds
#
# These resources build hardened AMIs WITHOUT creating a VPC or EKS cluster.
# Use them when you only want to produce an AMI for use elsewhere, e.g.:
#
#   terraform apply -var=create_ami_level1=true \
#                   -var=public_subnet_id=subnet-abc123 \
#                   -target=null_resource.only_create_hardened_ami_level_1
#
# Both create_ami_levelN and a valid public_subnet_id must be supplied.
################################################################################
resource "null_resource" "only_create_hardened_ami_level_1" {
  count      = var.create_ami_level1 ? 1 : 0
  depends_on = [null_resource.update_template, module.packer_role]

  triggers = {
    branch              = var.branch
    template_files_hash = local.template_files_hash
    aws_region          = var.aws_region
    cis_ami_name        = var.cis_ami_name_level_1
    name                = var.name
    subnet_id           = var.public_subnet_id
    cluster_version     = var.cluster_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if [ -z "$SUBNET_ID" ]; then
        echo "Error: public_subnet_id must be provided for AMI-only builds."
        exit 1
      fi
      packer plugins install github.com/hashicorp/amazon || true

      cd amazon-eks-ami
      timestamp=$(date +%s)
      ami_name="CIS_Amazon_Linux_2023_Benchmark_Level_1-$timestamp"

      AMI_ID=$(aws ec2 describe-images \
        --owners aws-marketplace \
        --filters "Name=architecture,Values=x86_64" "Name=name,Values=$CIS_AMI_NAME" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --region "$AWS_REGION" \
        --output text)

      PACKER_BINARY=packer make k8s="$CLUSTER_VERSION" \
        os_distro=al2023 \
        aws_region="$AWS_REGION" \
        source_ami_id="$AMI_ID" \
        source_ami_owners=679593333241 \
        source_ami_filter_name="$CIS_AMI_NAME" \
        AMI_VARIANT=amazon-eks-cis \
        subnet_id="$SUBNET_ID" \
        associate_public_ip_address=true \
        remote_folder=/home/ec2-user \
        ami_name="$ami_name" \
        iam_instance_profile="$INSTANCE_PROFILE" \
        pause_container_image="$PAUSE_IMAGE" \
        run_tags="Name=$RESOURCE_NAME"

      AMI_ID_Level_1=$(jq -r '(.builds | reverse[]) | select(.custom_data.source_ami_name | contains("Level 1")) | .artifact_id | split(":")[1]' manifest.json | head -n1)
      echo "Built Level 1 AMI: $AMI_ID_Level_1"
    EOT
    environment = {
      AWS_REGION       = var.aws_region
      SUBNET_ID        = var.public_subnet_id
      CIS_AMI_NAME     = var.cis_ami_name_level_1
      RESOURCE_NAME    = var.name
      INSTANCE_PROFILE = module.packer_role.instance_profile_name
      PAUSE_IMAGE      = "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/eks/pause:3.10"
      CLUSTER_VERSION  = var.cluster_version
    }
  }
}

resource "null_resource" "only_create_hardened_ami_level_2" {
  count      = var.create_ami_level2 ? 1 : 0
  depends_on = [null_resource.update_template, module.packer_role]

  triggers = {
    branch              = var.branch
    template_files_hash = local.template_files_hash
    aws_region          = var.aws_region
    cis_ami_name        = var.cis_ami_name_level_2
    name                = var.name
    subnet_id           = var.public_subnet_id
    cluster_version     = var.cluster_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      if [ -z "$SUBNET_ID" ]; then
        echo "Error: public_subnet_id must be provided for AMI-only builds."
        exit 1
      fi
      packer plugins install github.com/hashicorp/amazon || true

      cd amazon-eks-ami
      timestamp=$(date +%s)
      ami_name="CIS_Amazon_Linux_2023_Benchmark_Level_2-$timestamp"

      AMI_ID=$(aws ec2 describe-images \
        --owners aws-marketplace \
        --filters "Name=architecture,Values=x86_64" "Name=name,Values=$CIS_AMI_NAME" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --region "$AWS_REGION" \
        --output text)

      PACKER_BINARY=packer make k8s="$CLUSTER_VERSION" \
        os_distro=al2023 \
        aws_region="$AWS_REGION" \
        source_ami_id="$AMI_ID" \
        source_ami_owners=679593333241 \
        source_ami_filter_name="$CIS_AMI_NAME" \
        subnet_id="$SUBNET_ID" \
        associate_public_ip_address=true \
        remote_folder=/home/ec2-user \
        ami_name="$ami_name" \
        iam_instance_profile="$INSTANCE_PROFILE" \
        pause_container_image="$PAUSE_IMAGE" \
        run_tags="Name=$RESOURCE_NAME"

      AMI_ID_Level_2=$(jq -r '(.builds | reverse[]) | select(.custom_data.source_ami_name | contains("Level 2")) | .artifact_id | split(":")[1]' manifest.json | head -n1)
      echo "Built Level 2 AMI: $AMI_ID_Level_2"
    EOT
    environment = {
      AWS_REGION       = var.aws_region
      SUBNET_ID        = var.public_subnet_id
      CIS_AMI_NAME     = var.cis_ami_name_level_2
      RESOURCE_NAME    = var.name
      INSTANCE_PROFILE = module.packer_role.instance_profile_name
      PAUSE_IMAGE      = "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/eks/pause:3.10"
      CLUSTER_VERSION  = var.cluster_version
    }
  }
}
