variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default = "payload-eks"
}

variable "region" {
  type        = string
  default = "ap-south-1"
  description = "AWS region where the cluster is deployed"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID of the cluster"
}
