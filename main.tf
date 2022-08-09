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

resource "aws_iam_role" "instance" {
  name = "${var.environment}-eks-instance-role"

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

resource "aws_iam_role_policy_attachment" "instance-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.instance.name
}

resource "aws_iam_role_policy_attachment" "instance-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.instance.name
}

resource "aws_iam_role_policy_attachment" "instance-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.instance.name
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.environment}-eks-instance-profile"
  role = aws_iam_role.instance.name
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

resource "aws_security_group" "cluster_instance_sg" {
  name   = "${var.environment}-cluster-instance-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "TCP"
    security_groups = [aws_security_group.cluster_sg.id]
  }

  ingress {
    from_port       = 1025
    to_port         = 65535
    protocol        = "UDP"
    security_groups = [aws_security_group.cluster_sg.id]
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

resource "aws_security_group_rule" "cluster_instance_sg_self_rule" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = -1

  security_group_id        = aws_security_group.cluster_instance_sg.id
  source_security_group_id = aws_security_group.cluster_instance_sg.id
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

resource "aws_eks_node_group" "node_group" {
  cluster_name    = local.cluster_name
  node_group_name = "${var.environment}-default-node-group"
  node_role_arn   = aws_iam_role.instance.arn
  subnet_ids      = module.vpc.public_subnets

  scaling_config {
    desired_size = var.instances
    max_size     = var.instances
    min_size     = var.instances
  }

  instance_types = [
    var.instance_type
  ]

  depends_on = [
    aws_eks_cluster.cluster,
    aws_iam_role_policy_attachment.instance-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.instance-AmazonEKS_CNI_Policy
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
