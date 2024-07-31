
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
  applications = {
    frontend = ["dev", "test", "prod"],
    backend  = ["dev", "test", "prod"]
  }
}

resource "kubernetes_manifest" "argocd_applications" {
  for_each = {
    for pair in flatten([
      for app, envs in local.applications : [
        for env in envs : {
          key = "${app}-${env}"
          value = {
            app = app
            env = env
          }
        }
      ]
    ]) : pair.key => pair.value
  }

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = each.key
      namespace = "devops"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/cvp-challenges/practice-river-devops.git"
        targetRevision = "HEAD"
        path           = "${each.value.app}/envs/${each.value.env}"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace =  "${each.value.env}"
      }
      syncPolicy = {
        automated = {
          selfHeal = true
          prune    = true
        }
      }
    }
  }

}

resource "kubernetes_manifest" "google_api_key_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "google-api-key-external-secrets"
      namespace = "devops"
    }
    spec = {
      data = [
        {
          remoteRef = {
            key      = "river-secrets"
            property = "google-api-key"
          }
          secretKey = "text"
        }
      ]
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "SecretStore"
        name = "external-secrets-store"
      }
      target = {
        name = "google-api-key"
      }
    }
  }
}

resource "kubernetes_manifest" "google_tag_mgr_key_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "google-tag-mgr-key-external-secrets"
      namespace = "devops"
    }
    spec = {
      data = [
        {
          remoteRef = {
            key      = "river-secrets"
            property = "google-tag-mgr-key"
          }
          secretKey = "text"
        }
      ]
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "SecretStore"
        name = "external-secrets-store"
      }
      target = {
        name = "google-tag-mgr-key"
      }
    }
  }
}

