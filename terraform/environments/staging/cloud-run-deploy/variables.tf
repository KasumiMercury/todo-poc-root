variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "location" {
  description = "The location where Cloud Run services will be deployed"
  type        = string
}

variable "image_tag" {
  description = "The tag of the container image to deploy to Cloud Run (e.g., v1.2.3)"
  type        = string
}

variable "environment_variables" {
  description = "Environment variables to set in the container"
  type        = map(string)
  default     = {}
}

variable "allow_unauthenticated_access" {
  description = "Whether to allow unauthenticated access to the service"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false
}