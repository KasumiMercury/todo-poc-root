output "deployment_service_account_email" {
  description = "Email of the deployment service account"
  value       = module.deployment_service_account.service_account_email
}

output "deployment_service_account_name" {
  description = "Name of the deployment service account"
  value       = module.deployment_service_account.service_account_name
}

output "workload_identity_pool_provider" {
  description = "Workload Identity Pool Provider for GitHub Actions"
  value       = module.deployment_workload_identity.workload_identity_pool_provider_name
}