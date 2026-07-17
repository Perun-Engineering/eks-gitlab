# Documentation

## Description and Architecture

This module was created to simplify deploying Gitlab into the EKS with storage on AWS S3, AWS Aurora for PostreSQL, and AWS ElastiCache Redis.

<p align="center">
  <img src="https://raw.githubusercontent.com/opsworks-co/eks-gitlab/master/.github/images/diagram.svg" alt="Architectural diagram" width="100%">
</p>

In the above diagram, you can see the components and their relations (PostgreSQL and Redis are not deployed with this module).

## Lean backup CronJob

The chart deploys a single nightly full backup (blobs included) via the toolbox `backups.cron`. The
optional `lean_backup` input adds a **second, toggleable tier**: an intraday "lean full" backup that
runs `backup-utility` with all object-storage/blob components skipped, so only `db` and
`repositories` are captured. This is useful when the blob data already lives durably in S3 and only
the database and Git repositories need a more frequent off-instance copy.

It is disabled by default. Enabling it takes a single flag:

```hcl
lean_backup = {
  enabled = true
}
```

Everything else has sensible defaults (schedule `0 6,12,18 * * *`, `concurrencyPolicy: Forbid`,
`activeDeadlineSeconds: 2700`, gitlab-base node placement, and the full blob `--skip` list). See the
`lean_backup` input below for the complete set of overridable fields.

The CronJob is rendered from `templates/lean-backup-cronjob.yaml.tpl` and applied with the
`kubectl` provider. The template is a faithful clone of the chart-managed toolbox backup pod spec
(init containers, projected secrets, volumes and env), with only scheduling, resources and the
`--skip` arguments parameterized. Container/init image repositories are taken from `values`, and the
image tag is resolved automatically from the deployed release's GitLab application version (the
chart's appVersion / `global.gitlabVersion`) — so no version needs to be maintained here.

