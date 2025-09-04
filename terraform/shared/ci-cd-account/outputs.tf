output "service_account_github_actions_email" {
  description = "The email address of the CI/CD service account for GitHub Actions"
  value       = module.ci_cd_service_account.service_account_email
}

output "google_iam_workload_identity_pool_provider_github_name" {
  description = "The name of the GitHub workload identity pool provider"
  value       = module.workload_identity.workload_identity_pool_provider_name
}