terraform {
  required_version = ">= 1.13"
  backend "s3" {
    bucket                      = "terraform"
    key                         = "todo-poc/environments/production/runtime-account/terraform.tfstate"
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
    google = {
      source  = "hashicorp/google"
      version = "~> 7.1"
    }
  }
}

provider "cloudflare" {
  # token pulled from $CLOUDFLARE_API_TOKEN
}

provider "google" {
  project = var.project_id
  region  = var.location
}

module "runtime_service_account" {
  source = "../../../modules/service-account"
  
  project_id   = var.project_id
  account_id   = "todo-poc-runtime"
  display_name = "Todo POC Runtime Service Account"
  description  = "Service account for Cloud Run application runtime"
  
  # Minimal runtime permissions - add application-specific permissions as needed
  roles = []
}