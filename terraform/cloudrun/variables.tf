variable "project_id" {
  description = "A name of a GCP project"
  type        = string
}

variable "location" {
  description = "A location of a cloud run instance"
  type        = string
}

variable "container_image" {
  description = "docker container image"
  type        = string
}

variable "service_account_id" {
  description = "Service account ID to be used by Cloud Run"
  type        = string
  default = "todo-poc-terraform"
}
