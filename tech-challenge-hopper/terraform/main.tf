provider "aws" {
  region = var.region
}

module "identity" {
  source = "./modules/stack_tf_identity"
  bucket_name   = var.bucket_name
  bucket_key    = var.bucket_key
  region        = var.region
  CLUSTER_NAME  = var.CLUSTER_NAME
  github_user   = var.github_user
  github_pat    = var.github_pat
  CLUSTER_DOMAIN = var.CLUSTER_DOMAIN
}

module "infra" {
  source = "./modules/stack_tf_eks_infra"
  bucket_name   = var.bucket_name
  bucket_key    = var.bucket_key
  region        = var.region
  CLUSTER_NAME  = var.CLUSTER_NAME
  cluster_name  = var.CLUSTER_NAME
  github_user   = var.github_user
  github_pat    = var.github_pat
  CLUSTER_DOMAIN = var.CLUSTER_DOMAIN
  cidr_block = var.cidr_block
  k8s_version = var.k8s_version
}

module "karpentercrd" {
  source = "./modules/stack_tf_karpenter_crd"
}
module "karpenter" {
  source = "./modules/stack_tf_karpenter"
  aws_region        = var.region
  cluster_name  = var.CLUSTER_NAME
  k8s_version = var.k8s_version
}
module "namespace" {
  source = "./modules/stack_tf_namespaces"
  namespaces = var.namespaces
}
module "ebscsi" {
  source = "./modules/stack_tf_ebs_csi_driver"
}
module "storageclasses" {
  source = "./modules/stack_tf_storage_classes"
}
module "reflector" {
  source = "./modules/stack_tf_reflector"
}
module "externalsecretscrd" {
  source = "./modules/stack_tf_external_secrets_crd"
}
module "externalsecrets" {
  source = "./modules/stack_tf_external_secrets"
  AWS_ACCESS_KEY_ID = var.AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY = var.AWS_SECRET_ACCESS_KEY
  namespaces = var.namespaces
}
module "dockerconfig" {
  source = "./modules/stack_tf_dockerconfig"
  namespaces = var.namespaces
  github_user = var.github_user
  github_pat = var.github_pat
}
module "eksaddons" {
  source = "./modules/stack_tf_eks_addons"
  cluster_name = var.CLUSTER_NAME
}
module "traefikdeploy" {
  source = "./modules/stack_tf_traefik_deploy"
  cluster_name = var.CLUSTER_NAME
}
module "traefikresources" {
  source = "./modules/stack_tf_traefik_resources"
  cluster_name = var.CLUSTER_NAME
  hosted_zone = var.hosted_zone
}
module "postgres" {
  source = "./modules/stack_tf_postgresql"
}
module "pgadmin" {
  source = "./modules/stack_tf_pgadmin"
  cluster_name = var.CLUSTER_NAME
  hosted_zone = var.hosted_zone
}
module "keycloak" {
  source = "./modules/stack_tf_keycloak"
  cluster_name = var.CLUSTER_NAME
  hosted_zone = var.hosted_zone
}
module "jenkins" {
  source = "./modules/stack_tf_jenkins"
  cluster_name = var.CLUSTER_NAME
  region = var.region
  hosted_zone = var.hosted_zone
  github_user = var.github_user
  github_pat  = var.github_pat
}
module "sonarqube" {
  source = "./modules/stack_tf_sonarqube"
  cluster_name = var.CLUSTER_NAME
  region = var.region
  hosted_zone = var.hosted_zone
  github_user = var.github_user
  github_pat  = var.github_pat
}
module "jenkinseed" {
  source = "./modules/stack_tf_jenkins_seed"
  cluster_name = var.CLUSTER_NAME
  region = var.region
  hosted_zone = var.hosted_zone
  github_user = var.github_user
  github_pat  = var.github_pat
}
module "argocd" {
  source = "./modules/stack_tf_argocd"
  cluster_name = var.CLUSTER_NAME
  region = var.region
  hosted_zone = var.hosted_zone
  github_user = var.github_user
  github_pat  = var.github_pat
}
module "argoapp" {
  source = "./modules/stack_tf_argoapp"
  cluster_name = var.CLUSTER_NAME
  region = var.region
  hosted_zone = var.hosted_zone
  github_user = var.github_user
  github_pat  = var.github_pat
}
module "smtp" {
  source = "./modules/stack_tf_smtp"
  cluster_name = var.CLUSTER_NAME
  region = var.region
  hosted_zone = var.hosted_zone
  github_user = var.github_user
  github_pat  = var.github_pat
}
module "kafka" {
  source = "./modules/stack_tf_kafka"
  cluster_name = var.CLUSTER_NAME
  region = var.region
  hosted_zone = var.hosted_zone
  github_user = var.github_user
  github_pat  = var.github_pat
}
