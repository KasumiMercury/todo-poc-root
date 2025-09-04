variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "pool_id" {
  description = "The ID of the workload identity pool"
  type        = string
}

variable "pool_display_name" {
  description = "The display name of the workload identity pool"
  type        = string
}

variable "pool_description" {
  description = "The description of the workload identity pool"
  type        = string
  default     = ""
}

variable "provider_id" {
  description = "The ID of the workload identity pool provider"
  type        = string
}

variable "provider_display_name" {
  description = "The display name of the workload identity pool provider"
  type        = string
}

variable "provider_description" {
  description = "The description of the workload identity pool provider"
  type        = string
  default     = ""
}

variable "attribute_condition" {
  description = "The attribute condition for the provider"
  type        = string
}

variable "attribute_mapping" {
  description = "The attribute mapping for the provider"
  type        = map(string)
}

variable "oidc_issuer_uri" {
  description = "The OIDC issuer URI"
  type        = string
}

variable "service_account_id" {
  description = "The ID of the service account to bind to workload identity"
  type        = string
}

variable "principal_set_filter" {
  description = "The principal set filter for workload identity binding"
  type        = string
}