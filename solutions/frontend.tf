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

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  restrict_public_buckets = false
}

resource "aws_s3_object" "file" {
  for_each = local.frontend_files

  bucket       = aws_s3_bucket.frontend.id
  key          = each.value
  source       = "${local.frontend_dir}/${each.value}"
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
  etag         = filemd5("${local.frontend_dir}/${each.value}")
  acl          = "public-read"
}


resource "aws_cloudfront_distribution" "distribution" {
  enabled         = true
  is_ipv6_enabled = true

  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend.website_endpoint
    origin_id   = aws_s3_bucket.frontend.bucket_regional_domain_name

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "http-only"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  default_cache_behavior {
    cache_policy_id        = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.frontend.bucket_regional_domain_name
  }
}

output "website_url" {
  description = "Website URL (HTTPS)"
  value       = aws_cloudfront_distribution.distribution.domain_name
}

output "s3_url" {
  description = "S3 hosting URL (HTTP)"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

