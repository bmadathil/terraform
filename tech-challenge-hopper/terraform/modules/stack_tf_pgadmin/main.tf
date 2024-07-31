
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

resource "kubernetes_manifest" "pgadmin_credentials_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "pgadmin-credentials-external-secrets"
      namespace = "pgadmin"
    }
    spec = {
      data = [
        {
          remoteRef = {
            key      = "river-secrets"
            property = "pgadmin-username"
          }
          secretKey = "username"
        },
        {
          remoteRef = {
            key      = "river-secrets"
            property = "pgadmin-password"
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
        name = "pgadmin-credentials"
        template = {
          type = "opaque"
        }
      }
    }
  }
}


# Function to fetch and decode secret data
locals {
  namespaces = ["dev", "test", "prod"]
  fetch_secret = { for ns in local.namespaces : ns => {
    username = try(
      base64decode(data.kubernetes_secret.db_credentials[ns].data.username),
      data.kubernetes_secret.db_credentials[ns].data.username
    )
    password = try(
      base64decode(data.kubernetes_secret.db_credentials[ns].data.password),
      data.kubernetes_secret.db_credentials[ns].data.password
    )
  }}
  pgpass_content = join("\n", [
    for ns, creds in local.fetch_secret :
    "postgres-${ns}.${ns}.svc.cluster.local:5432:postgres:postgres:${creds.password}"
  ])
}

# Data source to fetch the secrets from different namespaces
data "kubernetes_secret" "db_credentials" {
  for_each = toset(local.namespaces)
  metadata {
    name      = "postgres-db-credentials"
    namespace = each.key
  }
}

# Create a local file named pgpassfile
resource "local_file" "pgpassfile" {
  filename        = "/tmp/pgpassfile"
  content         = local.pgpass_content
  file_permission = "0600"
}

# Create a Kubernetes secret named pgpassfile in each namespace
resource "kubernetes_secret" "pgpassfile" {
  metadata {
    name      = "pgpassfile"
    namespace = "pgadmin"
  }

  data = {
    pgpassfile = local.pgpass_content
  }

  type = "Opaque"
}

# Output the usernames
output "db_usernames" {
  value = {
    for ns, creds in local.fetch_secret : ns => creds.username
  }
  sensitive = true
}

# Output the path to the local pgpassfile
output "local_pgpassfile" {
  value = local_file.pgpassfile.filename
}

locals {
  servers = {
    1 = {
      Group          = "Servers"
      Host           = "postgres-dev.dev.svc.cluster.local"
      MaintenanceDB  = "postgres"
      Name           = "dev"
      PassFile       = "/var/lib/pgadmin/pgpassfile"
      Port           = 5432
      SSLMode        = "prefer"
      Username       = "postgres"
    }
    2 = {
      Group          = "Servers"
      Host           = "postgres-test.test.svc.cluster.local"
      MaintenanceDB  = "postgres"
      Name           = "test"
      PassFile       = "/var/lib/pgadmin/pgpassfile"
      Port           = 5432
      SSLMode        = "prefer"
      Username       = "postgres"
    }
    3 = {
      Group          = "Servers"
      Host           = "postgres-prod.prod.svc.cluster.local"
      MaintenanceDB  = "postgres"
      Name           = "prod"
      PassFile       = "/var/lib/pgadmin/pgpassfile"
      Port           = 5432
      SSLMode        = "prefer"
      Username       = "postgres"
    }
  }
}


resource "kubernetes_config_map" "pgadmin_servers" {
  metadata {
    name      = "pgadmin-servers-config"
    namespace = "pgadmin"
  }

  data = {
    "servers.json" = jsonencode({
      Servers = local.servers
    })
  }
}

#  Helm Chart starts here 

resource "helm_release" "pgadmin" {
  name       = "pgadmin"
  namespace  = "pgadmin"
  chart      = "${path.module}/pgadmin4"
  depends_on = [kubernetes_secret.pgpassfile]

  values = [
    jsonencode({
      replicaCount    = 1
      existingSecret  = "pgadmin-credentials"
      secretKeys      = {
        pgadminPasswordKey = "password"
      }
      env             = {
        pgpassfile = "/var/lib/pgadmin/pgpassfile"
        email      = "river-pgadmin@cvpcorp.com"
      }

      serverDefinitions = {
        enabled = true
        servers = local.servers
      }

      extraSecretMounts = [
        {
          name      = "pgpassfile"
          secret    = "pgpassfile"
          subPath   = "pgpassfile"
          mountPath = "/tmp/pgpassfile"
        },
      ]

      extraEnvVars = [
        {
          name = "PGADMIN_DEFAULT_PASSWORD"
          valueFrom = {
            secretKeyRef = {
              name = "pgadmin-credentials"
              key  = "password"  
            }
          }
        }
      ]

      VolumePermissions = { enabled = true }
      extraInitContainers = <<-EOT
        - name: setup-pgpassfile
          image: "dpage/pgadmin4:latest"
          command: ["sh", "-c", "cp /tmp/pgpassfile /var/lib/pgadmin/pgpassfile && chown 5050:5050 /var/lib/pgadmin/pgpassfile && chmod 0600 /var/lib/pgadmin/pgpassfile"]
          volumeMounts:
            - name: pgadmin-data
              mountPath: /var/lib/pgadmin
            - name: pgpassfile
              subPath: pgpassfile
              mountPath: /tmp/pgpassfile
          securityContext:
            runAsUser: 5050
        EOT
      strategy = {
        type = "Recreate"
      }
    })
  ]
}

locals {
  pgadmin_host = "pgadmin.${var.cluster_name}.sandbox.cvpcorp.io"
}

resource "kubernetes_manifest" "pgadmin_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "pgadmin-ingress"
      namespace = "pgadmin"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
           match = "Host(`pgadmin.${var.cluster_name}.${var.hosted_zone}`)"
          kind     = "Rule"
          services = [
            {
              name      = "pgadmin-pgadmin4"
              namespace = "pgadmin"
              kind      = "Service"
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

