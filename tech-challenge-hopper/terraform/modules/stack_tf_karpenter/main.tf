
provider "aws" {
  region = "us-east-1"
}

provider "kubernetes" {
  config_path = "/tmp/kubeconfig"
}


data "aws_caller_identity" "current" {}


data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "tls_certificate" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

data "aws_ssm_parameter" "arm_ami_id" {
  name = "/aws/service/eks/optimized-ami/${var.k8s_version}/amazon-linux-2-arm64/recommended/image_id"
}

data "aws_ssm_parameter" "amd_ami_id" {
  name = "/aws/service/eks/optimized-ami/${var.k8s_version}/amazon-linux-2/recommended/image_id"
}

data "aws_ssm_parameter" "gpu_ami_id" {
  name = "/aws/service/eks/optimized-ami/${var.k8s_version}/amazon-linux-2-gpu/recommended/image_id"
}

output "aws_partition" {
  value = data.aws_partition.current.partition
}

output "aws_region" {
  value = data.aws_region.current.name
}

output "oidc_endpoint" {
  value = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "arm_ami_id" {
  value = data.aws_ssm_parameter.arm_ami_id.value
  sensitive = true
}

output "amd_ami_id" {
  value = data.aws_ssm_parameter.amd_ami_id.value
  sensitive = true
}

output "gpu_ami_id" {
  value = data.aws_ssm_parameter.gpu_ami_id.value
  sensitive = true
}

output "karpenter_namespace" {
  value = var.karpenter_namespace
}


resource "aws_iam_role" "karpenter_controller_role" {
  name               = "KarpenterControllerRole-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com",
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.karpenter_namespace}:karpenter"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "karpenter_controller_policy" {
  name   = "KarpenterControllerPolicy-${var.cluster_name}"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = [
          "ssm:GetParameter",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ]
        Effect   = "Allow"
        Resource = "*"
        Sid      = "Karpenter"
      },
      {
        Action    = "ec2:TerminateInstances"
        Effect    = "Allow"
        Resource  = "*"
        Sid       = "ConditionalEC2Termination"
        Condition = {
          StringLike = {
            "ec2:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterNodeRole-${var.cluster_name}"
        Sid      = "PassNodeIAMRole"
      },
      {
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = "arn:${data.aws_partition.current.partition}:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
        Sid      = "EKSClusterEndpointLookup"
      },
      {
        Sid      = "AllowScopedInstanceProfileCreationActions"
        Effect   = "Allow"
        Resource = "*"
        Action   = [
          "iam:CreateInstanceProfile"
        ]
        Condition = {
          StringEquals = {
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:RequestTag/topology.kubernetes.io/region"             = "${data.aws_region.current.name}"
          }
          StringLike = {
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid      = "AllowScopedInstanceProfileTagActions"
        Effect   = "Allow"
        Resource = "*"
        Action   = [
          "iam:TagInstanceProfile"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"             = "${data.aws_region.current.name}"
            "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}"  = "owned"
            "aws:RequestTag/topology.kubernetes.io/region"              = "${data.aws_region.current.name}"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
            "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"  = "*"
          }
        }
      },
      {
        Sid      = "AllowScopedInstanceProfileActions"
        Effect   = "Allow"
        Resource = "*"
        Action   = [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"             = "${data.aws_region.current.name}"
          }
          StringLike = {
            "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass" = "*"
          }
        }
      },
      {
        Sid     = "AllowInstanceProfileReadActions"
        Effect  = "Allow"
        Resource = "*"
        Action  = "iam:GetInstanceProfile"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "controller_policy_attachment" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_policy.arn
}


data "aws_eks_node_groups" "eks_karp_node_groups" {
  cluster_name = var.cluster_name
}

output "node_group_names" {
  value =  data.aws_eks_node_groups.eks_karp_node_groups.names
}
data "aws_eks_node_group" "eks_karp_node_group" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.cluster_name}-ng"
}

output "subnet_ids" {
  value = data.aws_eks_node_group.eks_karp_node_group.subnet_ids
}

