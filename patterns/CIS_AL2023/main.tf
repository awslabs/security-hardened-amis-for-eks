################################################################################
# VPC and Networking Resources
################################################################################
module "vpc" {
  source = "../modules/vpc"
  name   = var.name
  azs    = slice(data.aws_availability_zones.available.names, 0, 3)
}

################################################################################
# SSM Parameters
################################################################################
resource "aws_ssm_parameter" "cis_amazon_linux_2023_benchmark_level_1" {
  name  = "/cis_ami/${var.name}/CIS_Amazon_Linux_2023_Benchmark_Level_1/ami_id"
  type  = "String"
  value = "placeholder"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "cis_amazon_linux_2023_benchmark_level_2" {
  name  = "/cis_ami/${var.name}/CIS_Amazon_Linux_2023_Benchmark_Level_2/ami_id"
  type  = "String"
  value = "placeholder"

  lifecycle {
    ignore_changes = [value]
  }
}

################################################################################
# Create Packer Role
################################################################################
module "packer_role" {
  source = "../modules/packer-role"
  name = var.name
  account_id = data.aws_caller_identity.current.account_id
}

################################################################################
# Resource to clone repo and update template.json and Cleanup.sh
################################################################################
resource "null_resource" "update_template" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -d "amazon-eks-ami" ]; then
        git clone https://github.com/awslabs/amazon-eks-ami.git --branch ${var.branch}
      fi
      cd amazon-eks-ami
      echo "Waiting for PR https://github.com/awslabs/amazon-eks-ami/pull/1922"
      cp ../template.json templates/al2023/template.json
      cp ../cleanup.sh templates/shared/provisioners/cleanup.sh
      echo "sudo chmod 755 /usr/bin/kubelet" >> templates/al2023/provisioners/install-worker.sh
      # Function to apply sed commands based on OS
      apply_sed_commands() {
      OS=$(uname)
      if [ "$OS" = "Darwin" ]; then
          # Mac OS X commands
          echo "Applying changes for MacOS..."
          sed -i '' "s/chmod +x \$binary/chmod 755 \$binary/g" templates/al2023/provisioners/install-worker.sh
          sed -i '' 's#aws --version#sudo /bin//aws --version#g' templates/shared/provisioners/generate-version-info.sh
          sed -i '' 's#aws #sudo /bin//aws #g' templates/shared/runtime/bin/cache-pause-container
          sed -i '' 's#/tmp#/home/ec2-user#g' templates/al2023/variables-default.json
          sed -i '' 's#cache-pause-container#sudo cache-pause-container#g' templates/al2023/provisioners/cache-pause-container.sh
          sed -i '' 's#PARTITION=$(imds#sudo chmod 755 /usr/bin/imds\nPARTITION=$(imds#g' templates/al2023/provisioners/install-worker.sh
      else
          # Linux commands
          echo "Applying changes for Linux..."
          sed -i "s/chmod +x \$binary/chmod 755 \$binary/g" templates/al2023/provisioners/install-worker.sh
          sed -i 's#aws --version#sudo /bin//aws --version#g' templates/shared/provisioners/generate-version-info.sh
          sed -i 's#aws #sudo /bin//aws #g' templates/shared/runtime/bin/cache-pause-container
          sed -i 's#/tmp#/home/ec2-user#g' templates/al2023/variables-default.json
          sed -i 's#cache-pause-container#sudo cache-pause-container#g' templates/al2023/provisioners/cache-pause-container.sh
          sed -i 's#PARTITION=$(imds#sudo chmod 755 /usr/bin/imds\nPARTITION=$(imds#g' templates/al2023/provisioners/install-worker.sh

      fi
}
      # First apply the sed commands
      apply_sed_commands
    EOT
  }
}

