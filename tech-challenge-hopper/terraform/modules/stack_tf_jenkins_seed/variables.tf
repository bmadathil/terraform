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
variable "seed_folder" {
  description = "seed_folder "
  type        = string
  default     = "seed/river"
}
variable "seed_job_repo_url" {
  description = "seed_job_repo_url"
  type        = string
  default     = "https://github.com/cvpcorp/tech-challenge-hopper.git"
}
variable "workload_title" {
  description = "workload_title"
  type        = string
  default     = "River Tech Challenge CI/CD Pipelines"
}
variable "hosted_zone" {
  description = "hosted_zone"
  type        = string
}

