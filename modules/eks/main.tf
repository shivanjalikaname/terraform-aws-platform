data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  policy_prefix = "arn:${data.aws_partition.current.partition}:iam::aws:policy"
  account_root  = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
}

# --- secrets encryption ---

# Explicit key policy: account admins manage the key, only the cluster role may use it
data "aws_iam_policy_document" "secrets_key" {
  # In a key policy "*" means this key only, and root-account administration is AWS's required default statement
  #checkov:skip=CKV_AWS_109:Key policy resource "*" is scoped to this key
  #checkov:skip=CKV_AWS_111:Key policy resource "*" is scoped to this key
  #checkov:skip=CKV_AWS_356:Key policy resource "*" is scoped to this key
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }
  }

  statement {
    sid = "ClusterUse"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:ListGrants",
      "kms:CreateGrant",
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.cluster.arn]
    }
  }
}

resource "aws_kms_key" "secrets" {
  description             = "EKS secrets envelope encryption for ${var.name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.secrets_key.json
  tags                    = var.tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/eks/${var.name}"
  target_key_id = aws_kms_key.secrets.key_id
}

# --- control plane ---

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name_prefix        = "${var.name}-cluster-"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "${local.policy_prefix}/AmazonEKSClusterPolicy"
}

# Created up front so retention applies from the first log line (EKS would otherwise create it with no expiry)
resource "aws_cloudwatch_log_group" "cluster" {
  #checkov:skip=CKV_AWS_338:Retention is a per-environment cost decision (var.log_retention_days); export to S3 for long-term audit
  #checkov:skip=CKV_AWS_158:Encrypted at rest by default; a customer-managed key is opt-in via var.log_kms_key_arn
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_kms_key_arn
  tags              = var.tags
}

resource "aws_eks_cluster" "this" {
  #checkov:skip=CKV_AWS_37:Log types are configurable; prod enables all, dev keeps a cheaper subset
  #checkov:skip=CKV_AWS_39:Private by default; dev opts in with restricted public_access_cidrs (0.0.0.0/0 is rejected)
  name     = var.name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  enabled_cluster_log_types = var.cluster_log_types

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.endpoint_public_access ? var.public_access_cidrs : null
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.secrets.arn
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# --- IRSA: lets Kubernetes service accounts assume IAM roles ---

resource "aws_iam_openid_connect_provider" "this" {
  url            = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
  tags           = var.tags
}

# --- add-ons ---

resource "aws_eks_addon" "this" {
  for_each = toset(var.addons)

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags

  # coredns needs nodes to schedule onto
  depends_on = [aws_eks_node_group.this]
}
