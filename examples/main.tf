locals {
  saml_google_provider = <<EOF
name: saml
label: 'G Suite'
args:
  assertion_consumer_service_url: 'https://gitlab.example.com/users/auth/saml/callback'
  idp_cert_fingerprint: '00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00'
  idp_sso_target_url: 'https://accounts.google.com/o/saml2/idp?idpid=aabbccdde'
  issuer: 'https://gitlab.example.com'
  name_identifier_format: 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'
  attribute_statements: {
    email: [
      'emailAddress'
    ]
  }
EOF
  bucket_prefix        = "gitlab-mycompany"
}

module "gitlab" {
  source = "../"

  cluster_name         = "my-eks-cluster"
  release_name         = "gitlab"
  gitlab_chart_version = "7.8.1"

  database_password          = "database_password"
  registry_database_password = "registry_datatabase_password"
  redis_password             = "redis_password"
  smtp_user                  = "postfix"
  smtp_password              = "smtp_password"
  omniauth_providers = {
    "gitlab-omniauth-saml" = local.saml_google_provider
  }

  bucket_prefix = local.bucket_prefix
  buckets_lifecycles = {
    artifacts = <<EOF
{
  "lifecycle_rule": [
    {
      "id": "log",
      "status": "Enabled",
      "expiration": {
        "days": 30
      }
    }
  ]
}
EOF
    uploads   = <<EOF
{
  "lifecycle_rule": [
    {
      "id": "log",
      "status": "Enabled",
      "noncurrent_version_transition": [
        {
          "days": 30,
          "storage_class": "STANDARD_IA"
        }
      ]
    }
  ]
}
EOF
  }
  # Default is `false`, determine for each of backup, lfs, artifacts, packages, uploads etc
  buckets_versioning = {
    backup = true
  }

  # Optional intraday "lean full" backup CronJob (db + repositories only; object-storage blobs
  # skipped) in addition to the chart-managed nightly full. Disabled by default. The image tag is
  # resolved automatically from the deployed chart's GitLab app version, so only `enabled` is
  # required; the rest below are optional overrides shown with their defaults.
  lean_backup = {
    enabled = true

    # schedule                = "0 6,12,18 * * *"
    # concurrency_policy      = "Forbid"
    # active_deadline_seconds = 2700
    # tmp_storage_size        = "30Gi"
    # skip = [
    #   "registry", "uploads", "pages", "packages", "external_diffs",
    #   "ci_secure_files", "lfs", "artifacts", "terraform_state",
    # ]
  }

  values = [
    templatefile("values.yaml", {
      database_host              = "gitlab.xxxxxxxxxxxx.eu-central-1.rds.amazonaws.com"
      database_port              = "5432"
      database_username          = "postgres"
      registry_database_username = "gitlab_registry"
      redis_host                 = "master.gitlab.xxxxxx.euc1.cache.amazonaws.com"
      redis_port                 = "6379"
      release_name               = "gitlab"
      bucket_prefix              = local.bucket_prefix
      domain                     = "example.com"
      smtp_address               = "smtp.gmail.com"
    })
  ]

  tags = {}
}
