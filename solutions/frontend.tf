locals {
  frontend_dir   = "${path.module}/../frontend_dist"
  frontend_files = fileset(local.frontend_dir, "**")

  mime_types = {
    ".js"   = "application/javascript"
    ".html" = "text/html"
  }
}

resource "aws_s3_bucket" "frontend" {
  bucket = "s3-bucket-${local.id}"
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls = false
}

resource "aws_s3_object" "frontend" {
  for_each = local.frontend_files

  bucket       = aws_s3_bucket.frontend.id
  key          = each.value
  source       = "${local.frontend_dir}/${each.value}"
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
  etag         = filemd5("${local.frontend_dir}/${each.value}")

  acl = "public-read"

  # We can only provision objects with ACL after they are enabled on the bucket,
  # but there is still some eventual consistency, so it might still fail
  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
}

data "aws_cloudfront_cache_policy" "frontend" {
  name = "Managed-CachingDisabled"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled         = true
  is_ipv6_enabled = true

  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend.website_endpoint
    origin_id   = aws_s3_bucket.frontend.bucket_regional_domain_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  aliases = ["${local.id}.${data.aws_route53_zone.cloudlabs-aws-no.name}"]

  viewer_certificate {
    //cloudfront_default_certificate = true
    acm_certificate_arn = aws_acm_certificate_validation.frontend.certificate_arn
    ssl_support_method  = "sni-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  default_cache_behavior {
    cache_policy_id        = data.aws_cloudfront_cache_policy.frontend.id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.frontend.bucket_regional_domain_name
  }
}

output "website_url" {
  description = "Website URL (HTTPS)"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "s3_url" {
  description = "S3 hosting URL (HTTP)"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

# Create domain name
data "aws_route53_zone" "cloudlabs-aws-no" {
  provider = aws.ws-dns

  name = "cloudlabs-aws.no."
}

resource "aws_route53_record" "frontend" {
  provider = aws.ws-dns

  zone_id = data.aws_route53_zone.cloudlabs-aws-no.zone_id
  name    = "${local.id}.${data.aws_route53_zone.cloudlabs-aws-no.name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "frontend" {
  provider          = aws.ws-acm
  domain_name       = "${local.id}.${data.aws_route53_zone.cloudlabs-aws-no.name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "frontend-validation" {
  provider = aws.ws-dns
  zone_id  = data.aws_route53_zone.cloudlabs-aws-no.zone_id
  name     = one(aws_acm_certificate.frontend.domain_validation_options).resource_record_name
  type     = one(aws_acm_certificate.frontend.domain_validation_options).resource_record_type
  records  = [one(aws_acm_certificate.frontend.domain_validation_options).resource_record_value]
  ttl      = 60
}

resource "aws_acm_certificate_validation" "frontend" {
  provider                = aws.ws-acm
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [aws_route53_record.frontend-validation.fqdn]
}

output "certificate_arn" {
  value = aws_acm_certificate.frontend.arn
}

output "certificate_validation_arn" {
  value = aws_acm_certificate_validation.frontend.certificate_arn
}
