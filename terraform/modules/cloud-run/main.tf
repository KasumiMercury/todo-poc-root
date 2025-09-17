terraform {
  required_version = ">= 1.13"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.1"
    }
  }
}

resource "google_cloud_run_v2_service" "default" {
  name     = var.service_name
  location = var.location
  project  = var.project_id

  template {
    containers {
      image = var.container_image

      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }
    }
    service_account = var.runtime_service_account_email
  }

  deletion_protection = var.deletion_protection
}

# Optional: Allow unauthenticated access if specified
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = var.allow_unauthenticated_access ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_service.default.location
  name     = google_cloud_run_v2_service.default.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}