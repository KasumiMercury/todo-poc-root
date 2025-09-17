variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "location" {
  description = "The location where Cloud Run services will be deployed"
  type        = string
}

variable "environment" {
  description = "Identifier for this environment (e.g., production)."
  type        = string
  default     = "production"
}

variable "service_config" {
  description = "Per-service deployment configuration keyed by service identifier"
  type = map(object({
    image_tag                    = optional(string)
    environment_variables        = optional(map(string), {})
    allow_unauthenticated_access = optional(bool)
    deletion_protection          = optional(bool)
    skip                         = optional(bool, false)
  }))
}
