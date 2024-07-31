
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


resource "kubernetes_manifest" "external_secret_keycloak_admin_credentials" {
  for_each = toset(["dev", "test", "prod"])

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"

    metadata = {
      name      = "keycloak-admin-credentials-external-secrets"
      namespace = each.key
    }

    spec = {
      data = [
        {
          remoteRef = {
            key      = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            property = "keycloak-admin-username"
          }
          secretKey = "username"
        },
        {
          remoteRef = {
            key      = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            property = "keycloak-admin-password"
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
        name = "keycloak-admin-credentials"
        template = {
          type = "opaque"
        }
      }
    }
  }
}

resource "kubernetes_manifest" "external_secret_keycloak_client_secrets" {
  for_each = toset(["dev", "test", "prod"])

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"

    metadata = {
      name      = "keycloak-client-secrets-external-secrets"
      namespace = each.key
    }

    spec = {
      data = [
        {
          remoteRef = {
            key      = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            property = "client-secret"
          }
          secretKey = "client-secret"
        }
      ]
      refreshInterval = "1h"
      secretStoreRef = {
        kind = "SecretStore"
        name = "external-secrets-store"
      }
      target = {
        name = "keycloak-client-secrets"
      }
    }
  }
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [kubernetes_manifest.external_secret_keycloak_client_secrets]

  create_duration = "30s"
}

# Define the data sources for the secrets
data "kubernetes_secret" "keycloak_secret_dev" {
  metadata {
    name      = "keycloak-client-secrets"
    namespace = "dev"
  }
  depends_on = [kubernetes_manifest.external_secret_keycloak_client_secrets]
}

data "kubernetes_secret" "keycloak_secret_test" {
  metadata {
    name      = "keycloak-client-secrets"
    namespace = "test"
  }
  depends_on = [kubernetes_manifest.external_secret_keycloak_client_secrets]
}

data "kubernetes_secret" "keycloak_secret_prod" {
  metadata {
    name      = "keycloak-client-secrets"
    namespace = "prod"
  }
  depends_on = [kubernetes_manifest.external_secret_keycloak_client_secrets]
}

# Create local variables to store the secrets, with error handling
locals {
  client_secret_dev  = try(data.kubernetes_secret.keycloak_secret_dev.data["client-secret"], "secret-not-found-for-dev")
  client_secret_test = try(data.kubernetes_secret.keycloak_secret_test.data["client-secret"], "secret-not-found-for-test")
  client_secret_prod = try(data.kubernetes_secret.keycloak_secret_prod.data["client-secret"], "secret-not-found-for-prod")
}

# Create Kubernetes ConfigMaps for each environment
resource "kubernetes_config_map" "keycloak_realm_configmap_dev" {
  metadata {
    name      = "keycloak-realms-configmap"
    namespace = "dev"
  }

  data = {
    "river-tech-challenge-dev.json" = jsonencode({
      realm       = "river-tech-challenge-dev"
      displayName = "Practice River Tech Challenge (Dev)"
      enabled     = true
      roles = {
        realm = [
          {
            name        = "User"
            description = "A User of the system"
            containerId = "river-tech-challenge-dev"
          }
        ]
      }
      groups = [
        {
          name = "Users"
          path = "/Users"
        }
      ]
      users = [
        {
          username      = "user1"
          enabled       = true
          email         = "user1@cvpcorp.com"
          emailVerified = true
          firstName     = "User"
          lastName      = "One"
          credentials = [
            {
              type  = "password"
              value = "tc123"
            }
          ]
          realmRoles = ["User"]
          groups     = ["/Users"]
        }
      ]
      clients = [
        {
          clientId                  = "river-tech-challenge-ui"
          name                      = "Practice River Tech Challenge UI (Dev)"
          description               = "UI client for River Tech Challenge practice team"
          rootUrl                   = "https://dev.app.river.sandbox.cvpcorp.io"
          baseUrl                   = "/"
          enabled                   = true
          alwaysDisplayInConsole    = true
          clientAuthenticatorType   = "client-secret"
          secret                    = local.client_secret_dev
          redirectUris              = ["/*"]
          webOrigins                = ["*"]
          publicClient              = true
          directAccessGrantsEnabled = true
        }
      ]
    })
  }

  depends_on = [data.kubernetes_secret.keycloak_secret_dev,time_sleep.wait_30_seconds]
}

resource "kubernetes_config_map" "keycloak_realm_configmap_test" {
  metadata {
    name      = "keycloak-realms-configmap"
    namespace = "test"
  }

  data = {
    "river-tech-challenge-test.json" = jsonencode({
      realm       = "river-tech-challenge-test"
      displayName = "Practice River Tech Challenge (Test)"
      enabled     = true
      roles = {
        realm = [
          {
            name        = "User"
            description = "A User of the system"
            containerId = "river-tech-challenge-test"
          }
        ]
      }
      groups = [
        {
          name = "Users"
          path = "/Users"
        }
      ]
      users = [
        {
          username      = "user1"
          enabled       = true
          email         = "user1@cvpcorp.com"
          emailVerified = true
          firstName     = "User"
          lastName      = "One"
          credentials = [
            {
              type  = "password"
              value = "tc123"
            }
          ]
          realmRoles = ["User"]
          groups     = ["/Users"]
        }
      ]
      clients = [
        {
          clientId                  = "river-tech-challenge-ui"
          name                      = "Practice River Tech Challenge UI (Test)"
          description               = "UI client for River Tech Challenge practice team"
          rootUrl                   = "https://test.app.river.sandbox.cvpcorp.io"
          baseUrl                   = "/"
          enabled                   = true
          alwaysDisplayInConsole    = true
          clientAuthenticatorType   = "client-secret"
          secret                    = local.client_secret_test
          redirectUris              = ["/*"]
          webOrigins                = ["*"]
          publicClient              = true
          directAccessGrantsEnabled = true
        }
      ]
    })
  }

  depends_on = [data.kubernetes_secret.keycloak_secret_test,time_sleep.wait_30_seconds]
}

