variable "k8s_version" {
  description = "Kubernete version "
  type        = string
}
variable "region" {
  description = "The region to deploy resources in"
  type        = string
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "bucket_key" {
  description = "The key for the S3 bucket"
  type        = string
}

variable "CLUSTER_NAME" {
  description = "The name of the cluster"
  type        = string
}
variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
}

variable "github_user" {
  description = "The GitHub username"
  type        = string
}

variable "github_pat" {
  description = "The GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "CLUSTER_DOMAIN" {
  description = "The domain name for the cluster"
  type        = string
}

variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
}
variable "namespaces" {
  type = list(object({
    name = string
  }))
  description = "List of namespaces to create"
}
variable "kubeconfig" {
  type        = string
  description = "Path to the kubeconfig file"
  default     = "/tmp/kubeconfig"
}
variable "AWS_ACCESS_KEY_ID" {
  type        = string
  description = "AWS Access Key ID"
}
variable "AWS_SECRET_ACCESS_KEY" {
  type        = string
  description = "AWS Secret Access Key"
  sensitive   = true
}

variable "hosted_zone" {
  description = "Hosted Zone in AWS"
  type        = string
}

