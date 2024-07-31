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
  
locals {
  TRAEFIK = "traefik"
  traefik_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eks-traefik-controller"
} 

resource "helm_release" "traefik" {
  name       = local.TRAEFIK
  namespace  = local.TRAEFIK
  chart      = "${path.module}/traefik"

  values = [
    yamlencode({
      image = {
        tag = "v3.0.0-beta5"
      }
      certResolvers = {
        le = {
          email        = "traefik@cvpcorp.com"
          tlsChallenge = true
          storage      = "/data/acme.json"
        }
      }
      deployment = {
        initContainers = [
          {
            name  = "volume-permissions"
            image = "busybox:latest"
            command = [
              "sh",
              "-c",
              "touch /data/acme.json && chmod -Rv 600 /data/* && chown 65532:65532 /data/acme.json"
            ]
            securityContext = {
              runAsNonRoot = false
              runAsGroup   = 0
              runAsUser    = 0
            }
            volumeMounts = [
              {
                name      = "data"
                mountPath = "/data"
              }
            ]
          }
        ]
      }
      persistence = {
        enabled    = true
        name       = "data"
        accessMode = "ReadWriteOnce"
        size       = "128Mi"
        path       = "/data"
      }
      serviceAccountAnnotations = {
        "eks.amazonaws.com/role-arn" = local.traefik_role_arn
      }
      service = {
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
          "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
        }
      }
      additionalArguments = [
        "--certificatesresolvers.le.acme.caserver=${var.certificate_server}"
      ]
    })
  ]
}