################################################################################
# Create Hardened AMI EKS_Optimized_AL2023_Level_1
################################################################################
resource "null_resource" "create_hardened_ami_level_1" {
  depends_on = [module.vpc, aws_ssm_parameter.cis_amazon_linux_2023_benchmark_level_1, null_resource.update_template, module.packer_role]

  triggers = {
    always_run = timestamp()
    aws_region = var.aws_region

  }

  provisioner "local-exec" {
    command = <<-EOT

      packer plugins install github.com/hashicorp/amazon || true
      
      cd amazon-eks-ami
      timestamp=$(date +%s)
      ami_name="CIS_Amazon_Linux_2023_Benchmark_Level_1-$timestamp"
 
      AMI_ID=$(aws ec2 describe-images \
        --owners aws-marketplace \
        --filters "Name=architecture,Values=x86_64" "Name=name,Values=${var.cis_ami_name_level_1}" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --region ${var.aws_region} \
        --output text)
      
      PACKER_BINARY=packer make k8s=1.34 \
        os_distro=al2023 \
        aws_region=${var.aws_region} \
        source_ami_id=$AMI_ID \
        source_ami_owners=679593333241 \
        source_ami_filter_name="${var.cis_ami_name_level_1}" \
        AMI_VARIANT=amazon-eks-cis \
        subnet_id=${module.vpc.public_subnets[0]} \
        associate_public_ip_address=true \
        remote_folder=/home/ec2-user \
        ami_name=$ami_name \
        iam_instance_profile=packer-role-CIS_AL2023 \
        pause_container_image=602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/eks/pause:3.10 \
			  run_tags="Name=${var.name}"

      AMI_ID_Level_1=$(jq -r '(.builds | reverse[]) | select(.custom_data.source_ami_name | contains("Level 1")) | .artifact_id | split(":")[1]' manifest.json | head -n1)
      echo "Level 1 AMI ID: $AMI_ID_Level_1"
      
      aws ssm put-parameter \
        --name "/cis_ami/${var.name}/CIS_Amazon_Linux_2023_Benchmark_Level_1/ami_id" \
        --type "String" \
        --value "$AMI_ID_Level_1" \
        --region ${var.aws_region} \
        --overwrite
    EOT
  }
}

################################################################################
# Create Hardened AMI EKS_Optimized_AL2023_Level_2
################################################################################
resource "null_resource" "create_hardened_ami_level_2" {
  depends_on = [module.vpc, aws_ssm_parameter.cis_amazon_linux_2023_benchmark_level_2, null_resource.update_template, module.packer_role]

  triggers = {
    always_run = timestamp()
    aws_region = var.aws_region
  }

  provisioner "local-exec" {
    command = <<-EOT
      
      packer plugins install github.com/hashicorp/amazon || true

      cd amazon-eks-ami
      timestamp=$(date +%s)
      ami_name="CIS_Amazon_Linux_2023_Benchmark_Level_2-$timestamp"

      AMI_ID=$(aws ec2 describe-images \
        --owners aws-marketplace \
        --filters "Name=architecture,Values=x86_64" "Name=name,Values=${var.cis_ami_name_level_2}" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --region ${var.aws_region} \
        --output text)
      
      PACKER_BINARY=packer make k8s=1.34 \
      	os_distro=al2023 \
        aws_region=${var.aws_region} \
        source_ami_id=$AMI_ID \
        source_ami_owners=679593333241 \
        source_ami_filter_name="${var.cis_ami_name_level_2}" \
        subnet_id=${module.vpc.public_subnets[0]} \
        associate_public_ip_address=true \
        remote_folder=/home/ec2-user \
        ami_name=$ami_name \
        iam_instance_profile=packer-role-CIS_AL2023 \
			  pause_container_image=602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/eks/pause:3.10 \
			  run_tags="Name=${var.name}"
      
      AMI_ID_Level_2=$(jq -r '(.builds | reverse[]) | select(.custom_data.source_ami_name | contains("Level 2")) | .artifact_id | split(":")[1]' manifest.json | head -n1)
      echo "Level 2 AMI ID: $AMI_ID_Level_2"
      
      aws ssm put-parameter \
        --name "/cis_ami/${var.name}/CIS_Amazon_Linux_2023_Benchmark_Level_2/ami_id" \
        --type "String" \
        --value "$AMI_ID_Level_2" \
        --region ${var.aws_region} \
        --overwrite
    EOT
  }
}

################################################################################
# EKS Cluster
################################################################################
module "eks_cluster" {
  source = "../modules/eks-cluster"
  depends_on = [module.vpc]
  name   = var.name
  cluster_version = var.cluster_version
}

################################################################################
# EKS Managed Node Group Modules For AL2023 CIS Level 1
################################################################################
data "aws_ssm_parameter" "cis_amazon_linux_2023_benchmark_level_1" {
  depends_on = [aws_ssm_parameter.cis_amazon_linux_2023_benchmark_level_1, null_resource.create_hardened_ami_level_1]
  name = "/cis_ami/${var.name}/CIS_Amazon_Linux_2023_Benchmark_Level_1/ami_id"
}

