# terraform.tfvars

bucket_name = "tech-chal-unique-terraform-state-bucket"
bucket_key  = "terraform/state/terraform.tfstate"

kubeconfig = "/tmp/kubeconfig"
namespaces = [
  { name = "dev" },
  { name = "test" },
  { name = "prod" },
  { name = "amazon-cloudwatch" },
  { name = "devops" },
  { name = "external-dns" },
  { name = "pgadmin" },
  { name = "smtp4dev" },
  { name = "traefik" },
]

