locals {
  app-service-account-manifest = <<SERVICEACCOUNT
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${var.app_role_service_account}
  namespace: ${var.namespace}
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.app_role.arn}
automountServiceAccountToken: true
SERVICEACCOUNT
}

data "aws_iam_policy_document" "app_role_openid_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.openid_provider.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.app_role_service_account}"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.openid_provider.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "app_role" {
  assume_role_policy = data.aws_iam_policy_document.app_role_openid_policy.json
  name               = "${var.environment}-app-role"

  tags = {
    Environment = var.environment
  }
}

data "template_file" "app_role_policy" {
  template = file("${path.module}/policies/app_role_policy.json")
}

resource "aws_iam_role_policy" "app_role_policy" {
  name   = "${var.environment}-app-role-policy"
  role   = aws_iam_role.app_role.name
  policy = data.template_file.app_role_policy.rendered
}

resource "kubectl_manifest" "app_role_manifest" {
  depends_on = [aws_eks_cluster.cluster]
  yaml_body = local.app-service-account-manifest
}
