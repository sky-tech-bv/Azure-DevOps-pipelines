# aws --version
# aws eks --region us-east-1 update-kubeconfig --name in28minutes-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# terraform-backend-state-in28minutes-123
# AKIA4AHVNOD7OOO6T4KI
# s3: terraform-backend-state-skydev-123
# Access key id: AKIAZKDNCVSWUON7DOHN

terraform {
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "us-east-1"
  }
}

resource "aws_default_vpc" "default" {

}

data "aws_subnet_ids" "subnets" {
  vpc_id = aws_default_vpc.default.id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  version                = "~> 2.10"
}

module "skytechbv-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "skytechbv-cluster"
  cluster_version = "1.24"
  subnet_ids         = ["subnet-0ef0d5508555e7946", "subnet-0cb15d0898267c776"] #CHANGE
  #subnets = data.aws_subnet_ids.subnets.ids
  vpc_id          = aws_default_vpc.default.id

  #vpc_id         = "vpc-0d098073d3eb2d578"

    eks_managed_node_groups = {
      test_node = {
        min_size     = 3
        max_size     = 5
        desired_size = 3

        instance_type = "t2.micro"
      }
    }
}

data "aws_eks_cluster" "cluster" {
  name = module.skytechbv-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.skytechbv-cluster.cluster_id
}


# We will use ServiceAccount to connect to K8S Cluster in CI/CD mode
# ServiceAccount needs permissions to create deployments 
# and services in default namespace
resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}

# Needed to set the default region
provider "aws" {
  region  = "us-east-1"
}