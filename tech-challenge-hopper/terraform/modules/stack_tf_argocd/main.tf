
provider "kubernetes" {
  config_path = var.kubeconfig
} 

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}
  
provider "aws" { 
  region = var.region
}   

data "aws_caller_identity" "current" {}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.namespace
  chart      = "${path.module}/argo-cd"
  wait       = false

  values = [
    <<-EOT
    configs:
      credentialTemplates:
        https-creds:
          url: ${var.workload_git_repo}
          password: ${var.github_pat}
          username: ${var.github_user}
    repositories:
      private-repo:
        url: ${var.workload_git_repo}
    server:
      extraArgs:
        - --insecure
EOT
  ]

  lifecycle {
    ignore_changes = [
      values,
      version
    ]
  }
  provisioner "local-exec" {
    command = "echo 'Sleeping for 20 seconds after ArgoCD installation...' && sleep 20 && echo 'Sleep completed'"
  }
}

resource "kubernetes_manifest" "argocd_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "argocd-ingressroute"
      namespace = var.namespace
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          kind  = "Rule"
          match = "Host(`argo.${var.cluster_name}.${var.hosted_zone}`)"
          services = [
            {
              name      = "argocd-server"
              kind      = "Service"
              namespace = var.namespace
              port      = 80
            }
          ]
        }
      ]
      tls = {
        certResolver = "le"
      }
    }
  }

  depends_on = [helm_release.argocd]
}

