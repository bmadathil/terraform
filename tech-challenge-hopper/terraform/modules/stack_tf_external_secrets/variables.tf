
variable "kubeconfig" {
  type = string
  default = "/tmp/kubeconfig"
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
variable "namespaces" {
  type = list(object({
    name = string
  }))
  description = "List of namespaces"
}

