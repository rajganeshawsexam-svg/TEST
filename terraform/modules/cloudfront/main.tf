#############################################################
# CloudFront + WAF for rajpoc.clik (CMS + API + ROOT)
#############################################################
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

locals {
  common_headers = ["Authorization", "Host", "Origin", "Referer"]
}

#############################################################
# Data sources (CloudFront managed policies)
#############################################################

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

#############################################################
# WAF (Global for CloudFront)
#############################################################

resource "aws_wafv2_web_acl" "rajpoc_waf" {
  provider    = aws.us_east_1
  name        = "rajpoc-waf"
  description = "Global WAF for rajpoc.clik CloudFront"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSCommonRules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "rajpocWAF"
    sampled_requests_enabled   = true
  }
}

#############################################################
# CloudFront: CMS → Traefik
#############################################################

resource "aws_cloudfront_distribution" "cms_cf" {
  provider    = aws.us_east_1
  comment         = "CloudFront for cms.${var.domain_name}"
  enabled         = true
  is_ipv6_enabled = true
  aliases         = ["cms.${var.domain_name}"]
  price_class     = "PriceClass_100"

  origin {
    domain_name = var.traefik_nlb_dns
    origin_id   = "cms-origin"

    custom_origin_config {
      origin_protocol_policy = "https-only"
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "cms-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.cms_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.rajpoc_waf.arn
}

#############################################################
# CloudFront: API → Traefik
#############################################################

resource "aws_cloudfront_distribution" "api_cf" {
  provider    = aws.us_east_1
  comment         = "CloudFront for api.${var.domain_name}"
  enabled         = true
  is_ipv6_enabled = true
  aliases         = ["api.${var.domain_name}"]
  price_class     = "PriceClass_100"

  origin {
    domain_name = var.traefik_nlb_dns
    origin_id   = "api-origin"

    custom_origin_config {
      origin_protocol_policy = "https-only"
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "api-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.api_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.rajpoc_waf.arn
}

#############################################################
# CloudFront: ROOT (traefik.rajpoc.clik) → Traefik
#############################################################

resource "aws_cloudfront_distribution" "root_cf" {
  provider    = aws.us_east_1
  comment         = "CloudFront for traefik.${var.domain_name}"
  enabled         = true
  is_ipv6_enabled = true
  aliases         = ["traefik.${var.domain_name}"]
  price_class     = "PriceClass_100"

  origin {
    domain_name = var.traefik_nlb_dns
    origin_id   = "traefik-origin"

    custom_origin_config {
      origin_protocol_policy = "https-only"
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "traefik-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.traefik_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.rajpoc_waf.arn
}
