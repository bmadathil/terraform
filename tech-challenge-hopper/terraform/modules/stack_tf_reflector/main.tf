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

locals {
  crds = {
    reflector     = "${path.module}/crd/reflector.yaml"
  }
}

resource "null_resource" "apply_crds" {
  for_each = local.crds

  provisioner "local-exec" {
    command = "kubectl --kubeconfig=/tmp/kubeconfig apply -f ${each.value} -n kube-system"
  }
}

