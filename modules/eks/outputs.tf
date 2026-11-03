output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA bundle for kubeconfig."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN, for IRSA trust policies."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "node_role_arn" {
  description = "IAM role used by managed node groups."
  value       = aws_iam_role.node.arn
}

output "kms_key_arn" {
  description = "KMS key used for secrets encryption."
  value       = aws_kms_key.secrets.arn
}