resource "kubernetes_config_map" "keycloak_realm_configmap_prod" {
  metadata {
    name      = "keycloak-realms-configmap"
    namespace = "prod"
  }

  data = {
    "river-tech-challenge-prod.json" = jsonencode({
      realm       = "river-tech-challenge-prod"
      displayName = "Practice River Tech Challenge (Prod)"
      enabled     = true
      roles = {
        realm = [
          {
            name        = "User"
            description = "A User of the system"
            containerId = "river-tech-challenge-prod"
          }
        ]
      }
      groups = [
        {
          name = "Users"
          path = "/Users"
        }
      ]
      users = [
        {
          username      = "user1"
          enabled       = true
          email         = "user1@cvpcorp.com"
          emailVerified = true
          firstName     = "User"
          lastName      = "One"
          credentials = [
            {
              type  = "password"
              value = "tc123"
            }
          ]
          realmRoles = ["User"]
          groups     = ["/Users"]
        }
      ]
      clients = [
        {
          clientId                  = "river-tech-challenge-ui"
          name                      = "Practice River Tech Challenge UI (Prod)"
          description               = "UI client for River Tech Challenge practice team"
          rootUrl                   = "https://prod.app.river.sandbox.cvpcorp.io"
          baseUrl                   = "/"
          enabled                   = true
          alwaysDisplayInConsole    = true
          clientAuthenticatorType   = "client-secret"
          secret                    = local.client_secret_prod
          redirectUris              = ["/*"]
          webOrigins                = ["*"]
          publicClient              = true
          directAccessGrantsEnabled = true
        }
      ]
    })
  }

  depends_on = [data.kubernetes_secret.keycloak_secret_prod,time_sleep.wait_30_seconds]
}


locals {
  namespaces = ["dev", "test","prod"]
}

resource "kubernetes_config_map" "keycloak_configmap" {
  count = length(local.namespaces)

  metadata {
    name      = "keycloak-configmap"
    namespace = local.namespaces[count.index]
  }

  data = {
    KC_DB              = "postgres"
    KC_DB_SCHEMA       = "keycloak"
    KC_HOSTNAME_DEBUG  = "true"
    KC_HTTP_ENABLED    = "true"
    KC_METRICS_ENABLED = "true"
    KC_PROXY           = "edge"
  }
}



resource "helm_release" "keycloak" {
  for_each = toset(local.namespaces)

  name       = "keycloak"
  namespace  = each.key
  chart      = "${path.module}/keycloak"

  values = [
    yamlencode({
      replicaCount = 1
      auth = {
        adminUser         = "admin" 
        existingSecret    = "keycloak-admin-credentials"
        passwordSecretKey = "password"
      }
      extraEnvVarsCM    = "keycloak-configmap"
      extraStartupArgs  = "--import-realm"
      extraVolumes = [
        {
          name = "keycloak-realms-configmap"
          configMap = {
            name = "keycloak-realms-configmap"
          }
        }
      ]
      extraVolumeMounts = [
        {
          name      = "keycloak-realms-configmap"
          mountPath = "/opt/bitnami/keycloak/data/import"
          readOnly  = true
        }
      ]
      postgresql = {
        enabled = false
      }
      externalDatabase = {
        port                    = "5432"
        host                    = "postgres-${each.key}.${each.key}.svc.cluster.local"
        database                = "postgres"
        existingSecret          = "keycloak-db-credentials"
        existingSecretUserKey   = "username"
        existingSecretPasswordKey = "password"
      }
    })
  ]
}


resource "kubernetes_manifest" "keycloak_ingress_dev" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "keycloak-ingress"
      namespace = "dev"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          kind  = "Rule"
          match = "Host(`dev.keycloak.${var.cluster_name}.${var.hosted_zone}`)"
          services = [
            {
              kind      = "Service"
              name      = "keycloak"
              namespace = "dev"
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
}

resource "kubernetes_manifest" "keycloak_ingress_test" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "keycloak-ingress"
      namespace = "test"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          kind  = "Rule"
          match = "Host(`test.keycloak.${var.cluster_name}.${var.hosted_zone}`)"
          services = [
            {
              kind      = "Service"
              name      = "keycloak"
              namespace = "test"
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
}

resource "kubernetes_manifest" "keycloak_ingress_prod" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "keycloak-ingress"
      namespace = "prod"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          kind  = "Rule"
          match = "Host(`prod.keycloak.${var.cluster_name}.${var.hosted_zone}`)"
          services = [
            {
              kind      = "Service"
              name      = "keycloak"
              namespace = "prod"
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
}

