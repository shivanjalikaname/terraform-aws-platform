mock_provider "aws" {
  # The real data source renders JSON; the mock must too, or aws_iam_role rejects it
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  name = "test-vpc"
  cidr = "10.0.0.0/16"
  azs  = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  tags = { Environment = "test" }
}

run "subnet_layout" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 3 && length(aws_subnet.private) == 3
    error_message = "Expected one public and one private subnet per AZ."
  }

  assert {
    condition     = aws_subnet.public[0].cidr_block == "10.0.0.0/20" && aws_subnet.public[2].cidr_block == "10.0.32.0/20"
    error_message = "Public subnets should be carved from the start of the VPC range."
  }

  assert {
    condition     = aws_subnet.private[0].cidr_block == "10.0.128.0/20"
    error_message = "Private subnets should start halfway through the VPC range."
  }

  assert {
    condition     = aws_vpc.this.tags["Name"] == "test-vpc" && aws_vpc.this.tags["Environment"] == "test"
    error_message = "VPC should carry its Name and the caller's tags."
  }
}

run "single_nat_shares_one_gateway" {
  command = plan

  variables {
    nat_mode = "single"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single mode should create exactly one NAT gateway."
  }

  assert {
    condition     = length(aws_route.private_nat) == 3
    error_message = "Every private route table still needs a default route."
  }
}

run "per_az_nat_is_highly_available" {
  command = plan

  variables {
    nat_mode = "per_az"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3 && length(aws_eip.nat) == 3
    error_message = "per_az mode should create one NAT gateway and EIP per AZ."
  }
}

run "no_nat_means_no_default_route" {
  command = plan

  variables {
    nat_mode = "none"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0 && length(aws_route.private_nat) == 0
    error_message = "none mode should create no NAT gateways or private default routes."
  }
}

run "eks_discovery_tags" {
  command = plan

  variables {
    eks_cluster_name = "platform-test"
  }

  assert {
    condition     = aws_subnet.private[0].tags["kubernetes.io/cluster/platform-test"] == "shared"
    error_message = "Subnets must be tagged for the EKS cluster so load balancers can find them."
  }
}

run "flow_logs_can_be_disabled" {
  command = plan

  variables {
    enable_flow_logs = false
  }

  assert {
    condition     = length(aws_flow_log.this) == 0 && length(aws_iam_role.flow_logs) == 0
    error_message = "Disabling flow logs should remove the log, its role and log group."
  }
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    cidr = "10.0.0.0/8"
  }

  expect_failures = [var.cidr]
}

run "rejects_single_az" {
  command = plan

  variables {
    azs = ["ap-south-1a"]
  }

  expect_failures = [var.azs]
}

run "rejects_unknown_nat_mode" {
  command = plan

  variables {
    nat_mode = "multi"
  }

  expect_failures = [var.nat_mode]
}
