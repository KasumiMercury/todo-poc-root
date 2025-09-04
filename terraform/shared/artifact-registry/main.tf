terraform {
  required_version = ">= 1.11"
  backend "s3" {
    bucket                      = "terraform"
    key                         = "todo-poc/shared/artifact-registry/terraform.tfstate"
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

resource "google_project_service" "artifactregistry" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
}
resource "google_artifact_registry_repository" "app_repo" {
  project       = var.project_id
  location      = var.location
  repository_id = "todo-poc-repo"
  description   = "Repository for Todo POC"
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"
}