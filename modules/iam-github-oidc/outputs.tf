output "role_arn" {
  description = "ARN to use as role-to-assume in aws-actions/configure-aws-credentials."
  value       = aws_iam_role.this.arn
}

output "allowed_subjects" {
  description = "OIDC subject claims permitted to assume the role."
  value       = local.subjects
}
