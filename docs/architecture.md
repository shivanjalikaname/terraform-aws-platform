# Architecture

## Network and cluster

```mermaid
flowchart TB
    subgraph VPC["VPC 10.20.0.0/16 (prod)"]
        direction TB
        IGW[Internet gateway]

        subgraph AZa["AZ a"]
            PUBa[Public /20<br/>ALB, NAT]
            PRIa[Private /20<br/>nodes, pods]
        end
        subgraph AZb["AZ b"]
            PUBb[Public /20<br/>ALB, NAT]
            PRIb[Private /20<br/>nodes, pods]
        end
        subgraph AZc["AZ c"]
            PUBc[Public /20<br/>ALB, NAT]
            PRIc[Private /20<br/>nodes, pods]
        end

        IGW --- PUBa & PUBb & PUBc
        PRIa -- default route --> PUBa
        PRIb -- default route --> PUBb
        PRIc -- default route --> PUBc
    end

    EKS[EKS control plane<br/>private endpoint, KMS-encrypted secrets] -.ENIs.- PRIa & PRIb & PRIc
    FL[VPC flow logs] --> CW[(CloudWatch Logs)]
    EKS --> CW
```

- **Subnet plan.** Public subnets use the low `/20`s of the VPC; private subnets start at the
  halfway point. Adding a fourth AZ later doesn't renumber anything.
- **Egress.** `per_az` NAT (prod) keeps each AZ's egress independent, so losing one AZ doesn't cut
  outbound traffic for the others. Dev uses a `single` NAT to save cost.
- **Load balancers.** Subnets carry `kubernetes.io/role/elb` / `internal-elb` and the cluster tag, so the
  AWS Load Balancer Controller discovers them without extra configuration.

## CI identity

```mermaid
sequenceDiagram
    participant GH as GitHub Actions job
    participant OIDC as token.actions.githubusercontent.com
    participant STS as AWS STS
    participant AWS as AWS APIs

    GH->>OIDC: request ID token (aud=sts.amazonaws.com)
    OIDC-->>GH: signed JWT, sub=repo:owner/name:pull_request
    GH->>STS: AssumeRoleWithWebIdentity(role, JWT)
    STS->>STS: check issuer, aud, and sub against trust policy
    STS-->>GH: 1h credentials (ReadOnlyAccess)
    GH->>AWS: terraform plan
```

No long-lived keys exist anywhere. The trust policy pins the exact repository and ref, so a fork,
another repository, or a feature branch cannot assume the role. In prod, pull requests are not trusted at all.

## State

Each environment has its own state file in S3 with `use_lockfile = true` (native S3 locking,
Terraform 1.10+), so no DynamoDB lock table is required. Environments share modules but never state:
a mistake in dev cannot touch prod.
