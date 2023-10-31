terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.20.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

provider "aws" {
  # Must correspond to the AWS CLI configured profile name
  profile             = "cloudlabs"
  region              = "eu-west-1"
  allowed_account_ids = ["893160086441"]
}

provider "aws" {
  alias = "ws-dns"
  # Must correspond to the AWS CLI configured profile name
  profile             = "cloudlabs-dns"
  region              = "eu-west-1"
  allowed_account_ids = ["325039187874"]
}

provider "aws" {
  alias = "ws-acm"
  # Must correspond to the AWS CLI configured profile name
  profile             = "cloudlabs-acm"
  region              = "us-east-1"
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

# This check will display a warning to the participants if they forget to set
# the id local variable in main.tf
check "id_is_set" {
  assert {
    error_message = "Id must be set in main.tf"
    condition     = length(local.id) > 0
  }
}
