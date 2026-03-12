output "role_name" {
  description = "Name of IAM role"
  value       = module.gitlab_role.iam_role_name
}

output "role_arn" {
  description = "ARN of IAM role"
  value       = module.gitlab_role.iam_role_arn

}

output "buckets" {
  description = "List of buckets created"
  value = tomap({
    for k, v in module.s3_bucket : k => v.s3_bucket_arn
  })
}