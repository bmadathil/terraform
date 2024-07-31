terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {}

provider "kubernetes" {
  config_path = var.kubeconfig
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

variable "CLUSTER_NAME" {}
variable "public_hosted_zone_name" {}
variable "public_hosted_zone_id" {}
variable "private_hosted_zone_name" {}
variable "private_hosted_zone_id" {}
variable "cluster_oidc_provider_url" {}
variable "kubeconfig" {}

locals {
  ext_dns_name = "external-dns"
  cluster_oidc_provider_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.cluster_oidc_provider_url}"
}

resource "aws_iam_policy" "external_dns" {
  name        = local.ext_dns_name
  path        = "/${var.CLUSTER_NAME}-policies/"
  description = "ExternalDNS policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["route53:ChangeResourceRecordSets"]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.public_hosted_zone_id}",
          "arn:aws:route53:::hostedzone/${var.private_hosted_zone_id}"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones", "route53:ListResourceRecordSets"]
        Resource = ["*"]
      }
    ]
  })
}

data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${var.cluster_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${local.ext_dns_name}:${local.ext_dns_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.cluster_oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [local.cluster_oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.CLUSTER_NAME}-${local.ext_dns_name}-role"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  policy_arn = aws_iam_policy.external_dns.arn
  role       = aws_iam_role.external_dns.name
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = local.ext_dns_name
  }
}

resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = local.ext_dns_name
    namespace = kubernetes_namespace.external_dns.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
    }
  }
}

resource "helm_release" "external_dns_public" {
  name       = "${local.ext_dns_name}-public"
  namespace  = kubernetes_namespace.external_dns.metadata[0].name
  chart      = "./external-dns"
  
  values = [
    yamlencode({
      aws = {
        zoneType = "public"
      }
      domainFilters = [var.public_hosted_zone_name]
      policy        = "sync"
      provider      = "aws"
      serviceAccount = {
        create = false
        name   = local.ext_dns_name
      }
      txtOwnerId = var.public_hosted_zone_id
    })
  ]

  depends_on = [kubernetes_service_account.external_dns]
}

resource "helm_release" "external_dns_private" {
  name       = "${local.ext_dns_name}-private"
  namespace  = kubernetes_namespace.external_dns.metadata[0].name
  chart      = "./external-dns"
  
  values = [
    yamlencode({
      aws = {
        zoneType = "private"
      }
      domainFilters = [var.private_hosted_zone_name]
      policy        = "sync"
      provider      = "aws"
      serviceAccount = {
        create = false
        name   = local.ext_dns_name
      }
      txtOwnerId = var.private_hosted_zone_id
    })
  ]

  depends_on = [kubernetes_service_account.external_dns]
}
