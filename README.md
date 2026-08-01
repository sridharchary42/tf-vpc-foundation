# tf-vpc-foundation

A custom AWS VPC built from scratch with Terraform — no default VPC involved. Creates a VPC, 2 public subnets, 2 private subnets across two Availability Zones, an Internet Gateway, and route tables wired up correctly.

## What this demonstrates
- Writing modular, reusable Terraform (variables, data sources, count-based resource loops)
- Understanding VPC networking fundamentals: CIDR planning, subnet tiers, route tables, IGW
- Consistent resource tagging for cost tracking and ownership

## Cost: $0, always
Every resource here — VPC, subnets, Internet Gateway, route tables — is permanently free on AWS. No NAT Gateway, no Elastic IP, nothing running. (NAT Gateway comes in the next project, since that's the one piece that costs money.)

## Prerequisites
- AWS account + an IAM user (not root) with VPC permissions
- Terraform >= 1.5
- AWS CLI v2, configured via `aws configure`

## Run it
```bash
terraform init
terraform plan
terraform apply
```

## Verify in the AWS Console
- VPC dashboard → confirm the VPC and CIDR
- Subnets → 4 subnets, 2 public / 2 private, across 2 AZs
- Route Tables → public has a `0.0.0.0/0 → igw` route, private doesn't
- Internet Gateways → attached to the VPC

## Tear it down
```bash
terraform destroy
```

## What I'd do differently in production
- Remote state (S3 + DynamoDB locking) instead of local state
- Separate environments via workspaces or separate state files
- Policy-as-code (OPA/Sentinel) to enforce tagging/CIDR standards automatically