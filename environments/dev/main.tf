locals {
  environment = "dev"
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
  cidr             = "10.10.0.0/16"
  azs              = ["${var.region}a", "${var.region}b"]
  nat_mode         = "single" # one NAT saves ~$35/month per AZ; acceptable outage risk for dev
  eks_cluster_name = local.name

  flow_log_retention_days = 7
}

module "eks" {
  source = "../../modules/eks"

  name               = local.name
  kubernetes_version = "1.34"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids

  # Public endpoint restricted to known ranges so engineers can use kubectl without a VPN
  endpoint_public_access = true
  public_access_cidrs    = var.api_allowed_cidrs

  node_groups = {
    general = {
      instance_types = ["t3.large", "t3a.large", "m5.large"] # several types improve spot availability
      capacity_type  = "SPOT"
      min_size       = 1
      max_size       = 4
      desired_size   = 2
    }
  }

  log_retention_days = 7
}

module "github_oidc" {
  source = "../../modules/iam-github-oidc"

  role_name            = "${local.name}-github-plan"
  repositories         = ["shivanjalikaname/terraform-aws-platform"]
  allowed_refs         = ["refs/heads/main"]
  allow_pull_requests  = true # PRs run plan only, so the role is read-only
  policy_arns          = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  create_oidc_provider = true
}
