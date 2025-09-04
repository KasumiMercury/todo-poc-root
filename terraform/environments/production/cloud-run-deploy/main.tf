terraform {
  required_version = ">= 1.11"
  backend "s3" {
    bucket                      = "terraform"
    key                         = "todo-poc/environments/production/cloud-run-deploy/terraform.tfstate"
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

data "terraform_remote_state" "runtime_account" {
  backend = "s3"
  config = {
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
}

data "terraform_remote_state" "artifact_registry" {
  backend = "s3"
  config = {
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
}

resource "google_project_service" "run" {
  service = "run.googleapis.com"
}

module "cloud_run_service" {
  source = "../../../modules/cloud-run"
  
  project_id                     = var.project_id
  location                       = var.location
  service_name                   = "todo-poc-cloud-run-prod"
  container_image                = "${data.terraform_remote_state.artifact_registry.outputs.repository_url}/todo-poc-server:${var.image_tag}"
  runtime_service_account_email  = data.terraform_remote_state.runtime_account.outputs.runtime_service_account_email
  environment_variables          = var.environment_variables
  allow_unauthenticated_access   = var.allow_unauthenticated_access
  deletion_protection            = var.deletion_protection
}