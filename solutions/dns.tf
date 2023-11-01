
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
