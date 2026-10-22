# EKS Optimized AL2023

This pattern provides a fully automated solution to create security-hardened Amazon EKS AL2023 AMIs that comply with either CIS Level 1 or Level 2 standards.

## 🔢 Pre-requisites

1. (Mandatory) Create S3 for storing terraform state files and provide S3 Bucket name and region on file ``versions.tf``.
2. (Mandatory) Install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).
3. (Mandatory) Install [Packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli).
4. (Mandatory) Become a member of Center for Interner Security(<https://www.cisecurity.org/>).

In order to download Build Kit scripts for Amazon Linux 2023.
This scripts will be applied on top of EKS-Optimized AMIs.
More info on Technical details section below.

7. (Optional) For the static tests, install terraform-docs,tflint,checkov,pre-commit and mdl.

## 🚀 How to deploy

### Option 1: Use the guided approach by running the script on the root folder: ``create-hardened-ami.sh``.

or 

### Option 2: Create Complete Infrastructure

**Step 1.** Navigate to the EKS_Optimized_AL2023 pattern directory: `cd patterns/EKS_Optimized_AL2023`

**Step 2.** Follow steps from the section [CIS Scripts](##🔒-cis-cripts)

**Step 3.** Run `terraform init` ,`terraform plan` and `terraform apply` to deploy Complete Infrastructure using Terraform.
This will include:

- VPC and Subnets
- EKS Cluster 
- EKS managed node groups with EKS CIS Level1 and Level2 Hardened AMIs using EKS AMIs as a base AMI
- Deploy several different add-ons to check if the workload will run without issues.
- Trigger AWS Inspector CIS scans to scan EKS manages nodes and generate reports about checks which Passed, are Skipped or Failed.

or 

### Option 3: Create Only Hardened AMIs

Use this when you only need a hardened AMI and don't want to provision a VPC or EKS cluster. You must supply an existing public subnet ID via `-var public_subnet_id=...`.

  1. CIS Level 1
```
terraform init
```
and
```
terraform plan \
  -var="create_ami_level1=true" \
  -var="public_subnet_id=$subnet_id" \
  -var="aws_region=$aws_region" \
  -target=null_resource.only_create_hardened_ami_level_1
```
and
```
terraform apply \
  -var="create_ami_level1=true" \
  -var="public_subnet_id=$subnet_id" \
  -var="aws_region=$aws_region" \
  -target=null_resource.only_create_hardened_ami_level_1 \
  --auto-approve
```

 2. CIS Level 2

```
terraform init
```
and

```
terraform plan \
  -var="create_ami_level2=true" \
  -var="public_subnet_id=$subnet_id" \
  -var="aws_region=$aws_region" \
  -target=null_resource.only_create_hardened_ami_level_2
```

and

```
terraform apply \
  -var="create_ami_level2=true" \
  -var="public_subnet_id=$subnet_id" \
  -var="aws_region=$aws_region" \
  -target=null_resource.only_create_hardened_ami_level_2 \
  --auto-approve
```

3. Both Level 1 and Level 2

```
terraform init
```

and

```
terraform plan \
  -var="create_ami_level1=true" \
  -var="create_ami_level2=true" \
  -var="public_subnet_id=$subnet_id" \
  -var="aws_region=$aws_region" \
  -target=null_resource.only_create_hardened_ami_level_1 \
  -target=null_resource.only_create_hardened_ami_level_2
```

and

```
terraform apply \
  -var="create_ami_level1=true" \
  -var="create_ami_level2=true" \
  -var="public_subnet_id=$subnet_id" \
  -var="aws_region=$aws_region" \
  -target=null_resource.only_create_hardened_ami_level_1 \
  -target=null_resource.only_create_hardened_ami_level_2 \
  --auto-approve
```

> Note: The `only_create_*` resources are gated by `create_ami_levelN` flags so they remain inert during normal `terraform apply`. They do not depend on `module.vpc`, so targeting them does not provision VPC infrastructure.

## 🧹 How to terminate resources

**Step 1.** Navigate to the EKS_Optimized_AL2023 pattern directory: `cd patterns/EKS_Optimized_AL2023`

**Step 2.** Run `terraform destroy` to Terminate Resources

## Technical details

## 🔒 CIS Scripts

CIS scripts needs to be downloaded from the following website: <https://www.cisecurity.org/cis-securesuite/cis-securesuite-build-kit-content>
In order to download the scripts, you need to be a CIS SecureSuite Member.

**Step 1.** Once you become a member, Click in "CIS WorkBench Sign In", and provide your username and password.

**Step 2.** Navigate to Benchmarks: <https://workbench.cisecurity.org/benchmarks>.

**Step 3.** Select "CIS Amazon Linux 2023 Benchmark" v1.0.0.

**Step 4.** Go to Files on the left side.

**Step 5.** Select "CIS Amazon Linux 2023 Benchmark v1.0.0 - Build Kit".

**Step 6.** Click in Latest Version on the right side, to Download amazon_linux_2023.tar.gz file.

**Step 7.** unzip the file and store the content on the folder [cis-scripts](./patterns/EKS_Optimized_2023/cis-scripts/).

**Step 8.**
Some changes need to be performed on the scripts in order to allow it to be executed from the pipeline.
Please find below detailed information about the changes.

Changes performed on CIS-LBK scripts:

1. Copied script `cis-scripts/CIS-LBK/cis_lbk_amazon_linux_2023/amazon_linux_2023.sh` to:
  `cis-scripts/CIS-LBK/cis_lbk_amazon_linux_2023/amazon_linux_2023_level_1.sh` and configure it to run Level 1 Hardening only:
   `run_profile=L1S`
   on the line 107.
   and `cis-scripts/CIS-LBK/cis_lbk_amazon_linux_2023/amazon_linux_2023_level_2.sh` and configure it to run Level 2 Hardening only:
   `run_profile=L2S`
   on the line 107.

2. add `mkdir $BDIR/logs` on Line 31 of `amazon_linux_2023_level_1.sh` and `amazon_linux_2023_level_2.sh` to create logs directory on the Instance

3. Disable prompt by commenting out on line 106

`#WARBNR`

4. disable checks that can cause operational impact on the file `exclusion_list.txt`:

You need to add to the file the following checks:

```#txt
1.4.1 #Ensure permissions on bootloader config are configured
1.6.1.6 #Ensure no unconfined services exist
3.2.1 #Ensure IP forwarding is disabled
3.4.2.4 #Ensure host based firewall loopback traffic is configured
3.3.1 #nix_ensure_source_routed_packets_not_accepted
3.3.2 #Ensure ICMP redirects are not accepted"
3.3.9 #Ensure IPv6 router advertisements are not accepted
3.4.2.7 #Ensure nftables default deny firewall policy
3.4.2.5 #Ensure firewalld drops unnecessary services and ports
3.4.4.2.3 #Ensure iptables rules exist for all open ports
3.4.4.2.4 #Ensure iptables default deny firewall policy
3.4.4.3.3 #Ensure ip6tables firewall rules exist for all open ports
6.1.11 #Ensure world writable files and directories are secured
6.1.12 #Ensure no unowned or ungrouped files or directories exist
3.4.1.1 #Ensure nftables is installed
```

Please find below more information about why the above checks needs to be skipped on EKS:

## CIS Scan Results and Exceptions for failed controls

Some configuration changes required for Kubernetes operation override settings applied during hardening. Below are failed findings, possible reasons, and recommendations where available. Organizations can re-apply controls according to their security and compliance requirements, then re-test to confirm application functionality.

| CIS ID | CIS Description | Reason | Alternative control |
|---------|-----------------|---------|-------------------|
| 3.4.4.2.3 | Ensure iptables rules exist for all open ports | iptables are managed by kube-proxy | Please use network policies to manage communication between pods |
| 3.4.4.2.4 | Ensure iptables default deny firewall policy | iptables are managed by kube-proxy | Please use network policies to manage communication between pods |
| 3.4.4.3.3 | Ensure ip6tables firewall rules exist for all open ports | iptables are managed by kube-proxy | Please use network policies to manage communication between pods |
| 6.1.11 | Ensure world writable files and directories are secured | Directories used by containerd | This is the standard behavior of Kubernetes, you can get more background here: [kubernetes/kubernetes#76158](https://github.com/kubernetes/kubernetes/issues/76158) |
| 6.1.12 | Ensure no unowned or ungrouped files or directories exist | Directories used by containerd | This is the standard behavior of Kubernetes, you can get more background here: [kubernetes/kubernetes#76158](https://github.com/kubernetes/kubernetes/issues/76158) |
| 3.2.1 | Ensure IP forwarding is disabled | IP forwarding is required by Kubernetes | N/A |
| 1.4.1 | Ensure permissions on bootloader config are configured | | |
| 1.6.1.6 | Ensure no unconfined services exist | Processes flagged in these findings are container processes. | Investigate any unconfined processes. They may need to have an existing security context assigned to them or a policy built for them. <https://aws.github.io/aws-eks-best-practices/security/docs/runtime/#runtime-security> |
| 3.4.2.4 | Ensure host based firewall loopback traffic is configured | Currently kube-proxy on EKS relies on iptables. | Once the FR is actioned on <https://github.com/aws/containers-roadmap/issues/2313>, then this check can be allowed. |
| 3.3.1 | nix_ensure_source_routed_packets_not_accepted | Pending | Pending |
| 3.3.2 | Ensure ICMP redirects are not accepted | Pending | Pending |
| 3.3.9 | Ensure IPv6 router advertisements are not accepted | Pending | Pending |
| 3.4.2.7 | Ensure nftables default deny firewall policy | Currently kube-proxy on EKS relies on iptables. | Once the FR is actioned on <https://github.com/aws/containers-roadmap/issues/2313>, then this check can be allowed. |
| 3.4.2.5 | Ensure firewalld drops unnecessary services and ports | Currently kube-proxy on EKS relies on iptables. | Once the FR is actioned on <https://github.com/aws/containers-roadmap/issues/2313>, then this check can be allowed. |
| 3.4.1.1 | Ensure nftables is installed | Currently kube-proxy on EKS relies on iptables. | Once the FR is actioned on <https://github.com/aws/containers-roadmap/issues/2313>, then this check can be allowed. |

## 🧑🏿‍💻 Packer scripts

`packer-files/al2023_amd64_level_1.pkrvars.hcl` has specific settings to EKS_Optimized_AL2023_CIS_Benchmark_Level_1
`packer-files/al2023_amd64_level_2.pkrvars.hcl` has specific settings to EKS_Optimized_AL2023_CIS_Benchmark_Level_2
`packer-files/amazon-eks.pkr.hcl` has the source,build and provisioner components for  the following AMIs:

- EKS_Optimized_AL2023_CIS_Benchmark_Level_1
- EKS_Optimized_AL2023_CIS_Benchmark_Level_2

## 🕵️ How to access the EKS Cluster

Step 1. Create EKS Access Entry for your IAM User:

Through the AWS Console:

- Go to EKS Cluster created as part of the solution which is named EKS_Optimized_AL2023 on the AWS Region from the pipeline.
- Go to Access, Create Access Entry, Select your IAM Role from the list, Type: Standard, Click Next
- Add policy AmazonEKSClusterAdminPolicy *

Click in Next, then Create

Using AWS CLI:

```#!/bin/bash
aws eks create-access-entry --cluster-name EKS_Optimized_AL2023 --principal-arn <value> --region <Region>
aws eks associate-access-policy --cluster-name EKS_Optimized_AL2023 --principal-arn <value> --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope "type=cluster" --region <Region>
```

Regarding the Policy AmazonEKSClusterAdminPolicy:

"This access policy includes permissions that grant an IAM principal administrator access to a cluster. When associated to an access entry, its access scope is typically the cluster, rather than a Kubernetes namespace. If you want an IAM principal to have a more limited administrative scope, consider associating the AmazonEKSAdminPolicy access policy to your access entry instead."
References: <https://docs.aws.amazon.com/eks/latest/userguide/access-policy-permissions.html#access-policy-permissions-amazoneksclusteradminpolicy>

Step 2. You need to update your kubeconfig in order to run kubectl commands to the cluster

```#!/bin/bash
aws eks update-kubeconfig --name EKS_Optimized_AL2023 --region <Region>
```

Then you can check nodes that joined the cluster and troubleshoot issues if required.

```#!/bin/bash
kubectl get nodes -o wide
NAME                                        STATUS   ROLES    AGE     VERSION               INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                        KERNEL-VERSION                           CONTAINER-RUNTIME
ip-10-0-22-135.us-west-2.compute.internal   Ready    <none>   20m   v1.37.0-eks-b9510e3   10.0.22.135   <none>        Amazon Linux 2023.12.20261021   6.18.54-121.166.amzn2023.x86_64 (amd64)   containerd://2.3.5+unknown
ip-10-0-46-74.us-west-2.compute.internal    Ready    <none>   20m   v1.37.0-eks-b9510e3   10.0.46.74    <none>        Amazon Linux 2023.12.20261021   6.18.54-121.166.amzn2023.x86_64 (amd64)   containerd://2.3.5+unknown
```

Check if all the pods are running:

```#!/bin/bash
kubectl get pods -A
NAMESPACE     NAME                                  READY   STATUS    RESTARTS   AGE
kube-system   aws-node-pwv5v                        2/2     Running   0          20m
kube-system   aws-node-qd5sm                        2/2     Running   0          20m
kube-system   coredns-6bd8c6cd8c-fv798              1/1     Running   0          20m
kube-system   coredns-6bd8c6cd8c-zsvsn              1/1     Running   0          20m
kube-system   ebs-csi-controller-868cc5bf75-4f9zp   6/6     Running   0          20m
kube-system   ebs-csi-controller-868cc5bf75-5hvlh   6/6     Running   0          20m
kube-system   ebs-csi-node-kl62t                    3/3     Running   0          20m
kube-system   ebs-csi-node-phzbx                    3/3     Running   0          20m
kube-system   kube-proxy-59wf9                      1/1     Running   0          20m
kube-system   kube-proxy-8wgbw                      1/1     Running   0          20m
```

## Troubleshooting

Please refer to the [troubleshooting docs](../../docs/troubleshooting.md)

<!-- BEGIN_TF_DOCS -->
## Providers

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.69.1 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 3.3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.38.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | 3.2.4 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks_blueprints_addons"></a> [eks\_blueprints\_addons](#module\_eks\_blueprints\_addons) | ../modules/eks-addons | n/a |
| <a name="module_eks_cluster"></a> [eks\_cluster](#module\_eks\_cluster) | ../modules/eks-cluster | n/a |
| <a name="module_eks_managed_node_group_level_1"></a> [eks\_managed\_node\_group\_level\_1](#module\_eks\_managed\_node\_group\_level\_1) | ../modules/eks_managed_node_group | n/a |
| <a name="module_eks_managed_node_group_level_2"></a> [eks\_managed\_node\_group\_level\_2](#module\_eks\_managed\_node\_group\_level\_2) | ../modules/eks_managed_node_group | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../modules/vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.create_hardened_ami_level_1](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [null_resource.create_hardened_ami_level_2](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [null_resource.only_create_hardened_ami_level_1](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [null_resource.only_create_hardened_ami_level_2](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [null_resource.run_cis_scan](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [aws_ami.eks_optimized_al2023_level_1](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/ami) | data source |
| [aws_ami.eks_optimized_al2023_level_2](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-west-2"` | no |
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Additional tags to merge with common\_tags. Use this to add team, cost-center, project, etc. | `map(string)` | `{}` | no |
| <a name="input_capacity_type"></a> [capacity\_type](#input\_capacity\_type) | Type of capacity for the EKS managed node groups. ON\_DEMAND for stability (recommended for CIS scanning), SPOT for cost savings. | `string` | `"ON_DEMAND"` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | EKS Cluster Version | `string` | `"1.37"` | no |
| <a name="input_create_ami_level1"></a> [create\_ami\_level1](#input\_create\_ami\_level1) | When true and only\_create\_hardened\_ami\_level\_1 is targeted, build a Level 1 hardened AMI without creating VPC/EKS resources. | `bool` | `false` | no |
| <a name="input_create_ami_level2"></a> [create\_ami\_level2](#input\_create\_ami\_level2) | When true and only\_create\_hardened\_ami\_level\_2 is targeted, build a Level 2 hardened AMI without creating VPC/EKS resources. | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name applied as a tag to all resources (e.g., dev, staging, prod). | `string` | `"dev"` | no |
| <a name="input_instance_types"></a> [instance\_types](#input\_instance\_types) | List of EC2 instance types for the EKS managed node groups. Provide multiple types for Spot diversification. | `list(string)` | `["m6i.large", "m5.large", "m5zn.large"]` | no |
| <a name="input_name"></a> [name](#input\_name) | Name Prefix | `string` | `"EKS_Optimized_AL2023"` | no |
| <a name="input_public_subnet_id"></a> [public\_subnet\_id](#input\_public\_subnet\_id) | Existing public subnet ID for Packer to use during AMI-only builds. Required when create\_ami\_level1 or create\_ami\_level2 is true. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ami_id_level_1"></a> [ami\_id\_level\_1](#output\_ami\_id\_level\_1) | The AMI ID for the EKS Optimized AL2023 Level 1 hardened image |
| <a name="output_ami_id_level_2"></a> [ami\_id\_level\_2](#output\_ami\_id\_level\_2) | The AMI ID for the EKS Optimized AL2023 Level 2 hardened image |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded certificate data for the EKS cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint for the EKS cluster API server |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | The primary security group ID of the EKS cluster |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | The Kubernetes version of the EKS cluster |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | The ARN of the OIDC provider for the EKS cluster |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | List of private subnet IDs |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | List of public subnet IDs |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
<!-- END_TF_DOCS -->
