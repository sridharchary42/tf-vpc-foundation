resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.30"

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # Streams control-plane logs to CloudWatch automatically - this is the
  # "watch what's happening" layer for the cluster itself.
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = {
    Name        = "${var.project_name}-eks"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  instance_types = ["t3.micro"]
  capacity_type  = "ON_DEMAND"

  # Custom launch template so we can raise the kubelet's max-pods value.
  # t3.micro's default max-pods (based on ENI/IP capacity) is only 4 -
  # not enough room for system pods + fluent-bit + Container Insights.
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only,
  ]

  tags = {
    Name        = "${var.project_name}-eks-node"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Tags EKS needs to auto-discover subnets for future load balancers/ingress.
resource "aws_ec2_tag" "public_elb" {
  count       = length(aws_subnet.public)
  resource_id = aws_subnet.public[count.index].id
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_internal_elb" {
  count       = length(aws_subnet.private)
  resource_id = aws_subnet.private[count.index].id
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "public_cluster" {
  count       = length(aws_subnet.public)
  resource_id = aws_subnet.public[count.index].id
  key         = "kubernetes.io/cluster/${aws_eks_cluster.main.name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_cluster" {
  count       = length(aws_subnet.private)
  resource_id = aws_subnet.private[count.index].id
  key         = "kubernetes.io/cluster/${aws_eks_cluster.main.name}"
  value       = "shared"
}