resource "aws_ec2_tag" "eks_karp_subnet_tags" {
  for_each = data.aws_eks_node_group.eks_karp_node_group.subnet_ids

  resource_id   = each.key  
  key           = "karpenter.sh/discovery"
  value         = var.cluster_name  
}


data "aws_eks_cluster" "ngeks_cluster" {
  name = var.cluster_name
}

output "cluster_security_group_id" {
  value = data.aws_eks_cluster.ngeks_cluster.vpc_config[0].cluster_security_group_id
}

resource "aws_ec2_tag" "eks_karp_sg_tags" {
  resource_id   = data.aws_eks_cluster.ngeks_cluster.vpc_config[0].cluster_security_group_id
  key           = "karpenter.sh/discovery"
  value         = var.cluster_name  
}

# ------  KARPENTER STARTS -------


resource "kubernetes_manifest" "karpenter_poddisruptionbudget" {
  manifest = {
    apiVersion = "policy/v1"
    kind       = "PodDisruptionBudget"
    metadata = {
      name      = "karpenter"
      namespace = "kube-system"
      labels = {
        "helm.sh/chart"            = "karpenter-0.36.2"
        "app.kubernetes.io/name"   = "karpenter"
        "app.kubernetes.io/instance" = "karpenter"
        "app.kubernetes.io/version" = "0.36.2"
        "app.kubernetes.io/managed-by" = "Helm"
      }
    }
    spec = {
      maxUnavailable = 1
      selector = {
        matchLabels = {
          "app.kubernetes.io/name"   = "karpenter"
          "app.kubernetes.io/instance" = "karpenter"
        }
      }
    }
  }
}

resource "kubernetes_manifest" "karpenter_serviceaccount" {
  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "karpenter"
      namespace = "kube-system"
      labels = {
        "helm.sh/chart"           = "karpenter-0.36.2"
        "app.kubernetes.io/name"  = "karpenter"
        "app.kubernetes.io/instance" = "karpenter"
        "app.kubernetes.io/version" = "0.36.2"
        "app.kubernetes.io/managed-by" = "Helm"
      }
      annotations = {
        "eks.amazonaws.com/role-arn" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterControllerRole-${var.cluster_name}"
      }
    }
  }
}

resource "kubernetes_manifest" "karpenter_clusterrole_admin" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = "karpenter-admin"
      labels = {
        "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
        "helm.sh/chart"           = "karpenter-0.36.2"
        "app.kubernetes.io/name"  = "karpenter"
        "app.kubernetes.io/instance" = "karpenter"
        "app.kubernetes.io/version" = "0.36.2"
        "app.kubernetes.io/managed-by" = "Helm"
      }
    }
    rules = [
      {
        apiGroups = ["karpenter.sh"]
        resources = ["nodepools", "nodepools/status", "nodeclaims", "nodeclaims/status"]
        verbs     = ["get", "list", "watch", "create", "delete", "patch"]
      },
      {
        apiGroups = ["karpenter.k8s.aws"]
        resources = ["ec2nodeclasses"]
        verbs     = ["get", "list", "watch", "create", "delete", "patch"]
      }
    ]
  }
}

