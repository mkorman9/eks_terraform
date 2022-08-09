data "http" "metrics_server_manifest" {
  url = "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
}

resource "kubectl_manifest" "metrics_server_manifest" {
  yaml_body = data.http.metrics_server_manifest.body
}
