data "http" "metrics_server_manifest" {
  url = "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
}

data "kubectl_file_documents" "metrics_server_manifest_docs" {
    content = data.http.metrics_server_manifest.body
}

resource "kubectl_manifest" "metrics_server_manifest" {
  depends_on = [aws_eks_node_group.default_node_group]
  for_each   = data.kubectl_file_documents.metrics_server_manifest_docs.manifests

  yaml_body = each.value
}
