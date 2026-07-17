output "role_name" {
  description = "Name of IAM role"
  value       = module.gitlab_role.arn
}

output "role_arn" {
  description = "ARN of IAM role"
  value       = module.gitlab_role.arn

}

output "buckets" {
  description = "List of buckets created"
  value = tomap({
    for k, v in module.s3_bucket : k => v.s3_bucket_arn
  })
}

output "lean_backup_cronjob_name" {
  description = "Name of the lean backup CronJob, or null when lean_backup is disabled"
  value       = var.lean_backup.enabled ? local.lean_name : null
}