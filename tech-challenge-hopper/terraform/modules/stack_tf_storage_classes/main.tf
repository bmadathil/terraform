terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig
}

resource "kubernetes_storage_class" "gp2_expanding" {
  metadata {
    name = "gp2-expanding"
  }

  storage_provisioner = "kubernetes.io/aws-ebs"
  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type = "gp2"
  }

  mount_options = ["debug"]
}
