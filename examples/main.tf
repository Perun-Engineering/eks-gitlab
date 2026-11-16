locals {
  bucket_prefix = "gitlab-mycompany"
}

module "gitlab" {
  source = "../"

  cluster_name = "my-eks-cluster"
  release_name = "gitlab"

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

  # Same values file the chart is deployed with (by ArgoCD, Flux or Helm). The module reads it
  # only to derive the S3 bucket names.
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
