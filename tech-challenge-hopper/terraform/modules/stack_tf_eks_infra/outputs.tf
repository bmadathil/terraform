
output "eks_vpc_ref" {
  value = "${var.CLUSTER_NAME}-vpc"
}
output "azs" {
  value =  data.aws_availability_zones.available.names[0]
}
