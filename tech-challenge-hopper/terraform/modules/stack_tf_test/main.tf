
provider "kubernetes" {
  config_path = "/tmp/kubeconfig"
}

provider "helm" {
  kubernetes {
    config_path = "/tmp/kubeconfig"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

#  Display Argo-CD Information 

data "kubernetes_secret" "argocd_initial_admin_secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "devops"  
  }
}

locals {
  # Try to decode the password, if it fails, use the raw value
  argocd_password = try(
    base64decode(data.kubernetes_secret.argocd_initial_admin_secret.data.password),
    data.kubernetes_secret.argocd_initial_admin_secret.data.password
  )
}

output "argocd_initial_password" {
  value       = local.argocd_password
  description = "Initial admin password for ArgoCD"
  sensitive   = true  # Set to false to allow displaying the password
}

data "kubernetes_resource" "argocd-ingressroute" {
  api_version = "traefik.io/v1alpha1"
  kind        = "IngressRoute"

  metadata {
    name      = "argocd-ingressroute"
    namespace = "devops"
  }
}

locals {
  argocd_host = try(
    data.kubernetes_resource.argocd-ingressroute.object.spec.routes[0].match,
    ""
  )
  # Extract the host from the match string (e.g., "Host(`example.com`)")
  argocdextracted_host = length(regexall("Host\\(`([^`]+)`\\)", local.argocd_host)) > 0 ? replace(local.argocd_host, "/Host\\(`([^`]+)`\\).*/", "$1") : ""
}

output "argocd_url" {
  value       = "https://${local.argocdextracted_host}"
  description = "ArgoCD URL"
}

#  Display PGadmin Information 


data "kubernetes_secret" "pgadmin-credentials" {
  metadata {
    name      = "pgadmin-credentials"
    namespace = "pgadmin"  
  }
}

locals {
  # Try to decode the password, if it fails, use the raw value
  pgadmin_username = try(
    base64decode(data.kubernetes_secret.pgadmin-credentials.data.username),
    data.kubernetes_secret.pgadmin-credentials.data.username
  )
  pgadmin_password = try(
    base64decode(data.kubernetes_secret.pgadmin-credentials.data.password),
    data.kubernetes_secret.pgadmin-credentials.data.password
  )
}

output "pgadmin_initial_login" {
  value       = local.pgadmin_username
  description = "Initial admin login for PGadmin"
  sensitive   = true  
}
output "pgadmin_initial_password" {
  value       = local.pgadmin_password
  description = "Initial admin password for PGadmin"
  sensitive   = true  
}

data "kubernetes_resource" "pgadmin-ingress" {
  api_version = "traefik.io/v1alpha1"
  kind        = "IngressRoute"

  metadata {
    name      = "pgadmin-ingress"
    namespace = "pgadmin"
  }
}

locals {
  pgadmin_host = try(
    data.kubernetes_resource.pgadmin-ingress.object.spec.routes[0].match,
    ""
  )
  # Extract the host from the match string (e.g., "Host(`example.com`)")
  pgadminextracted_host = length(regexall("Host\\(`([^`]+)`\\)", local.pgadmin_host)) > 0 ? replace(local.pgadmin_host, "/Host\\(`([^`]+)`\\).*/", "$1") : ""
}

output "pgadmin_url" {
  value       = "https://${local.pgadminextracted_host}"
  description = "PGadmin URL"
}

#  Display keycloak Information 

# Display Keycloak Information for dev, test, and prod namespaces

locals {
  namespaces = ["dev", "test", "prod"]
}

data "kubernetes_secret" "keycloak-admin-credentials" {
  for_each = toset(local.namespaces)
  metadata {
    name      = "keycloak-admin-credentials"
    namespace = each.key
  }
}

data "kubernetes_resource" "keycloak-ingress" {
  for_each     = toset(local.namespaces)
  api_version  = "traefik.io/v1alpha1"
  kind         = "IngressRoute"

  metadata {
    name      = "keycloak-ingress"
    namespace = each.key
  }
}

locals {
  keycloak_info = {
    for ns in local.namespaces : ns => {
      username = try(
        base64decode(data.kubernetes_secret.keycloak-admin-credentials[ns].data.username),
        data.kubernetes_secret.keycloak-admin-credentials[ns].data.username
      )
      password = try(
        base64decode(data.kubernetes_secret.keycloak-admin-credentials[ns].data.password),
        data.kubernetes_secret.keycloak-admin-credentials[ns].data.password
      )
      host = try(
        replace(
          data.kubernetes_resource.keycloak-ingress[ns].object.spec.routes[0].match,
          "/Host\\(`([^`]+)`\\).*/",
          "$1"
        ),
        ""
      )
    }
  }
}

# Outputs for dev namespace
output "keycloak_dev_username" {
  value       = local.keycloak_info.dev.username
  description = "Keycloak admin username for dev namespace"
  sensitive   = true
}

output "keycloak_dev_password" {
  value       = local.keycloak_info.dev.password
  description = "Keycloak admin password for dev namespace"
  sensitive   = true
}

output "keycloak_dev_url" {
  value       = "https://${local.keycloak_info.dev.host}"
  description = "Keycloak URL for dev namespace"
}

# Outputs for test namespace
output "keycloak_test_username" {
  value       = local.keycloak_info.test.username
  description = "Keycloak admin username for test namespace"
  sensitive   = true
}

output "keycloak_test_password" {
  value       = local.keycloak_info.test.password
  description = "Keycloak admin password for test namespace"
  sensitive   = true
}

output "keycloak_test_url" {
  value       = "https://${local.keycloak_info.test.host}"
  description = "Keycloak URL for test namespace"
}

# Outputs for prod namespace
output "keycloak_prod_username" {
  value       = local.keycloak_info.prod.username
  description = "Keycloak admin username for prod namespace"
  sensitive   = true
}

output "keycloak_prod_password" {
  value       = local.keycloak_info.prod.password
  description = "Keycloak admin password for prod namespace"
  sensitive   = true
}

output "keycloak_prod_url" {
  value       = "https://${local.keycloak_info.prod.host}"
  description = "Keycloak URL for prod namespace"
}

