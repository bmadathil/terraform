
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

data "aws_eks_cluster" "custer_name_oidc" {
  name = var.cluster_name
}

locals {
  oidc_provider_url = replace(data.aws_eks_cluster.custer_name_oidc.identity[0].oidc[0].issuer, "https://", "")
}


locals {
  cluster_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider_url}"
}


resource "aws_iam_policy" "jenkins_policy" {
  name        = "jenkins-policy"
  path        = "/${var.cluster_name}-policies/"
  description = "Jenkins policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = [
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/*"
        ]
      }
    ]
  })
}


data "aws_iam_policy_document" "jenkins_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:jenkins:${var.namespace}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      type        = "Federated"
      identifiers = [local.cluster_oidc_provider_arn]
    }
  }
}

resource "aws_iam_role" "jenkins_role" {
  name               = "${var.cluster_name}-jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.jenkins_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "jenkins_role_policy_attachment" {
  policy_arn = aws_iam_policy.jenkins_policy.arn
  role       = aws_iam_role.jenkins_role.name
}

resource "kubernetes_service_account" "jenkins_service_account" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_role.arn
    }
  }

  depends_on = [aws_iam_role.jenkins_role]
}

resource "kubernetes_role" "jenkins_sa_role" {
  metadata {
    name      = "jenkins-sa-role"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "watch", "list"]
  }
}


resource "kubernetes_role_binding" "jenkins_sa_role_binding" {
  metadata {
    name      = "jenkins-sa-role-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_sa_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = var.namespace
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = var.namespace
  }

  depends_on = [kubernetes_role.jenkins_sa_role]
}

resource "kubernetes_secret" "github_credentials" {
  metadata {
    name      = "github-credentials"
    namespace = var.namespace
    annotations = {
      "jenkins.io/credentials-description" = "GitHub username/PAT with repo and registry access"
    }
    labels = {
      "jenkins.io/credentials-type" = "usernamePassword"
    }
  }

  type = "Opaque"

  data = {
    username = var.github_user
    password = var.github_pat
  }
}

resource "kubernetes_secret" "github_token" {
  metadata {
    name      = "github-token"
    namespace = var.namespace
    annotations = {
      "jenkins.io/credentials-description" = "GitHub PAT (from user: ${var.github_user}) with admin:repo_hook, repo, and repo:status permissions"
    }
    labels = {
      "jenkins.io/credentials-type" = "secretText"
    }
  }

  type = "Opaque"

  data = {
    text = var.github_pat
  }
}

resource "kubernetes_secret" "kubeconfig" {
  metadata {
    name      = "kubeconfig"
    namespace = var.namespace
    annotations = {
      "jenkins.io/credentials-description" = "Cluster kubeconfig"
    }
    labels = {
      "jenkins.io/credentials-type" = "secretText"
    }
  }

  type = "Opaque"

  data = {
    text = var.kubeconfig
  }
}

resource "kubernetes_manifest" "jenkins_admin_credentials_external_secret" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "jenkins-admin-credentials-external-secrets"
      namespace = "devops"
    }
    spec = {
      data = [
        {
          remoteRef = {
            key      = "river-secrets"
            property = "jenkins-username"
          }
          secretKey = "username"
        },
        {
          remoteRef = {
            key      = "river-secrets"
            property = "jenkins-password"
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
        name = "jenkins-admin-credentials"
      }
    }
  }
}

data "kubernetes_secret" "jenkins_admin_credentials" {
  metadata {
    name      = "jenkins-admin-credentials"
    namespace = var.namespace
  }

  depends_on = [kubernetes_manifest.jenkins_admin_credentials_external_secret]
}

locals {
  jenkins_admin_username = data.kubernetes_secret.jenkins_admin_credentials.data["username"]
  jenkins_admin_password = data.kubernetes_secret.jenkins_admin_credentials.data["password"]
}

resource "helm_release" "jenkins" {
  name       = "jenkins-release"
  namespace  = var.namespace
  chart      = "${path.module}/jenkins"
  
  values = [
    <<-EOT
    serviceAccount:
      name: jenkins
      create: false
    controller:
      image: ghcr.io/cvpcorp/jenkins
      tag: "2.461-alpine-jdk17"
      tagLabel: "jdk17"
      imagePullSecretName: ghcr-pull-secret
      installPlugins: false
      admin:
        existingSecret: "jenkins-admin-credentials"
        userKey: username
        passwordKey: password
      persistence:
        size: 50Gi
      JCasC:
        security:
          globalJobDslSecurityConfiguration:
            useScriptSecurity: false
        configScripts:
          welcome-message: |
            jenkins:
              systemMessage: Jenkins CI/CD application pipeline management.
          github: |
            unclassified:
              gitHubPluginConfig:
                configs:
                - credentialsId: "github-token"
                  name: "GitHub"
                hookUrl: "http://localhost:8080/github-webhook/"
          sonarqube: |
            unclassified:
              sonarGlobalConfiguration:
                buildWrapperEnabled: true
                installations:
                - credentialsId: "sonarqube-jenkins-token"
                  name: "sonarqube"
                  serverUrl: "http://sonarqube.${var.namespace}.svc.cluster.local:9000"
                  triggers:
                    envVar: "SKIP_SQ"
                    skipScmCause: false
                    skipUpstreamCause: false
          sonarscanner: |
            tool:
              sonarRunnerInstallation:
                installations:
                - name: "sonarscanner"
                  properties:
                  - installSource:
                      installers:
                      - sonarRunnerInstaller:
                          id: "6.0.0.4432"
          nodejs: |
            tool:
              nodejs:
                installations:
                - name: "nodejs"
                  properties:
                  - installSource:
                      installers:
                      - nodejsInstaller:
                          id: "20.10.0"
          build-monitor: |
            jenkins:
              primaryView:
                buildMonitor:
                  name: "bm-all"
              views:
              - buildMonitor:
                  config:
                    colourBlindMode: true
                    displayBadges: "Always"
                    displayBadgesFrom: "getLastBuild"
                    maxColumns: 4
                    order: "byName"
                    textScale: "0.5"
                  includeRegex: "(?!seeder).*"
                  name: "bm-all"
                  recurse: true
                  title: "${var.workload_title}"
            unclassified:
              buildMonitorView:
                permissionToCollectAnonymousUsageStatistics: true
          seeder: |
            jobs:
              - script: >
                  job('seeder') {
                    authenticationToken('h4r-jenkins-seed')
                    scm {
                      git {
                        remote {
                          branch('main')
                          url('${var.seed_job_repo_url}')
                          credentials('github-credentials')
                        }
                      }
                    }
                    steps {
                      jobDsl {
                        targets '${var.seed_folder}/**/*.groovy'
                        //targets '${path.module}/${var.seed_folder}/**/*.groovy'
                      }
                    }
                  }
    EOT
  ]
  
  depends_on = [
    kubernetes_service_account.jenkins_service_account,
    kubernetes_manifest.jenkins_admin_credentials_external_secret
  ]
}

resource "kubernetes_manifest" "jenkins_ingress_route" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "jenkins"
      namespace = "devops"
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          kind  = "Rule"
          match = "Host(`jenkins.${var.cluster_name}.${var.hosted_zone}`)"
          services = [
            {
              kind      = "Service"
              name      = "jenkins-release"
              namespace = "devops"
              port      = 8080
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

locals {
  namespaces = ["dev", "test", "prod"]
  jenkins_namespace = "devops"  
}

resource "kubernetes_role" "jenkins_role" {
  for_each = toset(local.namespaces)

  metadata {
    name      = "jenkins-role"
    namespace = each.key
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "jenkins_role_binding" {
  for_each = toset(local.namespaces)

  metadata {
    name      = "jenkins-role-binding"
    namespace = each.key
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins_role[each.key].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = local.jenkins_namespace
  }

  depends_on = [kubernetes_role.jenkins_role]
}

