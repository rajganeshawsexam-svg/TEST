variable "domain_name" {
  description = "Base domain (e.g., rajpoc.clik)"
  type        = string
}

variable "traefik_nlb_dns" {
  description = "DNS of Traefik LoadBalancer (private NLB)"
  type        = string
}

variable "cms_cert_arn" {
  description = "ACM certificate ARN for cms.rajpoc.clik"
  type        = string
}

variable "api_cert_arn" {
  description = "ACM certificate ARN for api.rajpoc.clik"
  type        = string
}

variable "traefik_cert_arn" {
  description = "ACM certificate ARN for traefik.rajpoc.clik"
  type        = string
}
