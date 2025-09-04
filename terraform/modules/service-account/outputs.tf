output "service_account_email" {
  description = "The email address of the service account"
  value       = google_service_account.main.email
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = google_service_account.main.name
}

output "service_account_id" {
  description = "The unique ID of the service account"
  value       = google_service_account.main.unique_id
}