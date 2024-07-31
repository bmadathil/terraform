
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

resource "helm_release" "smtp4dev" {
  name      = "smtp4dev"
  namespace = "smtp4dev"
  chart     = "${path.module}/smtp4dev"

  values = [
    yamlencode({
      replicaCount = 1
      affinity = {
        nodeAffinity = {
          requiredDuringSchedulingIgnoredDuringExecution = {
            nodeSelectorTerms = [
              {
                matchExpressions = [
                  {
                    key      = "kubernetes.io/os"
                    operator = "In"
                    values   = ["linux"]
                  }
                ]
              }
            ]
          }
        }
      }
    })
  ]
}

resource "kubernetes_manifest" "smtp4dev_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "smtp4dev-ingressroute"
      namespace = "smtp4dev"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          kind  = "Rule"
          match = "Host(`smtp4dev.${var.cluster_name}.${var.hosted_zone}`)"
          services = [
            {
              name      = "smtp4dev"
              kind      = "Service"
              namespace = "smtp4dev"
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

  depends_on = [helm_release.smtp4dev]
}
                                                
