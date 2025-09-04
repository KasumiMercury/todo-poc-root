variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "location" {
  description = "The location where Cloud Run service will be deployed"
  type        = string
}

variable "service_name" {
  description = "The name of the Cloud Run service"
  type        = string
}

variable "container_image" {
  description = "The container image URL to deploy"
  type        = string
}

variable "runtime_service_account_email" {
  description = "The email address of the service account to run the service as"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables to set in the container"
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false
}

variable "allow_unauthenticated_access" {
  description = "Whether to allow unauthenticated access to the service"
  type        = bool
  default     = false
}