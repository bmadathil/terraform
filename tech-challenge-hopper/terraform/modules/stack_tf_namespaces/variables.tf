variable "kubeconfig" {
  type        = string
  description = "Path to the kubeconfig file"
  default     = "/tmp/kubeconfig"
}

variable "namespaces" {
  type = list(object({
    name = string
  }))
  description = "List of namespaces to create"
}
