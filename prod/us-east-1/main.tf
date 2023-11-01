terraform {
  required_version = "~> 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "clowd-haus-iac-us-east-1"
    key            = "<TODO>/prod/us-east-1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "clowd-haus-terraform-state"
    encrypt        = true
  }
}

provider "aws" {
  region = local.region

  assume_role {
    role_arn     = "arn:aws:iam::665739354515:role/terraform"
    session_name = local.name
  }
}

################################################################################
# Common Locals
################################################################################

locals {
  name        = "<TODO>"
  region      = "us-east-1"
  environment = "prod"
}

################################################################################
# Common Data
################################################################################

# tflint-ignore: terraform_unused_declarations
data "aws_caller_identity" "current" {}

################################################################################
# Common Modules
################################################################################

module "tags" {
  # tflint-ignore: terraform_module_pinned_source
  source = "git@github.com:clowdhaus/terraform-tags.git"

  environment = local.environment
  repository  = "https://github.com/clowdhaus/${local.name}"
}
