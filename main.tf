locals {
  release_namespace = coalesce(var.release_namespace, var.release_name)
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