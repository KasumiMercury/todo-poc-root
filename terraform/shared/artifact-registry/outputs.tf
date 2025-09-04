output "repository_url" {
  description = "The URL of the Artifact Registry repository"
  value       = "${var.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_repo.repository_id}"
}

output "repository_id" {
  description = "The ID of the Artifact Registry repository"
  value       = google_artifact_registry_repository.app_repo.repository_id
}

output "repository_location" {
  description = "The location of the Artifact Registry repository"
  value       = google_artifact_registry_repository.app_repo.location
}