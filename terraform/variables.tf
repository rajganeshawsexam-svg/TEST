variable "aws_region" {
  type    = string
  default = "ap-south-1"
  description = "AWS region to deploy"
}

variable "aws_profile" {
  type    = string
  default = ""
  description = "AWS CLI profile (optional). Empty => use env credentials"
}

variable "cluster_name" {
  type    = string
  default = "payload-eks"
  description = "EKS cluster name"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "node_group_desired" {
  type    = number
  default = 2
}
variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}
variable "node_min_size" { 
    type = number
    default = 1 
}
variable "node_max_size" { 
    type = number
    default = 3 
}

variable "tags" {
  type = map(string)
  default = {
    Owner = "raj"
    Project = "payload-demo"
  }
}
