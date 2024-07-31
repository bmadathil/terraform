terraform {
  required_version = ">=0.12"
}
provider "aws" {
  region = var.region
  alias = "availability_zones"
}

data "aws_availability_zones" "available" {}

locals {
  userClusterName = var.CLUSTER_NAME
  clusterDomain   = var.CLUSTER_DOMAIN

  clusterOwnedTag = {
    "kubernetes.io/cluster/${var.CLUSTER_NAME}" = "owned"
  }

  privateElbTag = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  publicElbTag = {
    "kubernetes.io/role/elb" = "1"
  }

  numAzs = 2
  azs    = slice(data.aws_availability_zones.available.names, 0, local.numAzs)
}

resource "aws_vpc" "tfer--vpc-tech-chal" {
  assign_generated_ipv6_cidr_block     = "false"
  cidr_block                           = "172.16.0.0/16"
  enable_dns_hostnames                 = "true"
  enable_dns_support                   = "true"
  enable_network_address_usage_metrics = "false"
  instance_tenancy                     = "default"

  tags = {
    ClusterName = "${local.userClusterName}c"
    Name        = "${local.userClusterName}-vpc"
    Usage       = "hopper"
  }

  tags_all = {
    ClusterName = "${local.userClusterName}"
    Name        = "${local.userClusterName}-vpc"
    Usage       = "hopper"
  }
}

resource "aws_internet_gateway" "igw_eks_main" {
  vpc_id = aws_vpc.tfer--vpc-tech-chal.id

  tags = {
    Name = "${local.userClusterName}-igw"
  }
}
resource "aws_subnet" "tfer--subnet-private-0" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "172.16.16.0/20"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                              = "${local.userClusterName}-private-0"
    "kubernetes.io/cluster/${local.userClusterName}"     = "owned"
    "kubernetes.io/role/internal-elb" = "1"
    type                              = "private"
  }

  tags_all = {
    Name                              = "${local.userClusterName}-private-0"
    "kubernetes.io/cluster/${local.userClusterName}"     = "owned"
    "kubernetes.io/role/internal-elb" = "1"
    type                              = "private"
  }

  vpc_id = aws_vpc.tfer--vpc-tech-chal.id
}

resource "aws_subnet" "tfer--subnet-private-1" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "172.16.32.0/20"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                              = "${local.userClusterName}-private-1"
    "karpenter.sh/discovery"          = "${local.userClusterName}"
    "kubernetes.io/cluster/${local.userClusterName}"     = "owned"
    "kubernetes.io/role/internal-elb" = "1"
    type                              = "private"
  }

  tags_all = {
    Name                              = "${local.userClusterName}-private-1"
    "karpenter.sh/discovery"          = "${local.userClusterName}"
    "kubernetes.io/cluster/${local.userClusterName}"     = "owned"
    "kubernetes.io/role/internal-elb" = "1"
    type                              = "private"
  }

  vpc_id = aws_vpc.tfer--vpc-tech-chal.id
}

resource "aws_subnet" "tfer--subnet-public-0" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "172.16.64.0/20"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "true"
  private_dns_hostname_type_on_launch            = "ip-name"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name                          = "${local.userClusterName}-public-0"
    "karpenter.sh/discovery"      = "${local.userClusterName}"
    "kubernetes.io/cluster/${local.userClusterName}" = "owned"
    "kubernetes.io/role/elb"      = "1"
    type                          = "public"
  }

  tags_all = {
    Name                          = "${local.userClusterName}-public-0"
    "karpenter.sh/discovery"      = "${local.userClusterName}"
    "kubernetes.io/cluster/${local.userClusterName}" = "owned"
    "kubernetes.io/role/elb"      = "1"
    type                          = "public"
  }

  vpc_id = aws_vpc.tfer--vpc-tech-chal.id
}
resource "aws_subnet" "tfer--subnet-public-1" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "172.16.80.0/20"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "true"
  private_dns_hostname_type_on_launch            = "ip-name"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name                          = "${local.userClusterName}-public-1"
    "karpenter.sh/discovery"      = "${local.userClusterName}"
    "kubernetes.io/cluster/${local.userClusterName}" = "owned"
    "kubernetes.io/role/elb"      = "1"
    type                          = "public"
  }

  tags_all = {
    Name                          = "${local.userClusterName}-public-1"
    "karpenter.sh/discovery"      = "${local.userClusterName}"
    "kubernetes.io/cluster/${local.userClusterName}" = "owned"
    "kubernetes.io/role/elb"      = "1"
    type                          = "public"
  }

  vpc_id = aws_vpc.tfer--vpc-tech-chal.id
}

