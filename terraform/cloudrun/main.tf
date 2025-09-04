terraform {
  required_version = ">= 1.11"
  backend "s3" {
    bucket                      = "terraform"
    key                         = "todo-poc/cloudrun/terraform.tfstate"
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
      version = "~> 7.0"
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

resource "google_cloud_run_v2_service" "default" {
  name     = "todo-poc-cloud-run"
  location = var.location
  template {
    containers {
      image = var.container_image
    }
    service_account = "${var.service_account_id}@${var.project_id}.iam.gserviceaccount.com"
  }
  deletion_protection = false
}

resource "google_cloud_run_v2_service_iam_member" "run_admin" {
  project  = var.project_id
  location = google_cloud_run_v2_service.default.location
  name     = google_cloud_run_v2_service.default.name
  role     = "roles/run.admin"
  member   = "serviceAccount:${var.service_account_id}@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_service_account_iam_member" "service_account_user" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.service_account_id}@${var.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.service_account_id}@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "artifactregistry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${var.service_account_id}@${var.project_id}.iam.gserviceaccount.com"
}

output "urls" {
  value = google_cloud_run_v2_service.default.urls
}

# data "google_iam_policy" "cloud_run" {
#   binding {
#     role = "roles/run.invoker"
#     members = [
#       "allUsers",
#     ]
#   }
# }

# data "google_cloud_run_v2_service_iam_policy" "policy" {
#   location = google_cloud_run_v2_service.default.location
#   project  = google_cloud_run_v2_service.default.project
#   name     = google_cloud_run_v2_service.default.name
# }