resource "kubernetes_manifest" "karpenter_clusterrole_core" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = "karpenter-core"
      labels = {
        "helm.sh/chart"           = "karpenter-0.36.2"
        "app.kubernetes.io/name"  = "karpenter"
        "app.kubernetes.io/instance" = "karpenter"
        "app.kubernetes.io/version" = "0.36.2"
        "app.kubernetes.io/managed-by" = "Helm"
      }
    }
    rules = [
      {
        apiGroups = ["karpenter.sh"]
        resources = ["nodepools", "nodepools/status", "nodeclaims", "nodeclaims/status"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = [""]
        resources = ["pods", "nodes", "persistentvolumes", "persistentvolumeclaims", "replicationcontrollers", "namespaces"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = ["storage.k8s.io"]
        resources = ["storageclasses", "csinodes"]
        verbs     = ["get", "watch", "list"]
      },
      {
        apiGroups = ["apps"]
        resources = ["daemonsets", "deployments", "replicasets", "statefulsets"]
        verbs     = ["list", "watch"]
      },
      {
        apiGroups = ["policy"]
        resources = ["poddisruptionbudgets"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = ["karpenter.sh"]
        resources = ["nodeclaims", "nodeclaims/status"]
        verbs     = ["create", "delete", "update", "patch"]
      },
      {
        apiGroups = ["karpenter.sh"]
        resources = ["nodepools", "nodepools/status"]
        verbs     = ["update", "patch"]
      },
      {
        apiGroups = [""]
        resources = ["events"]
        verbs     = ["create", "patch"]
      },
      {
        apiGroups = [""]
        resources = ["nodes"]
        verbs     = ["patch", "delete"]
      },
      {
        apiGroups = [""]
        resources = ["pods/eviction"]
        verbs     = ["create"]
      }
    ]
  }
}

resource "kubernetes_manifest" "karpenter_clusterrole" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRole"
    metadata = {
      name = "karpenter"
      labels = {
        "helm.sh/chart"           = "karpenter-0.36.2"
        "app.kubernetes.io/name"  = "karpenter"
        "app.kubernetes.io/instance" = "karpenter"
        "app.kubernetes.io/version" = "0.36.2"
        "app.kubernetes.io/managed-by" = "Helm"
      }
    }
    rules = [
      {
        apiGroups = ["karpenter.k8s.aws"]
        resources = ["ec2nodeclasses"]
        verbs     = ["get", "list", "watch"]
      },
      {
        apiGroups = ["karpenter.k8s.aws"]
        resources = ["ec2nodeclasses", "ec2nodeclasses/status"]
        verbs     = ["patch", "update"]
      }
    ]
  }
}

resource "kubernetes_manifest" "karpenter_clusterrolebinding_core" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "karpenter-core"
      labels = {
        "helm.sh/chart"           = "karpenter-0.36.2"
        "app.kubernetes.io/name"  = "karpenter"
        "app.kubernetes.io/instance" = "karpenter"
        "app.kubernetes.io/version" = "0.36.2"
        "app.kubernetes.io/managed-by" = "Helm"
      }
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "karpenter-core"
    }
    subjects = [
      {
        kind      = "ServiceAccount"
        name      = "karpenter"
        namespace = "kube-system"
      }
    ]
  }
}

resource "kubernetes_manifest" "karpenter_clusterrolebinding" {
  manifest = {
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "karpenter"
      labels = {
        "helm.sh/chart"           = "karpenter-0.36.2"
        "app.kubernetes.io/name"  = "karpenter"
        "app.kubernetes.io/instance" = "karpenter"
        "app.kubernetes.io/version" = "0.36.2"
        "app.kubernetes.io/managed-by" = "Helm"
      }
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "karpenter"
    }
    subjects = [
      {
        kind      = "ServiceAccount"
        name      = "karpenter"
        namespace = "kube-system"
      }
    ]
  }
}
resource "kubernetes_role" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = "kube-system"
    labels = {
      "helm.sh/chart"            = "karpenter-0.36.2"
      "app.kubernetes.io/name"   = "karpenter"
      "app.kubernetes.io/instance" = "karpenter"
      "app.kubernetes.io/version" = "0.36.2"
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["get", "watch"]
  }

  rule {
    api_groups     = ["coordination.k8s.io"]
    resources      = ["leases"]
    verbs          = ["patch", "update"]
    resource_names = ["karpenter-leader-election"]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["create"]
  }
}

