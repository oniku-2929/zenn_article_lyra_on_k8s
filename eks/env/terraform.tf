terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.22.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.4"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.2"
    }
    helm = {
      source  = "registry.terraform.io/hashicorp/helm"
      version = "~> 2.10.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.12.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 5.33.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.1"
    }
  }

  required_version = "~> 1.5.0"
}
