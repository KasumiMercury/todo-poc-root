variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "location" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "environments" {
  description = "Environments whose runtime service accounts should be impersonated"
  type        = list(string)
  default     = ["production", "staging"]
}
