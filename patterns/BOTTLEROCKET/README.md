# Bottlerocket

This pattern provides a fully automated solution to create security-hardened Amazon EKS Bottlerocket AMIs that comply with Level 2 standards.
Please note, Bottlerocket AMI is CIS Level 1 certified out of the box:
"Amazon Web Services’s Bottlerocket has been certified by the Center for Internet Security® (CIS®) to ship secure as hardened to CIS Bottlerocket Benchmark v1.0.0. Organizations that leverage Bottlerocket can now be assured that it will successfully run on a CIS hardened environment."

References: <https://aws.amazon.com/bottlerocket/>

## 🔢 Pre-requisites

1. (Mandatory) Create S3 for storing terraform state files and provide S3 Bucket name and region on file ``versions.tf``.
2. (Mandatory) Install [Docker](https://docs.docker.com/engine/install/).
3. (Mandatory) Install [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli).
4. (Optional) For the static tests, install terraform-docs,tflint,checkov,pre-commit and mdl.

## 🚀 How to deploy

### Option 1: Use the guided approach by running the script on the root folder: ``create-hardened-ami.sh``.

or 

### Option 2: Create Complete Infrastructure

**Step 1.** Navigate to the Bottlerocket pattern directory: `cd patterns/BOTTLEROCKET`

**Step 2.** Run `terraform init` ,`terraform plan` and `terraform apply` to deploy Complete Infrastructure using Terraform.
This will include:

- VPC and Subnets
- EKS Cluster 
- EKS managed node groups with hardened AMI
- Deploy several different add-ons to check if the workload will run without issues.

> Note: AWS Inspector CIS scans are not supported for Bottlerocket OS. Inspector CIS benchmarks only apply to general-purpose Linux distributions (Amazon Linux 2023, Ubuntu, etc.). For Bottlerocket, CIS hardening is applied at boot time via the bootstrap container in this pattern. See: <https://docs.aws.amazon.com/inspector/latest/user/scanning-cis.html>

or 

### Option 3: Create Only CIS Bootstrap Image

To build and push the CIS bootstrap image to ECR without creating the rest of the cluster:

```
terraform init
terraform apply \
    -var="aws_region=$aws_region" \
    -target=aws_ecr_repository.bottlerocket_cis_bootstrap_image \
    -target=null_resource.docker_build_push \
    --auto-approve
```

> Note: The `cis_bootstrape_image` flag and `docker_build_push_image_only` resource were removed as duplicates. The single `null_resource.docker_build_push` now handles image creation consistently.

## 🧹 How to terminate resources

**Step 1.** Navigate to the Bottlerocket pattern directory: `cd patterns/BOTTLEROCKET`

**Step 2.** Run `terraform destroy` to Terminate Resources

## 🕵️ How to access the EKS Cluster

Step 1. Create EKS Access Entry for your IAM User:

Through the AWS Console:

- Go to EKS Cluster created as part of the solution which is named BOTTLEROCKET on the AWS Region from the pipeline.
- Go to Access, Create Access Entry, Select your IAM Role from the list, Type: Standard, Click Next
- Add policy AmazonEKSClusterAdminPolicy *

Click in Next, then Create

Using AWS CLI:

```
#!/bin/bash
aws eks create-access-entry --cluster-name BOTTLEROCKET --principal-arn <value> --region <Region>
aws eks associate-access-policy --cluster-name BOTTLEROCKET --principal-arn <value> --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy --access-scope "type=cluster" --region <Region>
```

Regarding the Policy AmazonEKSClusterAdminPolicy:

"This access policy includes permissions that grant an IAM principal administrator access to a cluster. When associated to an access entry, its access scope is typically the cluster, rather than a Kubernetes namespace. If you want an IAM principal to have a more limited administrative scope, consider associating the AmazonEKSAdminPolicy access policy to your access entry instead."
References: <https://docs.aws.amazon.com/eks/latest/userguide/access-policy-permissions.html#access-policy-permissions-amazoneksclusteradminpolicy>

Step 2. You need to update your kubeconfig in order to run kubectl commands to the cluster

```
#!/bin/bash
aws eks update-kubeconfig --name BOTTLEROCKET --region <Region>
```

Then you can check nodes that joined the cluster and troubleshoot issues if required.

```
#!/bin/bash
kubectl get nodes -o wide
NAME                                        STATUS   ROLES    AGE     VERSION               INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                                KERNEL-VERSION    CONTAINER-RUNTIME
ip-10-0-19-22.us-west-2.compute.internal    Ready    <none>   24m   v1.37.0-eks-29d7970   10.0.19.22    <none>        Bottlerocket OS 1.67.0 (aws-k8s-1.37)   6.18.51 (amd64)   containerd://2.3.6+bottlerocket
```

Check if all the pods are running:

```
#!/bin/bash
kubectl get pods -A
NAMESPACE     NAME                                  READY   STATUS    RESTARTS   AGE
kube-system   aws-node-h7x7n                        2/2     Running   0          24m
kube-system   coredns-6bd8c6cd8c-9z2cm              1/1     Running   0          22m
kube-system   coredns-6bd8c6cd8c-rq2xs              1/1     Running   0          22m
kube-system   ebs-csi-controller-64bd9b8495-5llj2   6/6     Running   0          22m
kube-system   ebs-csi-controller-64bd9b8495-rndjb   6/6     Running   0          22m
kube-system   ebs-csi-node-vtnmm                    3/3     Running   0          22m
kube-system   kube-proxy-726b2                      1/1     Running   0          24m
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
| <a name="module_eks_managed_node_group_level_2"></a> [eks\_managed\_node\_group\_level\_2](#module\_eks\_managed\_node\_group\_level\_2) | ../modules/eks_managed_node_group | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../modules/vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_ecr_repository.bottlerocket_cis_bootstrap_image](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/resources/ecr_repository) | resource |
| [null_resource.docker_build_push](https://registry.terraform.io/providers/hashicorp/null/3.2.4/docs/resources/resource) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/caller_identity) | data source |
| [aws_ssm_parameter.bottlerocket_ami](https://registry.terraform.io/providers/hashicorp/aws/6.69.1/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-west-2"` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | EKS Cluster Version | `string` | `"1.37"` | no |
| <a name="input_ecr_repository_name"></a> [ecr\_repository\_name](#input\_ecr\_repository\_name) | ECR Repository Name | `string` | `"bottlerocket-cis-bootstrap-image"` | no |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | CIS Level 2 Bootstrap Image Tag. If empty, a content-hash of the Dockerfile is used (recommended for IMMUTABLE repos). | `string` | `""` | no |
| <a name="input_name"></a> [name](#input\_name) | Name Prefix | `string` | `"BOTTLEROCKET"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bottlerocket_ami_id"></a> [bottlerocket\_ami\_id](#output\_bottlerocket\_ami\_id) | The Bottlerocket AMI ID used for the node group |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded certificate data for the EKS cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint for the EKS cluster API server |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | The name of the EKS cluster |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | The primary security group ID of the EKS cluster |
| <a name="output_cluster_version"></a> [cluster\_version](#output\_cluster\_version) | The Kubernetes version of the EKS cluster |
| <a name="output_ecr_image_tag"></a> [ecr\_image\_tag](#output\_ecr\_image\_tag) | The tag of the CIS bootstrap image pushed to ECR (content-hash if image\_tag is empty) |
| <a name="output_ecr_image_uri"></a> [ecr\_image\_uri](#output\_ecr\_image\_uri) | Fully-qualified URI of the CIS bootstrap image in ECR |
| <a name="output_ecr_repository_arn"></a> [ecr\_repository\_arn](#output\_ecr\_repository\_arn) | The ARN of the ECR repository for the CIS bootstrap image |
| <a name="output_ecr_repository_url"></a> [ecr\_repository\_url](#output\_ecr\_repository\_url) | The URL of the ECR repository for the CIS bootstrap image |
| <a name="output_oidc_provider_arn"></a> [oidc\_provider\_arn](#output\_oidc\_provider\_arn) | The ARN of the OIDC provider for the EKS cluster |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | List of private subnet IDs |
| <a name="output_public_subnets"></a> [public\_subnets](#output\_public\_subnets) | List of public subnet IDs |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the VPC |
<!-- END_TF_DOCS -->
