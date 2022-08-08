locals {
  service-account = <<SERVICEACCOUNT
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${var.service_account}
  namespace: ${var.namespace}
  annotations:
    eks.amazonaws.com/role-arn: ${aws_iam_role.app_role.arn}
automountServiceAccountToken: true
SERVICEACCOUNT

  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.cluster.certificate_authority.0.data}
  name: ${local.cluster_name}
contexts:
- context:
    cluster: ${local.cluster_name}
    user: ${local.cluster_name}
  name: ${local.cluster_name}
current-context: ${local.cluster_name}
kind: Config
preferences: {}
users:
- name: ${local.cluster_name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws
      args:
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "${local.cluster_name}"
        - "--region"
        - "${var.aws_region}"
KUBECONFIG
}

output "service-account-yml" {
  value = local.service-account
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}
