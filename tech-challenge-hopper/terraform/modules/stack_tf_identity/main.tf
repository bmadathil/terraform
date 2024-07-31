terraform {
  required_version = ">=0.12"
}
provider "aws" {
  region = var.region
}


data "aws_caller_identity" "current" {}

# SecureString parameters in Systems Manager for all secrets/important data
resource "aws_ssm_parameter" "github_user" {
  name  = "/${var.CLUSTER_NAME}/${var.github_user}"
  type  = "SecureString"
  value = "${var.github_user}"


 lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ssm_parameter" "github_pat" {
  name  = "/${var.CLUSTER_NAME}/${var.github_pat}"
  type  = "SecureString"
  value = "${var.github_pat}"

 lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ssm_parameter" "cluster_name" {
  name  = "/${var.CLUSTER_NAME}/${var.CLUSTER_NAME}"
  type  = "String"
  value = "${var.CLUSTER_NAME}"

 lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ssm_parameter" "cluster_domain" {
  name  = "/${var.CLUSTER_NAME}/${var.CLUSTER_DOMAIN}"
  type  = "String"
  value = "${var.CLUSTER_DOMAIN}"

 lifecycle {
    create_before_destroy = true
  }
}

# Managed policies EKS requires for nodegroups
locals {
  nodegroupManagedPolicyArns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
  ]
}

# Create the EKS cluster admins role
resource "aws_iam_role" "admins_iam_role" {
  name               = "${var.CLUSTER_NAME}-eks-cluster-admins-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "admins_iam_role_policy" {
  name   = "${var.CLUSTER_NAME}-eks-cluster-admins-policy"
  role   = aws_iam_role.admins_iam_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:*", "ec2:DescribeImages"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*"
      }
    ]
  })
}

# Create the EKS cluster developers role
resource "aws_iam_role" "devs_iam_role" {
  name               = "${var.CLUSTER_NAME}-eks-cluster-devs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Create the standard node group worker role and attach the required policies
resource "aws_iam_role" "std_nodegroup_iam_role" {
  name               = "${var.CLUSTER_NAME}-eks-cluster-standardNodeGroup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "std_nodegroup_role_policy_attachment" {
  role       = aws_iam_role.std_nodegroup_iam_role.name
  policy_arn = local.nodegroupManagedPolicyArns[0]
}

# Create the performance node group worker role and attach the required policies
resource "aws_iam_role" "perf_nodegroup_iam_role" {
  name               = "${var.CLUSTER_NAME}-eks-cluster-performanceNodeGroup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "perf_nodegroup_role_policy_attachment" {
  role       = aws_iam_role.perf_nodegroup_iam_role.name
  policy_arn = local.nodegroupManagedPolicyArns[0]
}

