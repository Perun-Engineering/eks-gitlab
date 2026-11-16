# Documentation

## Description and Architecture

This module manages the AWS side of a GitLab deployment on EKS: the S3 buckets for object storage
and backups, and the IAM role (IRSA) GitLab's pods use to reach them. PostgreSQL (Aurora) and Redis
(ElastiCache) are not created here.

<p align="center">
  <img src="https://raw.githubusercontent.com/opsworks-co/eks-gitlab/master/.github/images/diagram.svg" alt="Architectural diagram" width="100%">
</p>

The bucket names are derived from the chart values passed in `values`, so pass the same values file
the chart is deployed with.

## In-cluster resources are no longer managed (since 0.7.0)

Up to 0.6.0 the module also installed the GitLab Helm release and created the namespace, the
credential/storage Secrets and an optional "lean" backup CronJob. Running a GitLab upgrade through
Terraform from a CI job hosted on that same GitLab drops the job mid-upgrade, so the chart now
belongs to a GitOps tool (ArgoCD, Flux) or plain Helm.

0.7.0 drops those objects from Terraform state with `removed { lifecycle { destroy = false } }`
blocks (`removed.tf`): the first apply after upgrading forgets them and **deletes nothing** in the
cluster. Before upgrading, make sure something else owns them:

- the Helm release (adopt it with the same release name and values),
- the namespace,
- the Secrets `<release>-postgresql-password`, `<release>-registry-postgresql-password`,
  `<release>-redis-password`, `<release>-smtp-password`, `<release>-rails-storage`,
  `<release>-registry-storage`, `<release>-ldap-password` and one per OmniAuth provider,
- the `<release>-toolbox-backup-lean` CronJob, if `lean_backup` was enabled.

The inputs that only fed those objects are removed: `gitlab_chart_version`, `release_max_history`,
`database_password`, `registry_database_password`, `redis_password`, `smtp_user`, `smtp_password`,
`omniauth_providers`, `ldap_password`, `namespace_labels`, `bucket_prefix`, `lean_backup`; and the
`lean_backup_cronjob_name` output. The upgrade plan should show only "will no longer be managed"
entries for those resources, with no changes to the S3 buckets or the IAM role.

The helm, kubernetes and kubectl providers are still declared in 0.7.0 so Terraform can process the
forgotten state entries; a later release drops them.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0, < 4.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.20 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.73.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_gitlab_policy"></a> [gitlab\_policy](#module\_gitlab\_policy) | terraform-aws-modules/iam/aws//modules/iam-policy | v6.4.0 |
| <a name="module_gitlab_role"></a> [gitlab\_role](#module\_gitlab\_role) | terraform-aws-modules/iam/aws//modules/iam-role | v6.4.0 |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | 5.10.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_eks_cluster.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_policy_document.s3_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_buckets_lifecycles"></a> [buckets\_lifecycles](#input\_buckets\_lifecycles) | Lifecycle rules for buckets | `map(string)` | `{}` | no |
| <a name="input_buckets_versioning"></a> [buckets\_versioning](#input\_buckets\_versioning) | Versioning for buckets | `map(bool)` | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name whose OIDC provider the IAM role trusts | `string` | n/a | yes |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Name of the GitLab Helm release, used in the IAM role name | `string` | `"gitlab"` | no |
| <a name="input_release_namespace"></a> [release\_namespace](#input\_release\_namespace) | Namespace GitLab runs in, used in the IAM role's OIDC subject. If empty, `release_name` will be used. | `string` | `""` | no |
| <a name="input_role_policy"></a> [role\_policy](#input\_role\_policy) | Policy for GitLab role | `string` | `null` | no |
| <a name="input_role_suffix"></a> [role\_suffix](#input\_role\_suffix) | Optional suffix for GitLab role | `string` | `"access-aws"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_values"></a> [values](#input\_values) | The GitLab chart values (list of YAML strings, first one is read); the S3 bucket names are derived from it | `any` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_buckets"></a> [buckets](#output\_buckets) | List of buckets created |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of IAM role |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of IAM role |
<!-- END_TF_DOCS -->