module "eks_managed_node_group_level_1" {
  source = "../modules/eks_managed_node_group"
  depends_on = [module.eks_cluster, 
                null_resource.create_hardened_ami_level_1]

  name                              = "CISAL2023BL1"
  cluster_name                      = module.eks_cluster.cluster_name
  cluster_version                   = module.eks_cluster.cluster_version
  kubernetes_version                = module.eks_cluster.cluster_version
  subnet_ids                        = module.vpc.private_subnets
  cluster_primary_security_group_id = module.eks_cluster.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks_cluster.node_security_group_id]
  cluster_service_cidr              = module.eks_cluster.cluster_service_cidr
  ami_id                            = data.aws_ssm_parameter.cis_amazon_linux_2023_benchmark_level_1.value
  ami_type                          = "AL2023_x86_64_STANDARD"
  cluster_endpoint                  = module.eks_cluster.cluster_endpoint
  cluster_auth_base64               = module.eks_cluster.cluster_certificate_authority_data
  cloudinit_pre_nodeadm = [
    {
      content_type = "text/x-shellscript; charset=\"us-ascii\""
      content      = <<-EOT
        #!/usr/bin/env bash
        #kubelet runs on port 10250 so need to update iptables 
        iptables -I INPUT -p tcp -m tcp --dport 10250 -j ACCEPT
      EOT
    }
  ]
}

################################################################################
# EKS Managed Node Group Modules For AL2023 CIS Level 2
################################################################################
data "aws_ssm_parameter" "cis_amazon_linux_2023_benchmark_level_2" {
  depends_on = [aws_ssm_parameter.cis_amazon_linux_2023_benchmark_level_2, null_resource.create_hardened_ami_level_2]
  name = "/cis_ami/${var.name}/CIS_Amazon_Linux_2023_Benchmark_Level_2/ami_id"
}

module "eks_managed_node_group_level_2" {
  source = "../modules/eks_managed_node_group"
  depends_on = [module.eks_cluster, 
                null_resource.create_hardened_ami_level_2]

  name                              = "CISAL2023BL2"
  cluster_name                      = module.eks_cluster.cluster_name
  cluster_version                   = module.eks_cluster.cluster_version
  kubernetes_version                = module.eks_cluster.cluster_version
  subnet_ids                        = module.vpc.private_subnets
  cluster_primary_security_group_id = module.eks_cluster.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks_cluster.node_security_group_id]
  cluster_service_cidr              = module.eks_cluster.cluster_service_cidr
  ami_id                            = data.aws_ssm_parameter.cis_amazon_linux_2023_benchmark_level_2.value
  ami_type                          = "AL2023_x86_64_STANDARD"
  cluster_endpoint                  = module.eks_cluster.cluster_endpoint
  cluster_auth_base64               = module.eks_cluster.cluster_certificate_authority_data
  cloudinit_pre_nodeadm = [
    {
      content_type = "text/x-shellscript; charset=\"us-ascii\""
      content      = <<-EOT
            #!/usr/bin/env bash
            # kubelet runs on port 10250 so need to update iptables 
            iptables -I INPUT -p tcp -m tcp --dport 10250 -j ACCEPT
          EOT
    }
  ]
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
}

################################################################################
# Run CIS SCAN AWS Inspector
################################################################################
resource "null_resource" "run_cis_scan" {
  depends_on = [module.eks_managed_node_group_level_1, module.eks_managed_node_group_level_2]
  triggers = {
    cluster_name = var.name
    force_scan   = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Initiating CIS scan using AWS Inspector..." && \
      echo "Account ID: ${data.aws_caller_identity.current.account_id}" && \
      SCAN_ARN=$(aws inspector2 create-cis-scan-configuration \
        --scan-name "${var.name}" \
        --schedule "oneTime={}" \
        --security-level LEVEL_2 \
        --targets "accountIds=${data.aws_caller_identity.current.account_id},targetResourceTags={eks:cluster-name=${var.name}}" \
        --region ${var.aws_region} \
        --query 'scanArn' \
        --output text) && \
      
      if [ -z "$SCAN_ARN" ]; then
        echo "Error: Failed to create CIS scan configuration"
        exit 1
      fi && \
      
      echo "Successfully created CIS scan"
    EOT
  }
}

