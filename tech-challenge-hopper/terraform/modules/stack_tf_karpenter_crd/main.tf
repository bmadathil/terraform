provider "kubernetes" {
  config_path = "/tmp/kubeconfig"
}



locals {
  crds = {
    nodepool     = "${path.module}/crd/karpenter.sh_nodepools.yaml"
    ec2nodeclass = "${path.module}/crd/karpenter.k8s.aws_ec2nodeclasses.yaml"
    nodeclaim    = "${path.module}/crd/karpenter.sh_nodeclaims.yaml"
  }
}

resource "null_resource" "apply_crds" {
  for_each = local.crds

  provisioner "local-exec" {
    command = "kubectl --kubeconfig=/tmp/kubeconfig apply -f ${each.value}"
  }
}
