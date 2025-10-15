variable "vpc_cidr" {
  type = string
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "region" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "cluster_name" {
  type        = string
  description = "EKS cluster name to tag subnets correctly"
}