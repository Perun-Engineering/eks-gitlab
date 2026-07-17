variable "release_name" {
  description = "This is the name of the release which also used as a prefix or suffix for the resources"
  type        = string
  default     = "gitlab"
}

variable "release_max_history" {
  description = "Maximum saved revisions per release"
  type        = number
  default     = 10
}

variable "release_namespace" {
  description = "Namespace name where you want to deploy the release. If empty, `release_name` will be used."
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "EKS cluster name where you want to deploy the release"
  type        = string
}

variable "values" {
  description = "Custom values.yaml file for the Helm chart"
  type        = any
  default     = []
}

variable "gitlab_chart_version" {
  description = "Version of the gitlab chart"
  type        = string
  default     = "7.8.1"
}

variable "database_password" {
  type        = string
  description = "Password to access PostgreSQL database"
  sensitive   = true
}

variable "registry_database_password" {
  type        = string
  description = "Password to access Registry PostgreSQL database"
  sensitive   = true
  default     = null
}

variable "redis_password" {
  type        = string
  description = "Password to access Redis database"
  sensitive   = true
}

variable "smtp_user" {
  type        = string
  default     = ""
  description = "SMTP Username"
}

variable "smtp_password" {
  type        = string
  default     = ""
  description = "SMTP Password"
  sensitive   = true
}

variable "omniauth_providers" {
  description = "OmniAuth providers"
  type        = map(string)
  default     = {}
}

variable "ldap_password" {
  description = "LDAP password"
  type        = string
  default     = ""
}

variable "namespace_labels" {
  description = "Labels for GitLab namespace"
  type        = map(string)
  default     = {}
}

variable "bucket_prefix" {
  description = "Prefix used for S3 buckets"
  type        = string
  default     = ""
}

variable "buckets_lifecycles" {
  description = "Lifecycle rules for buckets"
  type        = map(string)
  default     = {}
}

variable "buckets_versioning" {
  description = "Versioning for buckets"
  type        = map(bool)
  default     = {}
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "role_policy" {
  type        = string
  description = "Policy for GitLab role"
  sensitive   = true
  default     = null
}

variable "role_suffix" {
  type        = string
  description = "Optional suffix for GitLab role"
  default     = "access-aws"
}

variable "lean_backup" {
  description = <<-EOT
    Optional intraday "lean full" backup CronJob (db + repositories only; object-storage/blob
    components skipped). Rendered as a clone of the chart's toolbox backup CronJob with only the
    scheduling, resources and `--skip` arguments changed, so env/secrets/volumes stay faithful to
    the chart. Disabled by default; set `enabled = true` to create it.

    Images default to the toolbox/certificates/gitlab-base repositories taken from `values`, tagged
    with the GitLab application version resolved from the deployed Helm release (the chart's
    appVersion, or `global.gitlabVersion` if set) — so there is no image version to maintain here.
    Supply the full `*_image` fields only to override. `name` defaults to
    "<release_name>-toolbox-backup-lean" and `service_account_name` to "<release_name>-toolbox".
  EOT

  type = object({
    enabled                       = optional(bool, false)
    schedule                      = optional(string, "0 6,12,18 * * *")
    name                          = optional(string, null)
    toolbox_image                 = optional(string, null)
    certificates_image            = optional(string, null)
    configure_image               = optional(string, null)
    service_account_name          = optional(string, null)
    rails_secret_name             = optional(string, null)
    concurrency_policy            = optional(string, "Forbid")
    restart_policy                = optional(string, "Never")
    active_deadline_seconds       = optional(number, 2700)
    backoff_limit                 = optional(number, 0)
    successful_jobs_history_limit = optional(number, 1)
    failed_jobs_history_limit     = optional(number, 3)
    ttl_seconds_after_finished    = optional(number, 86400)
    tmp_storage_size              = optional(string, "30Gi")
    skip = optional(list(string), [
      "registry", "uploads", "pages", "packages", "external_diffs",
      "ci_secure_files", "lfs", "artifacts", "terraform_state",
    ])
    node_selector = optional(map(string), {
      provisioner = "gitlab-base"
      nodetype    = "gitlab-base"
    })
    tolerations = optional(list(object({
      key      = string
      value    = optional(string)
      effect   = string
      operator = optional(string)
    })), [{ key = "gitlab-base", value = "true", effect = "NoSchedule" }])
    pod_annotations = optional(map(string), { "karpenter.sh/do-not-disrupt" = "true" })
    resources       = optional(any, { requests = { cpu = "500m", memory = "1G" } })
  })

  default = {}
}