variable "release_name" {
  description = "Name of the GitLab Helm release, used in the IAM role name"
  type        = string
  default     = "gitlab"
}

variable "release_namespace" {
  description = "Namespace GitLab runs in, used in the IAM role's OIDC subject. If empty, `release_name` will be used."
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "EKS cluster name whose OIDC provider the IAM role trusts"
  type        = string
}

variable "values" {
  description = "The GitLab chart values (list of YAML strings, first one is read); the S3 bucket names are derived from it"
  type        = any
  default     = []
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
