resource "aws_apprunner_service" "todo" {
  service_name = "ar-todo-${local.id}"

  source_configuration {
    image_repository {
      image_configuration {
        port = "3000"
        runtime_environment_variables = {
          DATABASE_URL = "postgresql://${aws_db_instance.todo.username}:${random_password.postgres_password.result}@${aws_db_instance.todo.endpoint}/${aws_db_instance.todo.db_name}"
        }
      }
      image_identifier      = "public.ecr.aws/m1p3r7y5/bekk-cloudlabs:latest"
      image_repository_type = "ECR_PUBLIC"
    }
    auto_deployments_enabled = false
  }
}

output "backend-url" {
  value = aws_apprunner_service.todo.service_url
}

locals {
  api_url = "api.${local.id}.${data.aws_route53_zone.cloudlabs-aws-no.name}"
}

resource "aws_apprunner_custom_domain_association" "todo" {
  domain_name          = local.api_url
  service_arn          = aws_apprunner_service.todo.arn
  enable_www_subdomain = false
}

resource "aws_route53_record" "backend" {
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
  #for_each        = { for r in aws_apprunner_custom_domain_association.todo.certificate_validation_records : r.name => r }
  allow_overwrite = true
  name            = local.validation_records[count.index].name
  records = [
    local.validation_records[count.index].value
  ]
  ttl     = 60
  type    = local.validation_records[count.index].type
  zone_id = data.aws_route53_zone.cloudlabs-aws-no.zone_id
}
