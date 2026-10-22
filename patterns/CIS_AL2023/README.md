# CIS Amazon Linux 2023

This pattern provides a fully automated solution to create security-hardened Amazon EKS AL2023 AMIs that comply with either CIS Level 1 or Level 2 standards.

## 🔢 Pre-requisites

1. (Mandatory) Create S3 for storing terraform state files and provide S3 Bucket name and region on file ``versions.tf``.
2. (Mandatory) Install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).
3. (Mandatory) Install [Packer](https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli).
4. (Mandatory) Subscribe to CIS AMIs from AWS Marketplace:

For Level 1:

- [CIS Amazon Linux 2023 Benchmark - Level 1](https://aws.amazon.com/marketplace/pp/prodview-fqqp6ebucarnm?sr=0-11&ref_=beagle&applicationId=AWSMPContessa)

For Level 2:

- [CIS Amazon Linux 2023 Benchmark - Level 2](https://aws.amazon.com/marketplace/pp/prodview-uis4wvkb7g3wq?sr=0-19&ref_=beagle&applicationId=AWSMPContessa)

5. (Optional) For the static tests, install terraform-docs, tflint, checkov, pre-commit and mdl.

## 🚀 How to deploy

### Option 1: Use the guided approach by running the script on the root folder: ``create-hardened-ami.sh``.

or

### Option 2: Create Complete Infrastructure

**Step 1.** Navigate to the CIS_AL2023 pattern directory: `cd patterns/CIS_AL2023`

**Step 2.** Run `terraform init`, `terraform plan` and `terraform apply` to deploy Complete Infrastructure using Terraform.
This will include:

- VPC and Subnets
- EKS Cluster
- EKS managed node groups with EKS CIS Level 1 and Level 2 Hardened AMIs using CIS Marketplace AMIs as the base
- Deploy several different add-ons to check if the workload will run without issues
- Trigger AWS Inspector CIS scans against the EKS managed nodes and generate reports about checks which Passed, are Skipped or Failed

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

**Step 1.** Navigate to the CIS_AL2023 pattern directory: `cd patterns/CIS_AL2023`

**Step 2.** Run `terraform destroy` to Terminate Resources

## Technical details

### How the AMI is built

This pattern uses `awslabs/amazon-eks-ami` Packer scripts as the build framework, with a small set of overrides shipped in `template_files/`:

- `install-worker.sh` — installs containerd, kubelet, nodeadm, ECR credential provider, SOCI snapshotter, and SSM Agent on top of the CIS base AMI (sudo-adjusted for the CIS non-root provisioner context)
- `set-clocksource.sh` / `limit-c-states.sh` — set kernel boot args via `sudo set-kernel-arg` (require root on the hardened AMI)
- `install-efa.sh` — installs Elastic Fabric Adapter packages when `enable_efa=true`
- `cleanup.sh` — runs at the end of the build only (dnf cache cleanup, auditd stop-before-purge, host-key removal, machine-id reset)
- `configure-selinux.sh` — relabels `/usr/bin` and `/etc/systemd/system` so EKS binaries match the SELinux policy applied by the CIS base
- `generate-version-info.sh` — emits the AMI version-info manifest (sudo-adjusted)
- `cache-pause-container.sh` / `cache-pause-container` — pre-pulls the EKS pause image so first-pod-launch doesn't pay an ECR round-trip

Note: as of `amazon-eks-ami` `v20261012` the al2023 Packer build is HCL2, so the upstream `template.pkr.hcl` and `variables-default.pkrvars.hcl` are used directly (no longer overridden); only the provisioner scripts above are overlaid.

`null_resource.update_template` clones `awslabs/amazon-eks-ami` at the tag specified by `var.branch` (default `v20261012`) into `patterns/CIS_AL2023/amazon-eks-ami/` and then overlays the files above before Packer runs. As of `v20261012` the al2023 build is HCL2 (`template.pkr.hcl` + `variables-default.pkrvars.hcl`); the upstream template is used as-is (only the `sudo`-adjusted provisioner scripts are overlaid), and `remote_folder=/home/ec2-user` is passed as a Packer `-var`.

### CIS controls already applied by the base AMI

Because the base is the CIS Marketplace AMI, the host OS controls (auditd, file permissions, kernel sysctls, services disabled, etc.) are applied by CIS before this pattern adds EKS components. The EKS overlay is intentionally narrow so it does not regress those controls.

## 🧑🏿‍💻 Packer scripts

The upstream HCL2 template (`templates/al2023/template.pkr.hcl`) is the Packer build definition used to produce both AMIs:

- CIS_Amazon_Linux_2023_Benchmark_Level_1
- CIS_Amazon_Linux_2023_Benchmark_Level_2

Packer is invoked from the cloned `awslabs/amazon-eks-ami` repository (under `patterns/CIS_AL2023/amazon-eks-ami/`) after `null_resource.update_template` overlays the files in `template_files/`. The source AMI is selected by `var.cis_ami_name_level_{1,2}` from the AWS Marketplace.

## 🕵️ How to access the EKS Cluster

Step 1. Create EKS Access Entry for your IAM User:

Through the AWS Console:

- Go to EKS Cluster created as part of the solution which is named CIS_AL2023 on the AWS Region from the pipeline.
- Go to Access, Create Access Entry, Select your IAM Role from the list, Type: Standard, Click Next
- Add policy AmazonEKSClusterAdminPolicy *

Click in Next, then Create

Using AWS CLI:

```#!/bin/bash
aws eks create-access-entry --cluster-name CIS_AL2023 --principal-arn <value> --region <Region>
aws eks associate-access-policy --cluster-name CIS_AL2023 --principal-arn <value> --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope "type=cluster" --region <Region>
```

Regarding the Policy AmazonEKSClusterAdminPolicy:

"This access policy includes permissions that grant an IAM principal administrator access to a cluster. When associated to an access entry, its access scope is typically the cluster, rather than a Kubernetes namespace. If you want an IAM principal to have a more limited administrative scope, consider associating the AmazonEKSAdminPolicy access policy to your access entry instead."
References: <https://docs.aws.amazon.com/eks/latest/userguide/access-policy-permissions.html#access-policy-permissions-amazoneksclusteradminpolicy>

Step 2. You need to update your kubeconfig in order to run kubectl commands to the cluster

```#!/bin/bash
aws eks update-kubeconfig --name CIS_AL2023 --region <Region>
```

Then you can check nodes that joined the cluster and troubleshoot issues if required.

```#!/bin/bash
kubectl get nodes -o wide
NAME                                        STATUS   ROLES    AGE    VERSION               INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                        KERNEL-VERSION                           CONTAINER-RUNTIME
ip-10-0-25-71.us-west-2.compute.internal    Ready    <none>   17m   v1.37.1-eks-117f323   10.0.25.71    <none>        Amazon Linux 2023.12.20261021   6.18.51-120.163.amzn2023.x86_64 (amd64)   containerd://2.2.7+unknown
ip-10-0-40-23.us-west-2.compute.internal    Ready    <none>   17m   v1.37.1-eks-117f323   10.0.40.23    <none>        Amazon Linux 2023.12.20260930   6.18.51-120.163.amzn2023.x86_64 (amd64)   containerd://2.2.7+unknown
```

Check if all the pods are running:

```#!/bin/bash
kubectl get pods -A
NAMESPACE     NAME                                  READY   STATUS    RESTARTS   AGE
kube-system   aws-node-dz5gq                        2/2     Running   0          17m
kube-system   aws-node-nxggp                        2/2     Running   0          11m
kube-system   coredns-6bd8c6cd8c-bvzl4              1/1     Running   0          14m
kube-system   coredns-6bd8c6cd8c-w9hbc              1/1     Running   0          11m
kube-system   ebs-csi-controller-7c88845bd5-486qt   6/6     Running   0          14m
kube-system   ebs-csi-controller-7c88845bd5-6vnb5   6/6     Running   0          12m
kube-system   ebs-csi-node-8jg7d                    3/3     Running   0          14m
kube-system   ebs-csi-node-d5m2n                    3/3     Running   0          11m
kube-system   kube-proxy-5wrb2                      1/1     Running   0          17m
kube-system   kube-proxy-kzgg4                      1/1     Running   0          11m
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
| <a name="module_packer_role"></a> [packer\_role](#module\_packer\_role) | ../modules/packer-role | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../modules/vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.create_hardened_ami_level_1](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [null_resource.create_hardened_ami_level_2](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [null_resource.only_create_hardened_ami_level_1](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [null_resource.only_create_hardened_ami_level_2](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [null_resource.run_cis_scan](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [null_resource.update_template](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [aws_ami_ids.cis_amazon_linux_2023_benchmark_level_1](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/ami_ids) | data source |
| [aws_ami_ids.cis_amazon_linux_2023_benchmark_level_2](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/ami_ids) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_tags"></a> [additional\_tags](#input\_additional\_tags) | Additional tags to merge with common\_tags. Use this to add team, cost-center, project, etc. | `map(string)` | `{}` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-west-2"` | no |
| <a name="input_branch"></a> [branch](#input\_branch) | EKS AMI Branch TAG | `string` | `"v20261012"` | no |
| <a name="input_capacity_type"></a> [capacity\_type](#input\_capacity\_type) | Type of capacity for the EKS managed node groups. ON\_DEMAND for stability (recommended for CIS scanning), SPOT for cost savings. | `string` | `"ON_DEMAND"` | no |
| <a name="input_cis_ami_name_level_1"></a> [cis\_ami\_name\_level\_1](#input\_cis\_ami\_name\_level\_1) | CIS AMI Name which will be use to Search the CIS AMI from Market Place | `string` | `"CIS Amazon Linux 2023 Benchmark - Level 1 - v10*"` | no |
| <a name="input_cis_ami_name_level_2"></a> [cis\_ami\_name\_level\_2](#input\_cis\_ami\_name\_level\_2) | CIS AMI Name which will be use to Search the CIS AMI from Market Place | `string` | `"CIS Amazon Linux 2023 Benchmark - Level 2 - v10*"` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | EKS Cluster Version | `string` | `"1.37"` | no |
| <a name="input_create_ami_level1"></a> [create\_ami\_level1](#input\_create\_ami\_level1) | Flag to create Level 1 Hardened AMI | `bool` | `false` | no |
| <a name="input_create_ami_level2"></a> [create\_ami\_level2](#input\_create\_ami\_level2) | Flag to create Level 2 Hardened AMI | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name applied as a tag to all resources (e.g., dev, staging, prod). | `string` | `"dev"` | no |
| <a name="input_instance_types"></a> [instance\_types](#input\_instance\_types) | List of EC2 instance types for the EKS managed node groups. Provide multiple types for Spot diversification. | `list(string)` | `["m6i.large", "m5.large", "m5zn.large"]` | no |
| <a name="input_name"></a> [name](#input\_name) | Name Prefix | `string` | `"CIS_AL2023"` | no |
| <a name="input_public_subnet_id"></a> [public\_subnet\_id](#input\_public\_subnet\_id) | Public subnet ID for AMI creation | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ami_id_level_1"></a> [ami\_id\_level\_1](#output\_ami\_id\_level\_1) | The AMI ID for the CIS Amazon Linux 2023 Benchmark Level 1 hardened image |
| <a name="output_ami_id_level_2"></a> [ami\_id\_level\_2](#output\_ami\_id\_level\_2) | The AMI ID for the CIS Amazon Linux 2023 Benchmark Level 2 hardened image |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded certificate data for the EKS cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint for the EKS cluster API server |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | The primary security group ID of the EKS cluster |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | The Kubernetes version of the EKS cluster |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | The ARN of the OIDC provider for the EKS cluster |
| <a name="output_packer_instance_profile"></a> [packer\_instance\_profile](#output\_packer\_instance\_profile) | Name of the IAM instance profile created for Packer builds |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | List of private subnet IDs |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | List of public subnet IDs |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
<!-- END_TF_DOCS -->
