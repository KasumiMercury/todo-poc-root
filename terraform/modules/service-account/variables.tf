variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "account_id" {
  description = "The service account ID"
  type        = string
}

variable "display_name" {
  description = "The display name for the service account"
  type        = string
}

variable "description" {
  description = "Description of the service account"
  type        = string
  default     = ""
}

variable "roles" {
  description = "List of IAM roles to assign to the service account at project level"
  type        = list(string)
  default     = []
}

variable "service_account_impersonation_targets" {
  description = "List of service account emails that this service account can impersonate (grants roles/iam.serviceAccountUser on specific service accounts instead of project-wide)"
  type        = list(string)
  default     = []
}