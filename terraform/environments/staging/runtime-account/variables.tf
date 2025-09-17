variable "project_id" {
  description = "The ID of the Google Cloud project where resources will be created."
  type        = string
}

variable "location" {
  description = "The location where Cloud Run services will be deployed."
  type        = string
}

variable "environment" {
  description = "Identifier for this environment (e.g., staging)."
  type        = string
  default     = "staging"
}
