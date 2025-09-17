output "workload_identity_pool_name" {
  description = "The name of the workload identity pool"
  value       = google_iam_workload_identity_pool.github.name
}

output "workload_identity_pool_id" {
  description = "The workload identity pool ID"
  value       = google_iam_workload_identity_pool.github.workload_identity_pool_id
}

output "workload_identity_pool_provider_name" {
  description = "The name of the workload identity pool provider"
  value       = google_iam_workload_identity_pool_provider.github.name
}
