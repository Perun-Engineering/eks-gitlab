locals {
  release_namespace = coalesce(var.release_namespace, var.release_name)
}

data "aws_region" "current" {}

resource "kubernetes_namespace_v1" "gitlab" {
  metadata {
    name   = local.release_namespace
    labels = var.namespace_labels
  }
}

resource "kubernetes_secret_v1" "postgres" {
  metadata {
    name      = "${var.release_name}-postgresql-password"
    namespace = local.release_namespace
  }

  data = {
    postgresql-password = var.database_password
    #We need below if we are going to deploy PostgreSQL next to the Gitlab in the EKS
    #not as RDS for PostgreSQL
    postgresql-postgres-password = var.database_password
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "registry_postgres" {
  # Optional, at this moment S3-only can be used https://docs.gitlab.com/administration/packages/container_registry_metadata_database/
  count = var.registry_database_password != null ? 1 : 0
  metadata {
    name      = "${var.release_name}-registry-postgresql-password"
    namespace = local.release_namespace
  }

  data = {
    registry-postgresql-password = var.registry_database_password
    #We need below if we are going to deploy PostgreSQL next to the Gitlab in the EKS
    #not as RDS for PostgreSQL
    registry-postgresql-postgres-password = var.registry_database_password
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "redis" {
  metadata {
    name      = "${var.release_name}-redis-password"
    namespace = local.release_namespace
  }

  data = {
    secret = var.redis_password
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "smtp" {
  #count = local.values.global.smtp.authentication == "false" ? 0 : 1

  metadata {
    name      = try(local.values.global.smtp.password.secret, "${var.release_name}-smtp-password")
    namespace = local.release_namespace
  }

  data = {
    password = var.smtp_password
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "gitlab_rails_storage" {
  metadata {
    name      = "${var.release_name}-rails-storage"
    namespace = local.release_namespace
  }

  data = {
    connection = <<EOF
provider: AWS
region: ${data.aws_region.current.id}
use_iam_profile: true
EOF
    config     = <<EOF
[default]
bucket_location = ${data.aws_region.current.id}
multipart_chunk_size_mb = 128
EOF
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "gitlab_omniauth_providers" {
  for_each = local.omniauth_providers
  metadata {
    name      = each.value
    namespace = local.release_namespace
  }

  data = {
    provider = var.omniauth_providers[each.value]
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "ldap" {
  count = lookup(local.values.global.appConfig, "ldap", []) == [] ? 0 : 1
  metadata {
    name      = "${var.release_name}-ldap-password"
    namespace = local.release_namespace
  }

  data = {
    secret = var.ldap_password
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "gitlab_registry_storage" {
  metadata {
    name      = "${var.release_name}-registry-storage"
    namespace = local.release_namespace
  }

  data = {
    config = <<EOF
s3:
  bucket: ${var.bucket_prefix}-registry
  region: ${data.aws_region.current.id}
  v4auth: true
EOF
  }
}

data "aws_iam_policy_document" "s3_bucket_policy" {
  for_each = local.buckets_list

  statement {
    sid    = "AllowListForGitlabRole"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.gitlab_role.arn]
    }
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${each.value}"]
  }

  statement {
    sid    = "AllowGetPutForGitlabRole"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.gitlab_role.arn]
    }
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["arn:aws:s3:::${each.value}/*"]
  }

  statement {
    sid    = "AllowDeleteForGitlabRole"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.gitlab_role.arn]
    }
    actions   = ["s3:DeleteObject"]
    resources = ["arn:aws:s3:::${each.value}/*"]
  }

  statement {
    sid    = "AllowPutObjectAclForGitlabRole"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.gitlab_role.arn]
    }
    actions   = ["s3:PutObjectAcl"]
    resources = ["arn:aws:s3:::${each.value}/*"]
  }

  statement {
    sid    = "AllowGetObjectAclForGitlabRole"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.gitlab_role.arn]
    }
    actions   = ["s3:GetObjectAcl"]
    resources = ["arn:aws:s3:::${each.value}/*"]
  }

  statement {
    sid    = "AllowListBucketMultipartUploads"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.gitlab_role.arn]
    }
    actions   = ["s3:ListBucketMultipartUploads"]
    resources = ["arn:aws:s3:::${each.value}"]
  }

  statement {
    sid    = "AllowListMultipartUploadParts"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [module.gitlab_role.arn]
    }
    actions   = ["s3:ListMultipartUploadParts"]
    resources = ["arn:aws:s3:::${each.value}/*"]
  }
}

module "s3_bucket" {
  for_each = local.buckets_list
  source   = "terraform-aws-modules/s3-bucket/aws"
  version  = "5.10.0"

  bucket        = each.value
  force_destroy = false

  versioning = {
    enabled = try(var.buckets_versioning[each.key], false)
  }

  policy        = data.aws_iam_policy_document.s3_bucket_policy[each.key].json
  attach_policy = true

  attach_deny_insecure_transport_policy = true
  block_public_acls                     = true
  block_public_policy                   = true
  ignore_public_acls                    = true
  restrict_public_buckets               = true

  lifecycle_rule = try(local.filtered_buckets_lifecycles[each.key].lifecycle_rule, [])

  tags = var.tags
}

resource "helm_release" "gitlab" {
  namespace        = local.release_namespace
  create_namespace = true

  name        = var.release_name
  repository  = "https://charts.gitlab.io/"
  chart       = "gitlab"
  max_history = var.release_max_history
  version     = var.gitlab_chart_version
  values      = var.values

  set {
    name  = "global.smtp.user_name"
    value = var.smtp_user
  }

  set {
    name  = "global.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.gitlab_role.arn
  }

  depends_on = [
    kubernetes_secret_v1.postgres,
    kubernetes_secret_v1.redis,
    kubernetes_secret_v1.gitlab_rails_storage,
    module.gitlab_role
  ]
}

# Intraday "lean full" backup CronJob (db + repositories only). Cloned from the chart-managed
# toolbox backup CronJob so its env/secrets/volumes stay faithful; only scheduling, resources and
# the backup-utility --skip arguments differ. Created only when var.lean_backup.enabled is true.
resource "kubectl_manifest" "lean_backup" {
  count = var.lean_backup.enabled ? 1 : 0

  yaml_body = templatefile("${path.module}/templates/lean-backup-cronjob.yaml.tpl", {
    cronjob_name                  = local.lean_name
    namespace                     = local.release_namespace
    release_name                  = var.release_name
    bucket_prefix                 = var.bucket_prefix
    schedule                      = local.lean.schedule
    concurrency_policy            = local.lean.concurrency_policy
    restart_policy                = local.lean.restart_policy
    active_deadline_seconds       = local.lean.active_deadline_seconds
    backoff_limit                 = local.lean.backoff_limit
    successful_jobs_history_limit = local.lean.successful_jobs_history_limit
    failed_jobs_history_limit     = local.lean.failed_jobs_history_limit
    ttl_seconds_after_finished    = local.lean.ttl_seconds_after_finished
    tmp_storage_size              = local.lean.tmp_storage_size
    backup_command                = local.lean_backup_command
    toolbox_image                 = local.lean_toolbox_image
    certificates_image            = local.lean_certificates_image
    configure_image               = local.lean_configure_image
    service_account               = local.lean_service_account
    rails_secret_name             = local.lean_rails_secret_name
    node_selector_yaml            = local.lean_node_selector_yaml
    tolerations_yaml              = local.lean_tolerations_yaml
    pod_annotations_yaml          = local.lean_pod_annotations_yaml
    resources_yaml                = local.lean_resources_yaml
  })

  server_side_apply = true
  wait              = false

  # The chart-generated secrets/configmaps the CronJob projects must exist first; the release also
  # supplies the app version used to tag the images.
  depends_on = [helm_release.gitlab]
}

module "gitlab_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "v6.4.0"

  name        = "gitlab-role-policy"
  description = "Policy for GitLab role"
  policy      = var.role_policy

  tags = var.tags
}

module "gitlab_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "v6.4.0"

  enable_oidc     = true
  name            = "${var.release_name}-${var.role_suffix}"
  use_name_prefix = false
  description     = "Gitlab Role to access AWS resources"

  oidc_provider_urls     = [data.aws_eks_cluster.eks.identity[0].oidc[0].issuer]
  oidc_wildcard_subjects = ["system:serviceaccount:${local.release_namespace}:gitlab*"]
  oidc_audiences         = ["sts.amazonaws.com"]

  policies = {
    gitlab-role-policy = module.gitlab_policy.arn
  }

  tags = var.tags

  depends_on = [
    module.gitlab_policy
  ]
}