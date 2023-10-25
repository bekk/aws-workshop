terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.20.1"
    }
    random = {
      source = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

provider "aws" {
  # Must correspond to the AWS CLI configured profile name
  profile             = "ManagedAdministratorAccess-893160086441"
  region              = "eu-west-1"
  allowed_account_ids = ["893160086441"]
}

data "aws_vpc" "default" {
  default = true
}

data "aws_caller_identity" "current" {}

output "user_arn" {
  value = data.aws_caller_identity.current.arn
}

output "user_id" {
  value = data.aws_caller_identity.current.user_id
}
