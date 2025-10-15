terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}


data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
}

# 🧩 Get the TLS certificate for the EKS OIDC issuer
data "tls_certificate" "oidc_thumbprint" {
  url = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# 1️⃣ Create OIDC provider for IRSA
resource "aws_iam_openid_connect_provider" "oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc_thumbprint.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# 2️⃣ Load Balancer Controller IAM Policy
resource "aws_iam_policy" "alb_policy" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("${path.module}/AWSLoadBalancerControllerIAMPolicy.json")
}

# 3️⃣ IRSA IAM Role for ALB Controller
resource "aws_iam_role" "alb_role" {
  name = "eks-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.oidc.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

# 4️⃣ Attach IAM policy
resource "aws_iam_role_policy_attachment" "alb_attach" {
  role       = aws_iam_role.alb_role.name
  policy_arn = aws_iam_policy.alb_policy.arn
}
resource "aws_iam_role_policy" "alb_controller_policy" {
  name = "AWSLoadBalancerControllerIAMPolicy"
  role = aws_iam_role.alb_role.id
  policy = data.aws_iam_policy_document.alb_controller_policy.json
}
data "aws_iam_policy_document" "alb_controller_policy" {
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    resources = [
      "arn:aws:iam::*:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing"
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }

}


resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.2"
  set = [ {
     name  = "clusterName"
     value = var.cluster_name
    },
    {name  = "region"
    value = var.region
    },
    {
    name  = "vpcId"
    value = var.vpc_id
    },
    {
    name  = "serviceAccount.create"
    value = "true"
    },
    {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
    },
    {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_role.arn
    }

    ]

  depends_on = [
    aws_iam_role_policy_attachment.alb_attach
  ]
}

