output "service_accounts" {
  description = "Map of runtime service accounts keyed by service identifier"
  value = {
    for service_id in keys(module.runtime_service_accounts) :
    service_id => {
      email = module.runtime_service_accounts[service_id].service_account_email
      name  = module.runtime_service_accounts[service_id].service_account_name
      id    = module.runtime_service_accounts[service_id].service_account_id
    }
  }
}

output "service_account_emails" {
  description = "Convenience map of runtime service account emails keyed by service identifier"
  value = {
    for service_id in keys(module.runtime_service_accounts) :
    service_id => module.runtime_service_accounts[service_id].service_account_email
  }
}
