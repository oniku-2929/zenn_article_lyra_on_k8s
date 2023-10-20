
terraform {
  backend "local" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.14.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.2"
    }
  }
  required_version = "~> 1.5.0"
}

provider "aws" {
  region = "ap-northeast-1"
}

provider "docker" {}

data "docker_image" "lyra_server_debug" {
  name = "lyra-server:debug"
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

module "ecr" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name                 = "lyra-on-k8s-agones"
  repository_image_tag_mutability = "MUTABLE"

  repository_read_write_access_arns = [
    data.aws_caller_identity.current.arn
  ]

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 3 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["debug", "development", "shipping"],
          countType     = "imageCountMoreThan",
          countNumber   = 3
        },
        action = {
          type = "expire"
        }
      }
    ]
  })
}
