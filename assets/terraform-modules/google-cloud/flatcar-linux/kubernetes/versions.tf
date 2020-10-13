# Terraform version and plugin versions

terraform {
  required_version = ">= 0.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "2.16.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "2.1.2"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.1.2"
    }
    ct = {
      source = "poseidon/ct"
    }
  }
}
