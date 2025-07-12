terraform {
  required_version = ">= 1.11"
  backend "s3" {
    bucket                      = "terraform"
    key                         = "todo-poc/account/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true
  }
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4"
    }
  }
}

provider "cloudflare" {
  # token pulled from $CLOUDFLARE_API_TOKEN
}

provider "google" {}

locals {
  cloudrun_roles = [
    "roles/run.developer",
    "roles/iam.serviceAccountUser",
  ]
}
