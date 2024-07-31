variable "region" {
  description = "Aws Regsion"
  type        = string
  #default     = "us-east-1"
}
variable "cluster_name" {
  description = "Cluster Name"
  type        = string
}
variable "kubeconfig" {
  description = "kubeconfig context "
  type        = string
  default     = "/tmp/kubeconfig"
}
variable "namespace" {
  description = "namespace devops "
  type        = string
  default     = "devops"
}
variable "github_pat" {
  description = "github_pat "
  type        = string
}

variable "github_user" {
  description = "github_user "
  type        = string
}
variable "hosted_zone" {
  description = "hosted_zone"
  type        = string
}
variable "workload_git_repo" {
  description = "Argo CD workload_git_repo"
  type        = string
  default     = "https://github.com/cvp-challenges/practice-river-devops.git"
}

