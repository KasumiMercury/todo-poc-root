output "service_accounts" {
  description = "CI/CD service accounts keyed by service identifier"
  value = {
    for service_id in keys(module.ci_cd_service_accounts) :
    service_id => {
      email = module.ci_cd_service_accounts[service_id].service_account_email
      name  = module.ci_cd_service_accounts[service_id].service_account_name
      id    = module.ci_cd_service_accounts[service_id].service_account_id
    }
  }
}

output "workload_identity_providers" {
  description = "Workload Identity providers keyed by service identifier"
  value = {
    for service_id in keys(google_iam_workload_identity_pool_provider.github_ci_cd) :
    service_id => {
      name                      = google_iam_workload_identity_pool_provider.github_ci_cd[service_id].name
      pool_name                 = google_iam_workload_identity_pool.github_ci_cd[local.ci_cd_services[service_id].workload_identity.pool_id].name
      provider_id               = google_iam_workload_identity_pool_provider.github_ci_cd[service_id].workload_identity_pool_provider_id
      workload_identity_pool_id = local.ci_cd_services[service_id].workload_identity.pool_id
    }
  }
}
