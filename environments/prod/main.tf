locals {
  environment = "prod"
  name        = "platform-${local.environment}"

  tags = {
    Environment = local.environment
    Project     = "terraform-aws-platform"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name             = local.name
  cidr             = "10.20.0.0/16" # non-overlapping with dev so the VPCs can be peered later
  azs              = ["${var.region}a", "${var.region}b", "${var.region}c"]
  nat_mode         = "per_az" # an AZ outage must not take down egress for the others
  eks_cluster_name = local.name

  flow_log_retention_days = 90
}

module "eks" {
  source = "../../modules/eks"

  name               = local.name
  kubernetes_version = "1.34"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids

  # Private API only: access via VPN / bastion / SSM
  endpoint_public_access = false

  node_groups = {
    system = {
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"
      min_size       = 3
      max_size       = 6
      desired_size   = 3
      labels         = { workload = "system" }
    }
    apps = {
      instance_types = ["m6i.xlarge", "m6a.xlarge", "m5.xlarge"]
      capacity_type  = "ON_DEMAND"
      min_size       = 3
      max_size       = 12
      desired_size   = 3
      labels         = { workload = "apps" }
    }
  }

  cluster_log_types  = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  log_retention_days = 90
}

module "github_oidc" {
  source = "../../modules/iam-github-oidc"

  role_name    = "${local.name}-github-plan"
  repositories = ["shivanjalikaname/terraform-aws-platform"]
  allowed_refs = ["refs/heads/main"]
  # Prod changes only from main, never from PR workflows
  allow_pull_requests  = false
  policy_arns          = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  create_oidc_provider = true
}
