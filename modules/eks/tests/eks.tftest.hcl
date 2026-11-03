mock_provider "aws" {
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
  name       = "platform-test"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]

  node_groups = {
    general = {
      instance_types = ["t3.large"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
    }
  }
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access == false
    error_message = "The API endpoint must be private by default."
  }

  assert {
    condition     = aws_kms_key.secrets.enable_key_rotation
    error_message = "Secrets encryption key must rotate."
  }

  assert {
    condition     = aws_launch_template.node["general"].metadata_options[0].http_tokens == "required"
    error_message = "Nodes must enforce IMDSv2."
  }

  assert {
    condition     = aws_launch_template.node["general"].block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "Node root volumes must be encrypted."
  }

  assert {
    condition     = aws_eks_node_group.this["general"].capacity_type == "ON_DEMAND"
    error_message = "capacity_type should default to ON_DEMAND."
  }
}

run "one_node_group_per_entry" {
  command = plan

  variables {
    node_groups = {
      system = { instance_types = ["m6i.large"], min_size = 2, max_size = 3, desired_size = 2 }
      spot   = { instance_types = ["m6i.large", "m5.large"], capacity_type = "SPOT", min_size = 0, max_size = 5, desired_size = 1 }
    }
  }

  assert {
    condition     = length(aws_eks_node_group.this) == 2 && aws_eks_node_group.this["spot"].capacity_type == "SPOT"
    error_message = "Expected one managed node group per map entry with its own capacity type."
  }
}

run "installs_default_addons" {
  command = plan

  assert {
    condition     = length(aws_eks_addon.this) == 4 && contains(keys(aws_eks_addon.this), "vpc-cni")
    error_message = "Expected the four default add-ons."
  }
}

run "rejects_world_open_api" {
  command = plan

  variables {
    endpoint_public_access = true
    public_access_cidrs    = ["0.0.0.0/0"]
  }

  expect_failures = [var.public_access_cidrs]
}

run "rejects_bad_scaling" {
  command = plan

  variables {
    node_groups = {
      general = { instance_types = ["t3.large"], min_size = 3, max_size = 2, desired_size = 2 }
    }
  }

  expect_failures = [var.node_groups]
}

run "rejects_single_subnet" {
  command = plan

  variables {
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaa1"]
  }

  expect_failures = [var.subnet_ids]
}
