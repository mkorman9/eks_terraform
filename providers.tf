provider "aws" {
  region  = "${var.aws_region}"
}

provider "template" {
}

provider "kubernetes" {
  host                   = aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = aws_eks_cluster.cluster.token
  load_config_file       = false
}
