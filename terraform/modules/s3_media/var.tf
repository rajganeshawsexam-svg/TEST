variable "env" {
  type    = string
  default = "dev"
}

variable "domain" {
  type        = string
  description = "Domain name for CloudFront or app"
  default = "api.rajpoc.click"
}

variable "tags" {
  type = map(string)
}
