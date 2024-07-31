
variable "kubeconfig" {
  type = string
  default = "/tmp/kubeconfig"
}
variable "cluster_name" {
  type = string
}
variable "region" {
  type = string
  default = "us-east-1"
}
variable "certificate_server" {
  type = string
  default = "https://acme-v02.api.letsencrypt.org/directory"
}
#  default = "https://acme-v02.api.letsencrypt.org/directory"
#  default = "https://acme-staging-v02.api.letsencrypt.org/directory"
