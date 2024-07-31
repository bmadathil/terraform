/*terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}*/

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

resource "kubernetes_service" "traefik_service" {
  metadata {
    name      = "traefik-service"
    namespace = "traefik"
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "traefik"
    }

    port {
      port        = 9100
      target_port = 9100
      protocol    = "TCP"
      name        = "metrics"
    }

    port {
      port        = 9000
      target_port = 9000
      protocol    = "TCP"
      name        = "traefik"
    }

    port {
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
      name        = "web"
    }

    port {
      port        = 8443
      target_port = 8443
      protocol    = "TCP"
      name        = "websecure"
    }
  }
}

resource "kubernetes_secret" "basic_auth_creds" {
  metadata {
    name      = "basic-auth-creds"
    namespace = "traefik"
  }
  
  type = "kubernetes.io/basic-auth"

  data = {
    username = base64encode("admin")
    password = base64encode("admin")
  }
}

resource "kubernetes_manifest" "traefik_middleware" {
  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "basic-auth"
      namespace = "traefik"
    }
    spec = {
      basicAuth = {
        secret = "basic-auth-creds"
      }
    }
  }
}

resource "kubernetes_manifest" "traefik_ingress" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "traefitraefik-ingress"
      namespace = "traefik"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          kind  = "Rule"
           match = "Host(`traefik.${var.cluster_name}.${var.hosted_zone}`)"
          /*middlewares = [
            {
              name = kubernetes_manifest.traefik_middleware.manifest.metadata.name
              namespace = "traefik"
            }
          ]*/

          services = [
            {
              kind      = "Service"
              name      = "traefik-service"
              namespace = "traefik"
              port      = 9000
            }
          ]
        }
      ]
      tls = {
        certResolver = "le"
      }
    }
  }
}


data "kubernetes_service" "traefik" {
  metadata {
    name      = local.TRAEFIK
    namespace = local.TRAEFIK
  }

}

data "aws_route53_zone" "selected" {
  name = "sandbox.cvpcorp.io"
}

resource "aws_route53_record" "traefik" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "*.${var.cluster_name}.sandbox.cvpcorp.io"  # replace with the desired subdomain name
  type    = "CNAME"     
  ttl     = 300
  records = [data.kubernetes_service.traefik.status.0.load_balancer.0.ingress.0.hostname]
}

output "traefikdns" {
  value = data.kubernetes_service.traefik.status.0.load_balancer.0.ingress.0.hostname
}             



