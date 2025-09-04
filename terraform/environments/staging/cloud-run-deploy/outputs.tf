output "cloud_run_urls" {
  description = "The URLs of the deployed Cloud Run service"
  value       = module.cloud_run_service.urls
  sensitive   = true
}

output "cloud_run_service_url" {
  description = "The primary URL of the deployed Cloud Run service"
  value       = module.cloud_run_service.service_url
  sensitive   = true
}

output "cloud_run_service_name" {
  description = "The name of the deployed Cloud Run service"
  value       = module.cloud_run_service.service_name
  sensitive   = true
}