resource "kubernetes_role" "karpenter_dns" {
  metadata {
    name      = "karpenter-dns"
    namespace = "kube-system"
    labels = {
      "helm.sh/chart"            = "karpenter-0.36.2"
      "app.kubernetes.io/name"   = "karpenter"
      "app.kubernetes.io/instance" = "karpenter"
      "app.kubernetes.io/version" = "0.36.2"
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }

  rule {
    api_groups     = [""]
    resources      = ["services"]
    resource_names = ["kube-dns"]
    verbs          = ["get"]
  }
}


resource "kubernetes_role" "karpenter_lease" {
  metadata {
    name      = "karpenter-lease"
    namespace = "kube-node-lease"
    labels = {
      "helm.sh/chart"              = "karpenter-0.36.2"
      "app.kubernetes.io/name"     = "karpenter"
      "app.kubernetes.io/instance" = "karpenter"
      "app.kubernetes.io/version"  = "0.36.2"
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["coordination.k8s.io"]
    resources  = ["leases"]
    verbs      = ["delete"]
  }
}


resource "kubernetes_role_binding" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = "kube-system"
    labels = {
      "helm.sh/chart"                = "karpenter-0.36.2"
      "app.kubernetes.io/name"       = "karpenter"
      "app.kubernetes.io/instance"   = "karpenter"
      "app.kubernetes.io/version"    = "0.36.2"
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "karpenter"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "karpenter"
    namespace = "kube-system"
  }
}

resource "kubernetes_role_binding" "karpenter_dns" {
  metadata {
    name      = "karpenter-dns"
    namespace = "kube-system"
    labels = {
      "helm.sh/chart"                = "karpenter-0.36.2"
      "app.kubernetes.io/name"       = "karpenter"
      "app.kubernetes.io/instance"   = "karpenter"
      "app.kubernetes.io/version"    = "0.36.2"
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "karpenter-dns"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "karpenter"
    namespace = "kube-system"
  }
}

resource "kubernetes_role_binding" "karpenter_lease" {
  metadata {
    name      = "karpenter-lease"
    namespace = "kube-node-lease"
    labels = {
      "helm.sh/chart"                = "karpenter-0.36.2"
      "app.kubernetes.io/name"       = "karpenter"
      "app.kubernetes.io/instance"   = "karpenter"
      "app.kubernetes.io/version"    = "0.36.2"
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "karpenter-lease"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "karpenter"
    namespace = "kube-system"
  }
}

resource "kubernetes_service" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = "kube-system"
    labels = {
      "helm.sh/chart"                = "karpenter-0.36.2"
      "app.kubernetes.io/name"       = "karpenter"
      "app.kubernetes.io/instance"   = "karpenter"
      "app.kubernetes.io/version"    = "0.36.2"
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }

  spec {
    type = "ClusterIP"

    port {
      name       = "http-metrics"
      port       = 8000
      target_port = "http-metrics"
      protocol   = "TCP"
    }

    selector = {
      "app.kubernetes.io/name"     = "karpenter"
      "app.kubernetes.io/instance" = "karpenter"
    }
  }
}

data "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
}

locals {
  new_map_roles = yamlencode([
    {
      groups   = ["system:masters"]
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-eks-cluster-admins-role"
      username = "admin"
    },
    {
      groups   = ["system:bootstrappers", "system:nodes"]
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.cluster_name}-eks-cluster-standardNodeGroup-role"
      username = "system:node:{{EC2PrivateDNSName}}"
    },
    {
      groups   = ["system:bootstrappers", "system:nodes"]
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/KarpenterNodeRole-${var.cluster_name}"
      username = "system:node:{{EC2PrivateDNSName}}"
    }
  ])
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = local.new_map_roles
  }

  force = true
}

