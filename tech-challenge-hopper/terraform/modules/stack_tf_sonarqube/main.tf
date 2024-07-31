
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

resource "kubernetes_manifest" "sonarqube_admin_credentials_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "sonarqube-admin-credentials-external-secrets"
      namespace = "devops"
    }
    spec = {
      data = [
        {
          remoteRef = {
            key      = "river-secrets"
            property = "sonarqube-username"
          }
          secretKey = "sonarqube-username"
        },
        {
          remoteRef = {
            key      = "river-secrets"
            property = "sonarqube-password"
          }
          secretKey = "sonarqube-password"
        }
      ]
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "SecretStore"
        name = "external-secrets-store"
      }
      target = {
        name = "sonarqube-admin-credentials"
      }
    }
  }
}

resource "kubernetes_manifest" "sonarqube_jenkins_credentials_external_secrets" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "sonarqube-jenkins-credentials-external-secrets"
      namespace = "devops"
    }
    spec = {
      data = [
        {
          remoteRef = {
            key      = "river-secrets"
            property = "sonarqube-jenkins-username"
          }
          secretKey = "username"
        },
        {
          remoteRef = {
            key      = "river-secrets"
            property = "sonarqube-jenkins-password"
          }
          secretKey = "password"
        }
      ]
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "SecretStore"
        name = "external-secrets-store"
      }
      target = {
        name = "sonarqube-jenkins-credentials"
      }
    }
  }
}

data "kubernetes_secret" "sonarqube_admin_credentials" {
  metadata {
    name      = "sonarqube-admin-credentials"
    namespace = "devops"
  }

  depends_on = [kubernetes_manifest.sonarqube_admin_credentials_external_secret]
}

locals {
  sonarqube_admin_username = data.kubernetes_secret.sonarqube_admin_credentials.data["sonarqube-username"]
  sonarqube_admin_password = data.kubernetes_secret.sonarqube_admin_credentials.data["sonarqube-password"]
}


data "kubernetes_secret" "sonarqube_jenkins_credentials" {
  metadata {
    name      = "sonarqube-jenkins-credentials"
    namespace = "devops"
  }

  depends_on = [kubernetes_manifest.sonarqube_jenkins_credentials_external_secrets]
}

locals {
  sonarqube_jenkins_username = data.kubernetes_secret.sonarqube_jenkins_credentials.data["username"]
  sonarqube_jenkins_password = data.kubernetes_secret.sonarqube_jenkins_credentials.data["password"]
}

resource "helm_release" "sonarqube" {
  name       = "sonarqube"
  namespace  = "devops"
  chart      = "${path.module}/sonarqube"

  values = [
    jsonencode({
      replicaCount     = 1
      sonarqubeUsername = local.sonarqube_admin_username
      sonarqubePassword = local.sonarqube_admin_password
      existingSecret   = "sonarqube-admin-credentials"
      persistence      = {
        enabled = true
      }
      service          = {
        type  = "ClusterIP"
        ports = {
          http = 9000
        }
      }
      postgresql = {
        enabled = false
      }
      externalDatabase = {
        port                    = "5432"
        host                    = "postgres-prod.prod.svc.cluster.local"
        database                = "postgres"
        existingSecret          = "postgres-db-credentials"
        existingSecretUserKey   = "username"
        existingSecretPasswordKey = "password"
      }
    })
  ]

  provisioner "local-exec" {
    command = "echo 'Sleeping for 30 seconds after Sonarqube installation...' && sleep 30 && echo 'Sleep completed'"
  }

  depends_on = [data.kubernetes_secret.sonarqube_admin_credentials,data.kubernetes_secret.sonarqube_jenkins_credentials] 
}

resource "kubernetes_manifest" "sonarqube_ingress_route" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "sonarqube-ingress"
      namespace = "devops"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          kind  = "Rule"
          match = "Host(`sonarqube.${var.cluster_name}.${var.hosted_zone}`)"
          services = [
            {
              kind      = "Service"
              name      = "sonarqube"
              namespace = "devops"
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
  depends_on = [
    helm_release.sonarqube,
  ]
}
