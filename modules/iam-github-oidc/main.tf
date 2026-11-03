locals {
  issuer = "token.actions.githubusercontent.com"

  # The token's `sub` claim encodes where the workflow ran. Matching it exactly is what
  # stops any other repository, or another branch of this one, from assuming the role.
  subjects = concat(
    [for pair in setproduct(var.repositories, var.allowed_refs) : "repo:${pair[0]}:ref:${pair[1]}"],
    [for pair in setproduct(var.repositories, var.allowed_environments) : "repo:${pair[0]}:environment:${pair[1]}"],
    var.allow_pull_requests ? [for r in var.repositories : "repo:${r}:pull_request"] : [],
  )
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = "https://${local.issuer}"
  client_id_list = ["sts.amazonaws.com"]
  tags           = var.tags
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.issuer}"
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # StringLike so refs such as refs/tags/v* work; repositories themselves are validated to contain no wildcards
    condition {
      test     = "StringLike"
      variable = "${local.issuer}:sub"
      values   = local.subjects
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = toset(var.policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
