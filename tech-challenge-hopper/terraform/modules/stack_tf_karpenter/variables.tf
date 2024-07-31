variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "karpenter_namespace" {
  description = "Namespace for Karpenter"
  type        = string
  default     = "kube-system"
}

