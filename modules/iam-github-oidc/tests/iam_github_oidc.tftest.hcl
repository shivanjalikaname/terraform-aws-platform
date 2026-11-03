mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  # The real data source renders JSON; the mock must too, or aws_iam_role rejects it
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  role_name    = "github-plan"
  repositories = ["shivanjalikaname/terraform-aws-platform"]
}

run "main_branch_only_by_default" {
  command = plan

  assert {
    condition     = output.allowed_subjects == ["repo:shivanjalikaname/terraform-aws-platform:ref:refs/heads/main"]
    error_message = "By default only the main branch should be trusted."
  }
}

run "pull_requests_and_environments" {
  command = plan

  variables {
    allow_pull_requests  = true
    allowed_environments = ["production"]
  }

  assert {
    condition     = contains(output.allowed_subjects, "repo:shivanjalikaname/terraform-aws-platform:pull_request")
    error_message = "allow_pull_requests should add the pull_request subject."
  }

  assert {
    condition     = contains(output.allowed_subjects, "repo:shivanjalikaname/terraform-aws-platform:environment:production")
    error_message = "allowed_environments should add environment subjects."
  }

  assert {
    condition     = length(output.allowed_subjects) == 3
    error_message = "Expected exactly main, pull_request and one environment subject."
  }
}

run "reuses_existing_provider" {
  command = plan

  variables {
    create_oidc_provider = false
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "No provider should be created when create_oidc_provider is false."
  }
}

run "rejects_wildcard_repository" {
  command = plan

  variables {
    repositories = ["shivanjalikaname/*"]
  }

  expect_failures = [var.repositories]
}

run "rejects_empty_repository_list" {
  command = plan

  variables {
    repositories = []
  }

  expect_failures = [var.repositories]
}
