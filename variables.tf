variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region. For example: eu-central-1"
  type        = string
}

variable "instance_type" {
  description = "Type of instance inside Autoscaling group. By default: t2.micro"
  type        = string
  default     = "t2.micro"
}

variable "instances" {
  description = "Instance count in the cluster"
  type        = number
  default     = 1
}

variable "namespace" {
  description = "Cluster namespace (by default: default)"
  type        = string
  default     = "default"
}

variable "service_account" {
  description = "Name of service account to associate with app role"
  type        = string
  default     = "app"
}