> **Chart upgrades:** because the template mirrors the chart's rendered toolbox backup pod spec, it
> must be re-synced after major GitLab chart upgrades that change the toolbox secret/volume topology.
> Regenerate it from the live CronJob: `kubectl -n <ns> get cronjob <release>-toolbox-backup -o yaml`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | 2.11.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | ~> 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.20 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.36.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | 2.11.0 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | 2.1.5 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 3.0.1 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_gitlab_policy"></a> [gitlab\_policy](#module\_gitlab\_policy) | terraform-aws-modules/iam/aws//modules/iam-policy | v6.4.0 |
| <a name="module_gitlab_role"></a> [gitlab\_role](#module\_gitlab\_role) | terraform-aws-modules/iam/aws//modules/iam-role | v6.4.0 |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | 5.10.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [helm_release.gitlab](https://registry.terraform.io/providers/hashicorp/helm/2.11.0/docs/resources/release) | resource |
| [kubectl_manifest.lean_backup](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace_v1.gitlab](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.gitlab_omniauth_providers](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.gitlab_rails_storage](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.gitlab_registry_storage](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.ldap](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.postgres](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.redis](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.registry_postgres](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.smtp](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [aws_eks_cluster.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_policy_document.s3_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_bucket_prefix"></a> [bucket\_prefix](#input\_bucket\_prefix) | Prefix used for S3 buckets | `string` | `""` | no |
| <a name="input_buckets_lifecycles"></a> [buckets\_lifecycles](#input\_buckets\_lifecycles) | Lifecycle rules for buckets | `map(string)` | `{}` | no |
| <a name="input_buckets_versioning"></a> [buckets\_versioning](#input\_buckets\_versioning) | Versioning for buckets | `map(bool)` | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | EKS cluster name where you want to deploy the release | `string` | n/a | yes |
| <a name="input_database_password"></a> [database\_password](#input\_database\_password) | Password to access PostgreSQL database | `string` | n/a | yes |
| <a name="input_gitlab_chart_version"></a> [gitlab\_chart\_version](#input\_gitlab\_chart\_version) | Version of the gitlab chart | `string` | `"7.8.1"` | no |
| <a name="input_ldap_password"></a> [ldap\_password](#input\_ldap\_password) | LDAP password | `string` | `""` | no |
| <a name="input_lean_backup"></a> [lean\_backup](#input\_lean\_backup) | Optional intraday "lean full" backup CronJob (db + repositories only; object-storage/blob<br/>components skipped). Rendered as a clone of the chart's toolbox backup CronJob with only the<br/>scheduling, resources and `--skip` arguments changed, so env/secrets/volumes stay faithful to<br/>the chart. Disabled by default; set `enabled = true` to create it.<br/><br/>Images default to the toolbox/certificates/gitlab-base repositories taken from `values`, tagged<br/>with the GitLab application version resolved from the deployed Helm release (the chart's<br/>appVersion, or `global.gitlabVersion` if set) — so there is no image version to maintain here.<br/>Supply the full `*_image` fields only to override. `name` defaults to<br/>"<release\_name>-toolbox-backup-lean" and `service_account_name` to "<release\_name>-toolbox". | <pre>object({<br/>    enabled                       = optional(bool, false)<br/>    schedule                      = optional(string, "0 6,12,18 * * *")<br/>    name                          = optional(string, null)<br/>    toolbox_image                 = optional(string, null)<br/>    certificates_image            = optional(string, null)<br/>    configure_image               = optional(string, null)<br/>    service_account_name          = optional(string, null)<br/>    rails_secret_name             = optional(string, null)<br/>    concurrency_policy            = optional(string, "Forbid")<br/>    restart_policy                = optional(string, "Never")<br/>    active_deadline_seconds       = optional(number, 2700)<br/>    backoff_limit                 = optional(number, 0)<br/>    successful_jobs_history_limit = optional(number, 1)<br/>    failed_jobs_history_limit     = optional(number, 3)<br/>    ttl_seconds_after_finished    = optional(number, 86400)<br/>    tmp_storage_size              = optional(string, "30Gi")<br/>    skip = optional(list(string), [<br/>      "registry", "uploads", "pages", "packages", "external_diffs",<br/>      "ci_secure_files", "lfs", "artifacts", "terraform_state",<br/>    ])<br/>    node_selector = optional(map(string), {<br/>      provisioner = "gitlab-base"<br/>      nodetype    = "gitlab-base"<br/>    })<br/>    tolerations = optional(list(object({<br/>      key      = string<br/>      value    = optional(string)<br/>      effect   = string<br/>      operator = optional(string)<br/>    })), [{ key = "gitlab-base", value = "true", effect = "NoSchedule" }])<br/>    pod_annotations = optional(map(string), { "karpenter.sh/do-not-disrupt" = "true" })<br/>    resources       = optional(any, { requests = { cpu = "500m", memory = "1G" } })<br/>  })</pre> | `{}` | no |
| <a name="input_namespace_labels"></a> [namespace\_labels](#input\_namespace\_labels) | Labels for GitLab namespace | `map(string)` | `{}` | no |
| <a name="input_omniauth_providers"></a> [omniauth\_providers](#input\_omniauth\_providers) | OmniAuth providers | `map(string)` | `{}` | no |
| <a name="input_redis_password"></a> [redis\_password](#input\_redis\_password) | Password to access Redis database | `string` | n/a | yes |
| <a name="input_registry_database_password"></a> [registry\_database\_password](#input\_registry\_database\_password) | Password to access Registry PostgreSQL database | `string` | `null` | no |
| <a name="input_release_max_history"></a> [release\_max\_history](#input\_release\_max\_history) | Maximum saved revisions per release | `number` | `10` | no |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | This is the name of the release which also used as a prefix or suffix for the resources | `string` | `"gitlab"` | no |
| <a name="input_release_namespace"></a> [release\_namespace](#input\_release\_namespace) | Namespace name where you want to deploy the release. If empty, `release_name` will be used. | `string` | `""` | no |
| <a name="input_role_policy"></a> [role\_policy](#input\_role\_policy) | Policy for GitLab role | `string` | `null` | no |
| <a name="input_role_suffix"></a> [role\_suffix](#input\_role\_suffix) | Optional suffix for GitLab role | `string` | `"access-aws"` | no |
| <a name="input_smtp_password"></a> [smtp\_password](#input\_smtp\_password) | SMTP Password | `string` | `""` | no |
| <a name="input_smtp_user"></a> [smtp\_user](#input\_smtp\_user) | SMTP Username | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |
| <a name="input_values"></a> [values](#input\_values) | Custom values.yaml file for the Helm chart | `any` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_buckets"></a> [buckets](#output\_buckets) | List of buckets created |
| <a name="output_lean_backup_cronjob_name"></a> [lean\_backup\_cronjob\_name](#output\_lean\_backup\_cronjob\_name) | Name of the lean backup CronJob, or null when lean\_backup is disabled |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | ARN of IAM role |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Name of IAM role |
<!-- END_TF_DOCS -->
