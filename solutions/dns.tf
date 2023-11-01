# Get the hosted zone from the admin account
data "aws_route53_zone" "cloudlabs-aws-no" {
  provider = aws.ws-dns

  name = "cloudlabs-aws.no."
}

# Create a new variable for the API URL
locals {
  api_url = "api.${local.id}.${data.aws_route53_zone.cloudlabs-aws-no.name}"
}

# Configure App Runner with new DNS name
resource "aws_apprunner_custom_domain_association" "todo" {
  domain_name          = local.api_url
  service_arn          = aws_apprunner_service.todo.arn
  # This is an API, so we don't need the www subdomain
  enable_www_subdomain = false
}

# Setup the route53 record for App Runner
resource "aws_route53_record" "backend" {
  # NB! Here we specify which provider we'll use
  provider        = aws.ws-dns

  allow_overwrite = true
  name            = local.api_url
  records         = [aws_apprunner_custom_domain_association.todo.dns_target]
  ttl             = 60
  type            = "CNAME"
  zone_id         = data.aws_route53_zone.cloudlabs-aws-no.zone_id
}

output "validation_records" {
  value = aws_apprunner_custom_domain_association.todo.certificate_validation_records
}

# Create local variable to simplify and avoid duplication
locals {
  validation_records = tolist(aws_apprunner_custom_domain_association.todo.certificate_validation_records)
}

resource "aws_route53_record" "backend_validation_records" {
  // We know there are two records, so using this because for_each with "unknown" number of values gives an error or requires targeted deploy
  count = 2

  provider        = aws.ws-dns
  allow_overwrite = true
  name            = local.validation_records[count.index].name
  records = [
    local.validation_records[count.index].value
  ]
  ttl     = 60
  type    = local.validation_records[count.index].type
  zone_id = data.aws_route53_zone.cloudlabs-aws-no.zone_id
}

### Frontend

# The record that will point to the CloudFront distribution
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

# The certificate
resource "aws_acm_certificate" "frontend" {
  provider          = aws.ws-acm
  domain_name       = "${local.id}.${data.aws_route53_zone.cloudlabs-aws-no.name}"
  validation_method = "DNS"
}

# The validation records
resource "aws_route53_record" "frontend-validation" {
  provider = aws.ws-dns
  zone_id  = data.aws_route53_zone.cloudlabs-aws-no.zone_id
  name     = one(aws_acm_certificate.frontend.domain_validation_options).resource_record_name
  type     = one(aws_acm_certificate.frontend.domain_validation_options).resource_record_type
  records  = [one(aws_acm_certificate.frontend.domain_validation_options).resource_record_value]
  ttl      = 60
}

# Pseudo-resource used to help validation in terraform, see docs
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
