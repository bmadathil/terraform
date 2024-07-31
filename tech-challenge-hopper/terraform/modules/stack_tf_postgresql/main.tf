/*terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
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
  namespaces = ["dev","test","prod"]
}

resource "kubernetes_config_map" "postgres_configmap" {
  for_each = toset(local.namespaces)
  metadata {
    name      = "postgres-configmap"
    namespace = each.key
  }

  data = {
    PGDATABASE    = "postgres"
    PGHOST        = "postgres"
    PGPORT        = "5432"
    POSTGRES_DB   = "postgres"
    POSTGRES_HOST = "postgres"
    POSTGRES_PORT = "5432"
  }
}
resource "kubernetes_manifest" "postgres_db_credentials_external_secret" {
  for_each = toset(local.namespaces)

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "postgres-db-credentials-external-secrets"
      namespace = each.key
    }
    spec = {
      data = [
        {
          remoteRef = {
            conversionStrategy = "Default"
            decodingStrategy   = "None"
            key                = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            //key = contains(["prod", "devops"], each.key) ? "river-secrets" : "river-${each.key}-secrets"
            metadataPolicy     = "None"
            property           = "postgres-db-username"
          }
          secretKey = "username"
        },
        {
          remoteRef = {
            conversionStrategy = "Default"
            decodingStrategy   = "None"
            key                = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            metadataPolicy     = "None"
            property           = "postgres-db-password"
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
        creationPolicy = "Owner"
        deletionPolicy = "Retain"
        name           = "postgres-db-credentials"
        template = {
          engineVersion = "v2"
          mergePolicy   = "Replace"
          metadata = {
            annotations = {}
            labels      = {}
          }
          type = "opaque"
        }
      }
    }
  }

}

resource "kubernetes_manifest" "app_db_credentials_external_secret" {
  for_each = toset(local.namespaces)

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "app-db-credentials-external-secrets"
      namespace = each.key
    }
    spec = {
      data = [
        {
          remoteRef = {
            conversionStrategy = "Default"
            decodingStrategy   = "None"
            key                = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            metadataPolicy     = "None"
            property           = "app-db-username"
          }
          secretKey = "username"
        },
        {
          remoteRef = {
            conversionStrategy = "Default"
            decodingStrategy   = "None"
            key                = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            metadataPolicy     = "None"
            property           = "app-db-password"
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
        creationPolicy = "Owner"
        deletionPolicy = "Retain"
        name           = "app-db-credentials"
        template = {
          engineVersion = "v2"
          mergePolicy   = "Replace"
          metadata = {
            annotations = {}
            labels      = {}
          }
          type = "opaque"
        }
      }
    }
  }

}


resource "kubernetes_manifest" "keycloak_db_credentials_external_secret" {
  for_each = toset(local.namespaces)

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "keycloak-db-credentials-external-secrets"
      namespace = each.key
    }
    spec = {
      data = [
        {
          remoteRef = {
            conversionStrategy = "Default"
            decodingStrategy   = "None"
            key                = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            metadataPolicy     = "None"
            property           = "keycloak-db-username"
          }
          secretKey = "username"
        },
        {
          remoteRef = {
            conversionStrategy = "Default"
            decodingStrategy   = "None"
            key                = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            metadataPolicy     = "None"
            property           = "keycloak-db-password"
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
        creationPolicy = "Owner"
        deletionPolicy = "Retain"
        name           = "keycloak-db-credentials"
        template = {
          engineVersion = "v2"
          mergePolicy   = "Replace"
          metadata = {
            annotations = {}
            labels      = {}
          }
          type = "opaque"
        }
      }
    }
  }

}

resource "kubernetes_manifest" "nextauth_db_credentials_external_secret" {
  for_each = toset(local.namespaces)

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "nextauth-db-credentials-external-secrets"
      namespace = each.key
    }
    spec = {
      data = [
        {
          remoteRef = {
            conversionStrategy = "Default"
            decodingStrategy   = "None"
            key                = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            metadataPolicy     = "None"
            property           = "nextauth-db-username"
          }
          secretKey = "username"
        },
        {
          remoteRef = {
            conversionStrategy = "Default"
            decodingStrategy   = "None"
            key                = each.key == "prod" ? "river-secrets" : "river-${each.key}-secrets"
            metadataPolicy     = "None"
            property           = "nextauth-db-password"
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
        creationPolicy = "Owner"
        deletionPolicy = "Retain"
        name           = "nextauth-db-credentials"
        template = {
          engineVersion = "v2"
          mergePolicy   = "Replace"
          metadata = {
            annotations = {}
            labels      = {}
          }
          type = "opaque"
        }
      }
    }
  }

}

locals {
  scripts_directory = "${path.module}/scripts-initdb"
  script_files      = fileset(local.scripts_directory, "*")
  file_configs = {
    for filename in local.script_files :
    filename => file("${local.scripts_directory}/${filename}")
  }
}

resource "kubernetes_config_map" "postgres_initdb_configmap" {
  for_each = toset(local.namespaces)
  metadata {
    name      = "postgres-initdb-configmap"
    namespace = each.key
  }
  data = local.file_configs

}


# Read the JSON file
locals {
  workloads = jsondecode(file("${path.module}/workloads.json")).namespaces
}


resource "helm_release" "postgres" {
  for_each = {
    for ns in local.workloads : ns.name => ns
  }

  name       = "postgres-${each.key}"
  namespace  = each.key
  chart      = "${path.module}/postgresql"
  values = [
    jsonencode({
      nameOverride = "postgres",
      auth = {
        username       = each.value.workloads[0].name,
        existingSecret = each.value.workloads[0].adminCredentials.name,
        secretKeys = {
          userPasswordKey  = each.value.workloads[0].adminCredentials.data[1].secretKey,
          adminPasswordKey = each.value.workloads[0].adminCredentials.data[1].secretKey
        }
      },
      primary = {
        extraEnvVars = [
          { name = "PGUSER", valueFrom = { secretKeyRef = { name = "postgres-db-credentials", key = "username" }}},
          { name = "PGPASSWORD", valueFrom = { secretKeyRef = { name = "postgres-db-credentials", key = "password" }}},
          { name = "PGDATABASE", value = "postgres" },
          { name = "APP_DB_USER", valueFrom = { secretKeyRef = { name = "app-db-credentials", key = "username" }}},
          { name = "APP_DB_PASSWORD", valueFrom = { secretKeyRef = { name = "app-db-credentials", key = "password" }}},
          { name = "KEYCLOAK_DB_USER", valueFrom = { secretKeyRef = { name = "keycloak-db-credentials", key = "username" }}},
          { name = "KEYCLOAK_DB_PASSWORD", valueFrom = { secretKeyRef = { name = "keycloak-db-credentials", key = "password" }}},
          { name = "NEXTAUTH_DB_USER", valueFrom = { secretKeyRef = { name = "nextauth-db-credentials", key = "username" }}},
          { name = "NEXTAUTH_DB_PASSWORD", valueFrom = { secretKeyRef = { name = "nextauth-db-credentials", key = "password" }}}
        ],
        initdb = {
          scriptsConfigMap = "postgres-initdb-configmap"
        }
      }
    })
  ]
}


resource "kubernetes_manifest" "postgres_db_credentials_external_secret_devops" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "postgres-db-credentials-external-secrets"
      namespace = "devops"
    }
    spec = {
      data = [
        {
          remoteRef = {
            key      = "river-secrets"
            property = "postgres-db-username"
          }
          secretKey = "username"
        },
        {
          remoteRef = {
            key      = "river-secrets"
            property = "postgres-db-password"
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
        name = "postgres-db-credentials"
      }
    }
  }
}


output "postgres_values" {
  value = [
    for ns in local.workloads : {
      namespace  = ns.name
      workload   = ns.workloads[0].name
      username   = ns.workloads[0].adminCredentials.data[1].remoteRef.property
      existing_secret = ns.workloads[0].adminCredentials.name
      user_password_key = ns.workloads[0].adminCredentials.data[1].secretKey
      admin_password_key = ns.workloads[0].adminCredentials.data[1].secretKey
    }
  ]
}

output "namespace_workloads" {
  value = {
    for ns in local.workloads : ns.name => ns.workloads
  }
}



