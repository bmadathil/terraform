terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}

locals {
  external_secrets = "external-secrets"
  namespace        = "kube-system"
}

resource "helm_release" "external_secrets" {
  name       = local.external_secrets
  namespace  = local.namespace
  chart      = "${path.module}/external-secrets"
}

