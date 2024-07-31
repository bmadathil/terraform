terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region 
  alias = "availability_zones"
} 


resource "aws_eks_addon" "cluster_addon_observability" {
  cluster_name = var.cluster_name
  addon_name   = "amazon-cloudwatch-observability"
}
