output "services" {
  description = "Per-service deployment outputs"
  value = {
    for service_id in keys(module.cloud_run_services) :
    service_id => {
      service_name = module.cloud_run_services[service_id].service_name
      service_url  = module.cloud_run_services[service_id].service_url
      urls         = module.cloud_run_services[service_id].urls
      location     = module.cloud_run_services[service_id].location
      service_id   = module.cloud_run_services[service_id].service_id
    }
  }
  sensitive = true
}
