terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig
}


#github_user = var.github_user
#github_pat  = var.github_pat


resource "kubernetes_secret" "ghcr_pull_secret" {
  metadata {
    name = "ghcr-pull-secret"
    annotations = {
      "reflector.v1.k8s.emberstack.com/reflection-allowed"      = "true"
      "reflector.v1.k8s.emberstack.com/reflection-auto-enabled" = "true"
      "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces" = join(",", [for ns in var.namespaces : ns.name])
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          auth = base64encode("${var.github_user}:${var.github_pat}")
        }
      }
    })
  }
}
