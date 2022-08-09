locals {
  lb-controller-service-account-manifest = <<SERVICEACCOUNT
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.lb_controller.arn}
automountServiceAccountToken: true
SERVICEACCOUNT
}

data "http" "lb_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.2/docs/install/iam_policy.json"
}

data "aws_iam_policy_document" "lb_controller_openid_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.openid_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.openid_provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "lb_controller" {
  assume_role_policy = data.aws_iam_policy_document.lb_controller_openid_policy.json
  name               = "${var.environment}-lb-controller"

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "lb_controller_policy" {
  name   = "${var.environment}-lb-controller-policy"
  role   = aws_iam_role.lb_controller.name
  policy = data.http.lb_iam_policy.body
}

resource "kubectl_manifest" "lb_controller_manifest" {
  depends_on = [aws_eks_cluster.cluster]

  yaml_body = local.lb-controller-service-account-manifest
}

resource "helm_release" "lb_controller" {
  depends_on = [aws_eks_node_group.default_node_group]

  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}
