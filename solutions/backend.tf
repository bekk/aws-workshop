resource "aws_apprunner_service" "todo" {
  service_name = "ar-todo-id"

  source_configuration {
    image_repository {
      image_configuration {
        port = "8000"
        runtime_environment_variables = {
          DATABASE_URL = "postgresql://USER:PASSWORD@HOST:PORT/DATABASE"
        }
      }
      image_identifier      = "public.ecr.aws/m1p3r7y5/bekk-cloudlabs:latest"
      image_repository_type = "ECR_PUBLIC"
    }
    auto_deployments_enabled = false
  }
}

