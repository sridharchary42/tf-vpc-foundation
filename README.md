# tf-vpc-foundation

This started as a VPC-only build and grew into a small end-to-end platform, all built with Terraform, all in one repo. It now covers three layers: networking, a load-balanced compute tier with auto scaling, and an EKS cluster with real observability and audit logging behind it.

## VPC foundation

A custom AWS VPC built from scratch, no default VPC involved. It creates a VPC, two public subnets, two private subnets across two Availability Zones, an Internet Gateway, and route tables wired up correctly.

**What this shows:** writing modular, reusable Terraform (variables, data sources, count-based resource loops), understanding VPC networking fundamentals like CIDR planning, subnet tiers, and route tables, and tagging everything consistently for cost tracking and ownership.

## Compute: Auto Scaling behind a Load Balancer

Built directly on top of the VPC above. A Launch Template pulls the latest Amazon Linux 2023 AMI through a data source rather than a hardcoded AMI ID, so the fleet never drifts onto a stale, unpatched image. Instances run on `t3.micro`, sit in an Auto Scaling Group spread across both public subnets, and are fronted by an Application Load Balancer doing health checks against a target group. If an instance fails a health check, the ASG replaces it automatically. If an Availability Zone goes down, the other one keeps serving traffic.

Security groups are locked down on purpose: SSH is restricted to a single known IP, and the only public entry point is the ALB on ports 80/443. Instances themselves are never exposed directly to the internet.

**What this shows:** I don't reach for a single EC2 instance when the job calls for something that survives failure. Health checks, multi-AZ spread, and least-privilege security groups are the baseline I build to, not an afterthought I add later.

## Monitoring and automated scaling

A CloudWatch metric alarm tracks average CPU utilization across the Auto Scaling Group. When it crosses a threshold, it triggers a scaling policy that adds capacity on its own, no one has to be paged to click a button at 2am because traffic spiked.

That loop, metric feeds an alarm, the alarm triggers an automated action, is the same pattern behind real production autoscaling and a lot of incident response tooling. I built it here at small scale so I understand exactly what's happening under the hood, not just what button to press in a console.

## EKS: Kubernetes with real observability, not just a cluster that boots

This is the deepest piece in the repo. It's a managed EKS cluster (`tf-vpc-foundation-eks`, Kubernetes 1.30) with a node group running on `t3.micro`, but the point of this project wasn't just getting a cluster running. It was building out the operational layer around it that actually matters once something is in production:

- **Control-plane logging**: API, audit, and authenticator logs stream straight to CloudWatch Logs, so there's an audit trail of everything happening at the cluster's control plane.
- **Container Insights**: the CloudWatch observability addon gives live CPU, memory, and pod-level metrics for the whole cluster, not just the EC2 layer underneath it.
- **CloudWatch alarms**: watching node CPU, the same automated-response pattern as the compute project above, just extended into Kubernetes.
- **CloudTrail**: a dedicated trail logging every management API call against the account, backed by its own S3 bucket with a locked-down bucket policy.
- **A real workload**: an nginx Deployment and Service running across both nodes, because a cluster with nothing deployed on it doesn't prove anything.

The part I'd actually want to talk about in an interview: getting Container Insights running here wasn't a straight path. `t3.micro` has a hard limit of 4 pods per node, which is an IP-address ceiling tied to how many ENIs the instance supports, not a CPU or memory limit. Once system pods and the CNI were accounted for, there was no room left for the observability agent, and it sat stuck for 27 minutes before timing out. I fixed it properly instead of just throwing a bigger, non-free-tier instance at the problem: enabled VPC CNI prefix delegation to give nodes more usable IP addresses, then attached a custom launch template that raises the kubelet's pod ceiling to actually use that extra capacity. Along the way I also hit an EKS quirk where custom node bootstrap data has to be wrapped in MIME multipart format, not passed as plain YAML, and a separate issue where Terraform's tag management fought itself over subnet tags shared between two resources, which I fixed with a `lifecycle` block instead of letting it flap on every apply.

**What this shows:** I can operate Kubernetes past the "it's running" stage. I read the actual error, understood why a resource constraint was the real cause instead of guessing, and fixed the root cause instead of masking it with more expensive infrastructure. That's the kind of debugging a platform or DevOps role runs into weekly, not just in tutorials.

## Cost

The VPC layer is permanently free: the VPC, subnets, Internet Gateway, and route tables cost nothing regardless of how long they run. The compute and EKS layers are not free. The ALB, the NAT Gateway, and the EKS control plane all bill by the hour, and EKS in particular is never free-tier eligible. None of this is expensive at this scale, a few cents an hour at most, but it's not zero, which is exactly why everything below gets destroyed after screenshots.

## Prerequisites

- An AWS account and an IAM user (not root) with the relevant permissions
- Terraform 1.5 or newer
- AWS CLI v2, configured with `aws configure`
- `kubectl`, for interacting with the EKS cluster

## Run it

\```bash
terraform init
terraform plan
terraform apply
\```

This single `apply` builds all three layers together, since they all live in one Terraform state.

## Verify in the AWS Console

- VPC dashboard: confirm the VPC and its CIDR block
- Subnets: 4 subnets total, 2 public and 2 private, spread across 2 AZs
- Route Tables: the public one has a 0.0.0.0/0 route to the Internet Gateway, the private one doesn't
- EC2: confirm the Auto Scaling Group and Load Balancer are healthy
- EKS: cluster status Active, node group status Active
- CloudWatch: Container Insights showing live metrics, alarms in OK state
- CloudTrail: trail logging, recent events showing up in Event History

## Tear it down

\```bash
terraform destroy
\```

Confirm in the console afterward that the ALB, node group, and EKS cluster are actually gone, since those are the pieces that cost money if left running.

## What I'd do differently in production

- Use remote state (S3 with DynamoDB locking) instead of local state
- Separate environments with workspaces or separate state files
- Enforce tagging and CIDR standards automatically with policy as code, like OPA or Sentinel
- Replace the custom max-pods workaround with right-sized nodes or Karpenter once cost isn't the primary constraint
- Put an ingress controller in front of the nginx workload instead of relying on `kubectl` port-forwarding for access