################################################################################
# Create Hardened AMI EKS_Optimized_AL2023_Level_1 Only
################################################################################
resource "null_resource" "only_create_hardened_ami_level_1" {
  depends_on = [aws_ssm_parameter.cis_amazon_linux_2023_benchmark_level_1, null_resource.update_template, module.packer_role]
  count = var.create_ami_level1 ? 1 : 0

  triggers = {
    always_run = timestamp()
    aws_region = var.aws_region
  }

  provisioner "local-exec" {
    command = <<-EOT
      
      packer plugins install github.com/hashicorp/amazon || true
      
      cd amazon-eks-ami

      timestamp=$(date +%s)
      ami_name="CIS_Amazon_Linux_2023_Benchmark_Level_1-$timestamp"

      AMI_ID=$(aws ec2 describe-images \
        --owners aws-marketplace \
        --filters "Name=architecture,Values=x86_64" "Name=name,Values=${var.cis_ami_name_level_1}" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --region ${var.aws_region} \
        --output text)

      PACKER_BINARY=packer make k8s=1.34 \
        os_distro=al2023 \
        aws_region=${var.aws_region} \
        source_ami_id=$AMI_ID \
        source_ami_owners=679593333241 \
        source_ami_filter_name="${var.cis_ami_name_level_1}" \
        AMI_VARIANT=amazon-eks-cis \
        subnet_id=${var.public_subnet_id} \
        associate_public_ip_address=true \
        remote_folder=/home/ec2-user \
        ami_name=$ami_name \
        iam_instance_profile=packer-role-CIS_AL2023 \
        pause_container_image=602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/eks/pause:3.10 \
			  run_tags="Name=${var.name}"

      AMI_ID_Level_1=$(jq -r '(.builds | reverse[]) | select(.custom_data.source_ami_name | contains("Level 1")) | .artifact_id | split(":")[1]' manifest.json | head -n1)
      echo "Level 1 AMI ID: $AMI_ID_Level_1"
      
      aws ssm put-parameter \
        --name "/cis_ami/${var.name}/CIS_Amazon_Linux_2023_Benchmark_Level_1/ami_id" \
        --type "String" \
        --value "$AMI_ID_Level_1" \
        --region ${var.aws_region} \
        --overwrite
    EOT
  }
}

################################################################################
# Create Hardened AMI EKS_Optimized_AL2023_Level_2 Only
################################################################################
resource "null_resource" "only_create_hardened_ami_level_2" {
  depends_on = [aws_ssm_parameter.cis_amazon_linux_2023_benchmark_level_2, null_resource.update_template, module.packer_role]
  count = var.create_ami_level2 ? 1 : 0

  triggers = {
    always_run = timestamp()
    aws_region = var.aws_region
  }

  provisioner "local-exec" {
    command = <<-EOT
      packer plugins install github.com/hashicorp/amazon || true

      cd amazon-eks-ami
      timestamp=$(date +%s)
      ami_name="CIS_Amazon_Linux_2023_Benchmark_Level_2-$timestamp"
        
      AMI_ID=$(aws ec2 describe-images \
        --owners aws-marketplace \
        --filters "Name=architecture,Values=x86_64" "Name=name,Values=${var.cis_ami_name_level_2}" \
        --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
        --region ${var.aws_region} \
        --output text)
      
      PACKER_BINARY=packer make k8s=1.34 \
      	os_distro=al2023 \
        aws_region=${var.aws_region} \
        source_ami_id=$AMI_ID \
        source_ami_owners=679593333241 \
        source_ami_filter_name="${var.cis_ami_name_level_2}" \
        subnet_id=${var.public_subnet_id} \
        associate_public_ip_address=true \
        remote_folder=/home/ec2-user \
        ami_name=$ami_name \
        iam_instance_profile=packer-role-CIS_AL2023 \
			  pause_container_image=602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/eks/pause:3.10 \
			  run_tags="Name=${var.name}"
      
      AMI_ID_Level_2=$(jq -r '(.builds | reverse[]) | select(.custom_data.source_ami_name | contains("Level 2")) | .artifact_id | split(":")[1]' manifest.json | head -n1)
      echo "Level 2 AMI ID: $AMI_ID_Level_2"
      
      aws ssm put-parameter \
        --name "/cis_ami/${var.name}/CIS_Amazon_Linux_2023_Benchmark_Level_2/ami_id" \
        --type "String" \
        --value "$AMI_ID_Level_2" \
        --region ${var.aws_region} \
        --overwrite
    EOT
  }
}