resource "aws_eip" "nat_eip1" {
  /*domain = "vpc"*/

  tags = {
    Name = "nat-eip1"
  }
}
resource "aws_eip" "nat_eip2" {
  /*domain = "vpc"*/

  tags = {
    Name = "nat-eip2"
  }
}

resource "aws_nat_gateway" "nat_gw1" {
  allocation_id = aws_eip.nat_eip1.id
  subnet_id     = aws_subnet.tfer--subnet-public-1.id

  tags = {
    Name = "nat-gateway-pub-1"
  }
}
resource "aws_nat_gateway" "nat_gw2" {
  allocation_id = aws_eip.nat_eip2.id
  subnet_id     = aws_subnet.tfer--subnet-public-0.id

  tags = {
    Name = "nat-gateway-pub-0"
  }
}

resource "aws_route_table" "tfer--rtb-main" {
  vpc_id = aws_vpc.tfer--vpc-tech-chal.id
}

resource "aws_route_table" "tfer--rtb-pub0" {
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_eks_main.id
  }

  vpc_id = aws_vpc.tfer--vpc-tech-chal.id
}
resource "aws_route_table" "tfer--rtb-pub1" {
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_eks_main.id
  }

  vpc_id = aws_vpc.tfer--vpc-tech-chal.id
}


resource "aws_route_table" "tfer--rtb-pri0" {
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw1.id
  }

  vpc_id = aws_vpc.tfer--vpc-tech-chal.id
}

resource "aws_route_table" "tfer--rtb-pri1" {
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw2.id
  }

  vpc_id = aws_vpc.tfer--vpc-tech-chal.id
}


resource "aws_main_route_table_association" "tfer--vpc-assoc1" {
  route_table_id = aws_route_table.tfer--rtb-main.id
  vpc_id         = aws_vpc.tfer--vpc-tech-chal.id
}

resource "aws_route_table_association" "tfer--subnet-pub0" {
  route_table_id = aws_route_table.tfer--rtb-pub0.id
  subnet_id      = aws_subnet.tfer--subnet-public-0.id
}
resource "aws_route_table_association" "tfer--subnet-pub1" {
  route_table_id = aws_route_table.tfer--rtb-pub1.id
  subnet_id      = aws_subnet.tfer--subnet-public-1.id
}

resource "aws_route_table_association" "tfer--subnet-pri0" {
  route_table_id = aws_route_table.tfer--rtb-pri0.id
  subnet_id      = aws_subnet.tfer--subnet-private-0.id
}
resource "aws_route_table_association" "tfer--subnet-pri1" {
  route_table_id = aws_route_table.tfer--rtb-pri1.id
  subnet_id      = aws_subnet.tfer--subnet-private-1.id
}

# EKS Starts here

data "aws_caller_identity" "current" {}

