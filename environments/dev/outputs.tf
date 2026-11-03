output "vpc_id" {
  description = "ID of the platform VPC."
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "github_plan_role_arn" {
  description = "Set as the AWS_ROLE_ARN repository variable to enable plan-on-PR."
  value       = module.github_oidc.role_arn
}

output "kubeconfig_command" {
  description = "Command to configure kubectl for this cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
