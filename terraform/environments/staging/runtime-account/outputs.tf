output "runtime_service_account_email" {
  description = "The email address of the runtime service account for Cloud Run"
  value       = module.runtime_service_account.service_account_email
}

output "runtime_service_account_name" {
  description = "The full resource name of the runtime service account"
  value       = module.runtime_service_account.service_account_name
}