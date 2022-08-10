variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region. For example: eu-central-1"
  type        = string
}

variable "node_type" {
  description = "Type of node inside autoscaling group. By default: t3.medium"
  type        = string
  default     = "t3.medium"
}

variable "nodes" {
  description = "Nodes count in the cluster"
  type        = number
  default     = 1
}

variable "namespace" {
  description = "Cluster namespace to operate on (by default: default)"
  type        = string
  default     = "default"
}

variable "app_role_service_account" {
  description = "Name of service account to associate with app role"
  type        = string
  default     = "app"
}
