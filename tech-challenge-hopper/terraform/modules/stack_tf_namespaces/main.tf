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


resource "kubernetes_namespace" "namespaces" {
  for_each = { for ns in var.namespaces : ns.name => ns }

  metadata {
    name = each.value.name
  }
}

resource "kubernetes_role" "default_role" {
  for_each = kubernetes_namespace.namespaces

  metadata {
    name      = "default-role"
    namespace = each.value.metadata[0].name
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "patch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "patch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding" "default_role_binding" {
  for_each = kubernetes_namespace.namespaces

  metadata {
    name      = "default-role-binding"
    namespace = each.value.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "default-role"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = each.value.metadata[0].name
  }

  depends_on = [kubernetes_role.default_role]
}
