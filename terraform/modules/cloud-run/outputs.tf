output "service_name" {
  description = "The name of the Cloud Run service"
  value       = google_cloud_run_v2_service.default.name
}

output "service_url" {
  description = "The URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.default.uri
}

output "urls" {
  description = "The URLs on which the deployed service is available"
  value       = google_cloud_run_v2_service.default.urls
}

output "location" {
  description = "The location of the Cloud Run service"
  value       = google_cloud_run_v2_service.default.location
}

output "service_id" {
  description = "The unique ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.default.id
}