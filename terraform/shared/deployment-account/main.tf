terraform {
  required_version = ">= 1.11"
  backend "s3" {
    bucket                      = "terraform"
    key                         = "todo-poc/shared/deployment-account/terraform.tfstate"
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
      version = "~> 6.0"
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

locals {
  repo_owner = "KasumiMercury"
  repo_name  = "todo-poc-root"
}

resource "google_project_service" "iamcredentials" {
  service = "iamcredentials.googleapis.com"
}

module "deployment_service_account" {
  source = "../../modules/service-account"
  
  project_id   = var.project_id
  account_id   = "todo-poc-deployment"
  display_name = "Todo POC Deployment Service Account"
  description  = "Service account for GitHub Actions Cloud Run deployment"
  
  roles = [
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
    "roles/artifactregistry.reader",
    "roles/compute.networkUser"
  ]
}

module "deployment_workload_identity" {
  source = "../../modules/workload-identity"
  
  project_id             = var.project_id
  pool_id                = "github-deployment"
  pool_display_name      = "Deployment Pool"
  pool_description       = "Workload Identity Pool for GitHub Actions deployment"
  provider_id            = "github-deployment-provider"
  provider_display_name  = "GitHub Deployment Provider"
  provider_description   = "GitHub OIDC Provider for deployment"
  
  attribute_condition    = "assertion.repository_owner == \"${local.repo_owner}\""
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.owner"      = "assertion.repository_owner"
    "attribute.ref"        = "assertion.ref"
  }
  
  oidc_issuer_uri        = "https://token.actions.githubusercontent.com"
  service_account_id     = module.deployment_service_account.service_account_name
  principal_set_filter   = "attribute.repository/${local.repo_owner}/${local.repo_name}"
}