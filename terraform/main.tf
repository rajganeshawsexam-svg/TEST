# Create VPC first
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  region               = var.aws_region
  tags                 = var.tags
  cluster_name  = "payload-eks"
}

# IAM role for EKS control plane -> created by aws_eks_cluster automatically if needed
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
  tags = var.tags
}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# Attach required AWS managed policies for EKS cluster role
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSServicePolicy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# IAM role for EKS Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
  tags = var.tags
}

data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Security group for EKS cluster communication
resource "aws_security_group" "eks_cluster_sg" {
  name        = "${var.cluster_name}-sg"
  description = "Cluster security group"
  vpc_id      = module.vpc.vpc_id
  tags        = var.tags
}

# EKS cluster
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.29" # choose your desired version

  vpc_config {
    subnet_ids = concat(module.vpc.private_subnet_ids, module.vpc.public_subnet_ids)
    endpoint_private_access = false
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.eks_cluster_sg.id]
  }

  # simple default logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  tags = var.tags

  # depends_on to ensure role policies are attached
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSServicePolicy
  ]
}

# Managed Node Group (AWS-managed)
resource "aws_eks_node_group" "ng" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-nodegroup"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = module.vpc.private_subnet_ids

  scaling_config {
    desired_size = var.node_group_desired
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  instance_types = [var.node_instance_type]


  tags = merge(var.tags, { "k8s.io/cluster-autoscaler/enabled" = "true" })
  depends_on = [aws_eks_cluster.this]
}

# Generate kubeconfig file to local path for convenience
resource "local_file" "kubeconfig" {
  filename = "${path.module}/kubeconfig_${var.cluster_name}"

  content = <<EOT
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.this.endpoint}
    certificate-authority-data: ${aws_eks_cluster.this.certificate_authority[0].data}
  name: ${aws_eks_cluster.this.name}
contexts:
- context:
    cluster: ${aws_eks_cluster.this.name}
    user: ${aws_eks_cluster.this.name}
  name: ${aws_eks_cluster.this.name}
current-context: ${aws_eks_cluster.this.name}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.this.name}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      command: aws
      args:
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "${aws_eks_cluster.this.name}"
        - "--region"
        - "${var.aws_region}"
EOT
}


locals {
  kubeconfig_path = "${path.module}/kubeconfig_${var.cluster_name}"
}

module "rds_postgres" {
  source     = "./modules/rds_postgres"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  db_name     = "payloadcms"
  db_username = "payloadadmin"
  db_password = "StrongPassword123!"
  tags        = var.tags
}

resource "aws_ecr_repository" "payload_repo" {
  name = "payloadcms"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Name = "payload-ecr" })
}

resource "aws_ecr_repository" "api_repo" {
  name = "payload-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, { Name = "api-ecr" })
}

module "alb_controller" {
  source       = "./modules/alb_controller"
  cluster_name = aws_eks_cluster.this.name
  region       = var.aws_region
  vpc_id       = module.vpc.vpc_id
  depends_on = [ aws_eks_cluster.this,
                 aws_eks_node_group.ng ]

}

module "traefik" {
  source = "./modules/traefik"
  depends_on = [
  module.alb_controller
]
}

module "s3_media" {
  source = "./modules/s3_media"
  env    = "dev"
  domain = "cms.rajpoc.clik"
  tags   = var.tags
  depends_on = [
  module.alb_controller
]
}

module "cw_logs" {
  source       = "./modules/cw_logs"
  cluster_name = aws_eks_cluster.this.name
  region       = var.aws_region
  depends_on = [
  module.alb_controller
]
}
module "cloudfront" {
  source = "./modules/cloudfront"

  domain_name     = "rajpoc.click"
  traefik_nlb_dns = "k8s-traefik-traefik-3f4ac0661b-70747e85eab4007b.elb.ap-south-1.amazonaws.com"

  cms_cert_arn     = "arn:aws:acm:us-east-1:517066985764:certificate/62d64f32-0b20-4c3f-a895-72e819fd137a"
  api_cert_arn     = "arn:aws:acm:us-east-1:517066985764:certificate/62d64f32-0b20-4c3f-a895-72e819fd137a"
  traefik_cert_arn = "arn:aws:acm:us-east-1:517066985764:certificate/62d64f32-0b20-4c3f-a895-72e819fd137a"
}



