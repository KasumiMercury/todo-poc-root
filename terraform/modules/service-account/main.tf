resource "google_service_account" "main" {
  account_id   = var.account_id
  display_name = var.display_name
  description  = var.description
  project      = var.project_id
}

resource "google_project_iam_member" "roles" {
  for_each = toset(var.roles)
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.main.email}"
}