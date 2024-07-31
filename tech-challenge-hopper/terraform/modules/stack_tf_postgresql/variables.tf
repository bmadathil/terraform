variable "region" {
  description = "Aws Regsion"
  type        = string
  default     = "us-east-1"
}
variable "kubeconfig" {
  description = "kubeconfig context "
  type        = string
  default     = "/tmp/kubeconfig"
}

variable "initdb_config_map_name" {
  default = "postgres-initdb-configmap"
}