resource "aws_security_group" "eks-cluster-sg" {
  description = "EKS created security group applied to ENI that is attached to EKS Control Plane master nodes, as well as any managed workloads."

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  name = "eks-cluster-sg-${var.CLUSTER_NAME}"

  tags = {
    Name                          = "eks-cluster-sg-${var.CLUSTER_NAME}"
    "karpenter.sh/discovery"      = "${var.CLUSTER_NAME}"
    "kubernetes.io/cluster/${var.CLUSTER_NAME}" = "owned"
  }

  tags_all = {
    Name                          = "eks-cluster-sg-${var.CLUSTER_NAME}"
    "karpenter.sh/discovery"      = "${var.CLUSTER_NAME}"
    "kubernetes.io/cluster/${var.CLUSTER_NAME}" = "owned"
  }

  vpc_id = aws_vpc.tfer--vpc-tech-chal.id
}

# Define the IAM role for the EKS cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "KarpenterNodeRole-${var.CLUSTER_NAME}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach policies to the EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_role_attachment1" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_attachment2" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_attachment3" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_attachment4" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_attachment5" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_attachment6" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" 
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_attachment7" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_role_attachment8" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_eks_cluster" "tfer--eks-cluster" {
/*  access_config {
    authentication_mode                         = "CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = "true"
  } */

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = "10.100.0.0/16"
  }

  name     = "${var.CLUSTER_NAME}"
  role_arn = aws_iam_role.eks_cluster_role.arn

  tags = {
    Name    = "${var.CLUSTER_NAME}-eksCluster"
    Project = "hopper-aws-services"
  }

  tags_all = {
    Name    = "${var.CLUSTER_NAME}-eksCluster"
    Project = "hopper-aws-services"
  }

  version = var.k8s_version

  vpc_config {
    endpoint_private_access = "false"
    endpoint_public_access  = "true"
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.eks-cluster-sg.id]
    subnet_ids              = [aws_subnet.tfer--subnet-public-0.id,aws_subnet.tfer--subnet-public-1.id,aws_subnet.tfer--subnet-private-0.id,aws_subnet.tfer--subnet-private-1.id]
  }
 

}

resource "aws_eks_node_group" "tfer--eks-cluster-ng" {
  ami_type        = "AL2_x86_64"
  capacity_type   = "ON_DEMAND"
  cluster_name    = "${aws_eks_cluster.tfer--eks-cluster.name}"
  disk_size       = "20"
  instance_types  = ["m6i.xlarge"]
  node_group_name = "${var.CLUSTER_NAME}-ng"
  node_role_arn   = aws_iam_role.eks_cluster_role.arn

  scaling_config {
    desired_size = "3"
    max_size     = "5"
    min_size     = "3"
  }

  subnet_ids              = [aws_subnet.tfer--subnet-public-0.id,aws_subnet.tfer--subnet-public-1.id,aws_subnet.tfer--subnet-private-0.id,aws_subnet.tfer--subnet-private-1.id]

  update_config {
    max_unavailable = "1"
  }

  version = var.k8s_version
}


output "cluster_endpoint" {
  value = aws_eks_cluster.tfer--eks-cluster.endpoint
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

resource "local_file" "kubeconfig" {
  content = <<-EOL
  apiVersion: v1
  clusters:
  - cluster:
      certificate-authority-data: ${aws_eks_cluster.tfer--eks-cluster.certificate_authority[0].data}
      server: ${aws_eks_cluster.tfer--eks-cluster.endpoint}
    name: ${aws_eks_cluster.tfer--eks-cluster.arn}
  contexts:
  - context:
      cluster: ${aws_eks_cluster.tfer--eks-cluster.arn}
      user: ${aws_eks_cluster.tfer--eks-cluster.arn}
    name: ${aws_eks_cluster.tfer--eks-cluster.arn}
  current-context: ${aws_eks_cluster.tfer--eks-cluster.arn}
  kind: Config 
  preferences: {}
  users: 
  - name: ${aws_eks_cluster.tfer--eks-cluster.arn}
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        command: aws
        args:
        - eks
        - get-token
        - --region
        - ${var.region}
        - --cluster-name
        - ${var.CLUSTER_NAME}
        - --output
        - json
  EOL

filename = "/tmp/kubeconfig"
depends_on = [aws_eks_cluster.tfer--eks-cluster]
}

