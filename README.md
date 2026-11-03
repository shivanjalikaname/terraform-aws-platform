# terraform-aws-platform

[![ci](https://github.com/shivanjalikaname/terraform-aws-platform/actions/workflows/ci.yml/badge.svg)](https://github.com/shivanjalikaname/terraform-aws-platform/actions/workflows/ci.yml)
![Terraform](https://img.shields.io/badge/terraform-%E2%89%A51.10-7B42BC)
![AWS provider](https://img.shields.io/badge/aws%20provider-6.x-FF9900)

Production-style AWS foundations in Terraform: a VPC, an EKS cluster and keyless CI access,
built as small reusable modules and composed into separate dev and prod environments.

Everything is validated, linted, security-scanned and unit-tested in CI **without AWS credentials**,
using `terraform test` with mock providers.

## What's inside

| Module | Purpose | Highlights |
|--------|---------|-----------|
| [`modules/vpc`](modules/vpc) | Network foundation | Multi-AZ public/private subnets, NAT `single`/`per_az`/`none`, flow logs, locked-down default SG, EKS subnet tags |
| [`modules/eks`](modules/eks) | Kubernetes | Private API by default, KMS secrets encryption with explicit key policy, IRSA, managed node groups with IMDSv2 and encrypted gp3, managed add-ons |
| [`modules/iam-github-oidc`](modules/iam-github-oidc) | CI identity | GitHub Actions OIDC role pinned to repo + ref/environment, optional PR access for read-only plans |

| Environment | VPC | NAT | API endpoint | Nodes |
|-------------|-----|-----|--------------|-------|
| [`dev`](environments/dev) | 10.10.0.0/16, 2 AZs | single | public, restricted CIDRs | 1 spot group, 1–4 nodes |
| [`prod`](environments/prod) | 10.20.0.0/16, 3 AZs | per AZ | private only | system + apps groups, on-demand, 3–12 nodes |

See [docs/architecture.md](docs/architecture.md) for diagrams of the network and the CI identity flow.

## Using a module

```hcl
module "vpc" {
  source = "github.com/shivanjalikaname/terraform-aws-platform//modules/vpc?ref=main"

  name             = "payments"
  cidr             = "10.30.0.0/16"
  azs              = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  nat_mode         = "per_az"
  eks_cluster_name = "payments"
}

module "eks" {
  source = "github.com/shivanjalikaname/terraform-aws-platform//modules/eks?ref=main"

  name       = "payments"
  subnet_ids = module.vpc.private_subnet_ids

  node_groups = {
    general = { instance_types = ["m6i.large"], min_size = 2, max_size = 6, desired_size = 2 }
  }
}
```

## Deploying an environment

```bash
cd environments/dev
terraform init          # S3 backend with native locking
terraform plan
terraform apply
$(terraform output -raw kubeconfig_command)
```

The state bucket in [`versions.tf`](environments/dev/versions.tf) is a placeholder; create one first
(for example with the `remote-state-bootstrap` module in
[devops-toolkit](https://github.com/shivanjalikaname/devops-toolkit/tree/main/terraform/remote-state-bootstrap)).

## CI

| Job | What it checks |
|-----|----------------|
| fmt & validate | `terraform fmt -check` and `validate` for every module and environment |
| terraform test | 20 plan-time tests with mocked AWS: subnet maths, NAT layouts, secure EKS defaults, OIDC subjects, and that bad input is rejected |
| tflint | AWS ruleset (invalid instance types, deprecated arguments) plus naming and documentation rules |
| checkov | Security policies; every skip is inline with a written justification |
| plan (PRs) | Assumes the read-only OIDC role and comments the plan on the PR. Skipped until `AWS_ROLE_ARN` is set |

Third-party actions are pinned to full commit SHAs. Run the same checks locally with `make check`.

## Cost notes (ap-south-1, approximate)

- **EKS control plane:** ~$73/month per cluster.
- **NAT gateways:** ~$33/month each plus data processing. Dev runs one; prod runs one per AZ.
  For dev, `nat_mode = "none"` with VPC endpoints is cheaper if nodes don't need internet egress.
- **Nodes:** dev uses spot across three instance types to reduce interruptions.

## Design decisions

- **Modules stay small and opinionated.** Each one does one job, with validation on inputs that are
  easy to get wrong (CIDR sizes, AZ counts, scaling bounds, `0.0.0.0/0` on the API).
- **Secure by default, explicit when not.** The API endpoint is private unless a caller opts in with
  specific CIDRs; IMDSv2 is enforced with hop limit 1 so pods can't steal node credentials.
- **`desired_size` is ignored after creation** so the cluster autoscaler or Karpenter owns it without
  Terraform fighting it on every apply.
- **No static AWS keys.** CI authenticates with OIDC; prod trusts only `main`.
- **No DynamoDB lock table.** S3 native locking (`use_lockfile`) is simpler and cheaper.

## Layout

```
modules/
  vpc/  eks/  iam-github-oidc/      reusable modules, each with tests/*.tftest.hcl
environments/
  dev/  prod/                       root modules with their own state
docs/architecture.md                diagrams and rationale
.github/workflows/                  ci.yml (checks), plan.yml (OIDC plan on PR)
```

## License

[MIT](LICENSE)
