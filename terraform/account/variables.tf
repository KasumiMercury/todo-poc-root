variable "project_id" {
  description = "The ID of the Google Cloud project where resources will be created."
  type        = string
  default     = null
}

variable "location" {
  description = "The location where Cloud Run services will be deployed."
  type        = string
  default     = ""
}