resource "kubernetes_deployment" "karpenter" {
  metadata {
    name      = "karpenter"
    namespace = "kube-system"
    labels = {
      "helm.sh/chart"                = "karpenter-0.36.2"
      "app.kubernetes.io/name"       = "karpenter"
      "app.kubernetes.io/instance"   = "karpenter"
      "app.kubernetes.io/version"    = "0.36.2"
      "app.kubernetes.io/managed-by" = "Helm"
    }
  }

  spec {
    replicas = 2
    revision_history_limit = 10

    strategy {
      rolling_update {
        max_unavailable = 1
      }
    }

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "karpenter"
        "app.kubernetes.io/instance" = "karpenter"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "karpenter"
          "app.kubernetes.io/instance" = "karpenter"
        }
      }

      spec {
        service_account_name = "karpenter"

        security_context {
          fs_group = 65532
        }

        priority_class_name = "system-cluster-critical"
        dns_policy = "ClusterFirst"

        container {
          name = "controller"

          security_context {
            run_as_user  = 65532
            run_as_group = 65532
            run_as_non_root = true
            seccomp_profile {
              type = "RuntimeDefault"
            }
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
            read_only_root_filesystem = true
          }

          image = "public.ecr.aws/karpenter/controller:0.36.2@sha256:858faf3c7236659ef344cfbca0a1052f9b6c2636125daeab6e2cb427b4aed6d1"
          image_pull_policy = "IfNotPresent"

          env {
            name  = "KUBERNETES_MIN_VERSION"
            value = "1.19.0-0"
          }
          env {
            name  = "KARPENTER_SERVICE"
            value = "karpenter"
          }
          env {
            name  = "LOG_LEVEL"
            value = "info"
          }
          env {
            name  = "METRICS_PORT"
            value = "8000"
          }
          env {
            name  = "HEALTH_PROBE_PORT"
            value = "8081"
          }
          env {
            name  = "SYSTEM_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }
          env {
            name  = "MEMORY_LIMIT"
            value_from {
              resource_field_ref {
                container_name = "controller"
                divisor        = "0"
                resource       = "limits.memory"
              }
            }
          }
          env {
            name  = "FEATURE_GATES"
            value = "Drift=true,SpotToSpotConsolidation=false"
          }
          env {
            name  = "BATCH_MAX_DURATION"
            value = "10s"
          }
          env {
            name  = "BATCH_IDLE_DURATION"
            value = "1s"
          }
          env {
            name  = "ASSUME_ROLE_DURATION"
            value = "15m"
          }
          env {
            name  = "CLUSTER_NAME"
            value = "${var.cluster_name}"
          }
          env {
            name  = "VM_MEMORY_OVERHEAD_PERCENT"
            value = "0.075"
          }
          env {
            name  = "RESERVED_ENIS"
            value = "0"
          }

          port {
            name        = "http-metrics"
            container_port = 8000
            protocol    = "TCP"
          }
          port {
            name        = "http"
            container_port = 8081
            protocol    = "TCP"
          }

          liveness_probe {
            initial_delay_seconds = 30
            timeout_seconds      = 30
            http_get {
              path = "/healthz"
              port = "http"
            }
          }

          readiness_probe {
            initial_delay_seconds = 5
            timeout_seconds      = 30
            http_get {
              path = "/readyz"
              port = "http"
            }
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }

        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "karpenter.sh/nodepool"
                  operator = "DoesNotExist"
                }
              }
              node_selector_term {
                match_expressions {
                  key      = "eks.amazonaws.com/nodegroup"
                  operator = "In"
                  values   = ["${var.cluster_name}-ng"]
                }
              }
            }
          }

          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              topology_key = "kubernetes.io/hostname"
            }
          }
        }

        topology_spread_constraint {
          label_selector {
            match_labels = {
              "app.kubernetes.io/instance" = "karpenter"
              "app.kubernetes.io/name"     = "karpenter"
            }
          }
          max_skew            = 1
          topology_key        = "topology.kubernetes.io/zone"
          when_unsatisfiable  = "ScheduleAnyway"
        }

        toleration {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        }
      }
    }
  }
}

resource "kubernetes_manifest" "nodepool" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata = {
      name = "default"
    }
    spec = {
      template = {
        spec = {
          requirements = [
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "kubernetes.io/os"
              operator = "In"
              values   = ["linux"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot"]
            },
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["c", "m", "r"]
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["2"]
            }
          ]
          nodeClassRef = {
            apiVersion = "karpenter.k8s.aws/v1beta1"
            kind       = "EC2NodeClass"
            name       = "default"
          }
        }
      }
      limits = {
        cpu = 1000
      }
      disruption = {
        consolidationPolicy = "WhenUnderutilized"
        expireAfter         = "720h"
      }
    }
  }
}

resource "kubernetes_manifest" "ec2nodeclass" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "default"
    }
    spec = {
      amiFamily = "AL2"
      role      = "KarpenterNodeRole-${var.cluster_name}"
      subnetSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
      securityGroupSelectorTerms = [
        {
          tags = {
            "karpenter.sh/discovery" = var.cluster_name
          }
        }
      ]
    }
  }
}
