locals {
  aws_auth = <<CONFIGMAPAWSAUTH
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.instance.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
CONFIGMAPAWSAUTH

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

output "config-map-aws-auth" {
  value = "${local.aws_auth}"
}

output "kubeconfig" {
  value = "${local.kubeconfig}"
}
