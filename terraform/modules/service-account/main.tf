terraform {
  required_version = ">= 1.13"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.1"
    }
  }
}

resource "google_service_account" "main" {
  account_id   = var.account_id
  display_name = var.display_name
  description  = var.description
  project      = var.project_id
}

resource "google_project_iam_member" "roles" {
  for_each = toset([
    for role in var.roles : role
    if role != "roles/iam.serviceAccountUser"
  ])
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.main.email}"
}

resource "google_service_account_iam_member" "impersonation" {
  for_each = toset(var.service_account_impersonation_targets)
  
  service_account_id = each.key
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.main.email}"
}