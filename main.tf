locals {
    cluster_name = "${var.environment}-cluster"
}

/*
    VPC
*/
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = "${var.environment}-eks-vpc"

  cidr = "10.1.0.0/16"

  azs            = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  public_subnets = ["10.1.0.0/18", "10.1.64.0/18"]

  enable_nat_gateway = false

  tags = {
    Environment = var.environment
  }

  public_subnet_tags = tomap({
    "kubernetes.io/role/elb" = "1"
  })

  private_subnet_tags = tomap({
    "kubernetes.io/role/internal-elb" = "1"
  })
}

/*
    IAM
*/
resource "aws_iam_role" "cluster" {
  name = "${var.environment}-eks-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role" "node" {
  name = "${var.environment}-eks-node-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.environment}-eks-node-profile"
  role = aws_iam_role.node.name
}

data "tls_certificate" "cluster_cert" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "openid_provider" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster_cert.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

/*
    EC2
*/
resource "aws_security_group" "cluster_sg" {
  name   = "${var.environment}-cluster-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
  }
}

/*
    EKS
*/
resource "aws_eks_cluster" "cluster" {
  name     = local.cluster_name
  version  = "1.22"
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.cluster_sg.id]
    subnet_ids         = module.vpc.public_subnets
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy,
  ]
}

resource "aws_eks_node_group" "default_node_group" {
  cluster_name    = local.cluster_name
  node_group_name = "${var.environment}-default-node-group"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = module.vpc.public_subnets

  scaling_config {
    desired_size = var.nodes
    max_size     = var.nodes
    min_size     = var.nodes
  }

  instance_types = [
    var.node_type
  ]

  depends_on = [
    aws_eks_cluster.cluster,
    aws_iam_role_policy_attachment.node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node-AmazonEC2ContainerRegistryReadOnly
  ]

  tags = {
    Environment = var.environment
  }
}

resource "kubectl_manifest" "project_namespace" {
  depends_on = [aws_eks_cluster.cluster]

  yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.namespace}
YAML
}
