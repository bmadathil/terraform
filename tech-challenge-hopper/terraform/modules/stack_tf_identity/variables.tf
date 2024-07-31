# variables.tf

variable "bucket_name" {
  description = "The name of the S3 bucket for storing the Terraform state"
  type        = string
}

variable "bucket_key" {
  description = "The key path within the bucket for the Terraform state file"
  type        = string
}

variable "region" {
  description = "The AWS region where the S3 bucket is located"
  type        = string
}
variable "CLUSTER_NAME" {
  description = "The AWS EKS Cluster Name"
  type        = string
}
variable "github_user" {
  description = "The Github User Name"
  type        = string
}
variable "github_pat" {
  description = "The Github Pat Name"
  type        = string
}
variable "CLUSTER_DOMAIN" {
  description = "The AWS EKS Cluster Domain"
  type        = string
}
