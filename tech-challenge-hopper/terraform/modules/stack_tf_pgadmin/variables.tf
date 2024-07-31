variable "region" {
  description = "Aws Regsion"
  type        = string
  default     = "us-east-1"
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
variable "hosted_zone" {
  description = "hosted_zone"
  type        = string
}


