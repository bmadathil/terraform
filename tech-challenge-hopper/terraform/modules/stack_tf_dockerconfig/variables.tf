
variable "github_user" {
  type = string
}

variable "github_pat" {
  type = string
}

variable "kubeconfig" {
  type = string
  default = "/tmp/kubeconfig"
}

variable "namespaces" {
  type = list(object({
    name = string
  }))
}
