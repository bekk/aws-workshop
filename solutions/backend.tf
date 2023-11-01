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
