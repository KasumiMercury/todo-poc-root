terraform {
  required_version = ">= 1.13"
  backend "s3" {
    bucket                      = "terraform"
    key                         = "todo-poc/environments/production/cloud-run-deploy/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true
  }
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.1"
    }
  }
}

provider "cloudflare" {
  # token pulled from $CLOUDFLARE_API_TOKEN
}

provider "google" {
  project = var.project_id
  region  = var.location
}

data "terraform_remote_state" "runtime_account" {
  backend = "s3"
  config = {
    bucket                      = "terraform"
    key                         = "todo-poc/environments/production/runtime-account/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true
  }
}

data "terraform_remote_state" "artifact_registry" {
  backend = "s3"
  config = {
    bucket                      = "terraform"
    key                         = "todo-poc/shared/artifact-registry/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true
  }
}

resource "google_project_service" "run" {
  service = "run.googleapis.com"

  lifecycle {
    precondition {
      condition     = length(local.missing_service_ids) == 0
      error_message = "Missing config entries for services: ${join(", ", local.missing_service_ids)}"
    }
    precondition {
      condition     = length(local.missing_image_tags) == 0
      error_message = "Missing image_tag values for services: ${join(", ", local.missing_image_tags)}"
    }
  }
}

locals {
  repo_root       = abspath("${path.module}/../../..")
  service_catalog = jsondecode(file("${local.repo_root}/service_catalog.json"))
  environment     = var.environment

  service_definitions = {
    for service_id, service in local.service_catalog.services :
    service_id => {
      service_name = service.deploy.cloud_run[local.environment].service_name
      image_name   = service.artifact.image
      defaults     = try(service.deploy.defaults, {})
      overrides    = try(service.deploy.cloud_run[local.environment].overrides, {})
      display_name = service.display_name
    }
    if try(service.deploy.cloud_run[local.environment], null) != null
  }

  required_service_ids   = keys(local.service_definitions)
  configured_service_ids = keys(var.service_config)
  missing_service_ids    = sort(setsubtract(local.required_service_ids, local.configured_service_ids))
  missing_image_tags = [
    for service_id in local.required_service_ids :
    service_id
    if !try(var.service_config[service_id].skip, false)
    && trim(coalesce(var.service_config[service_id].image_tag, "")) == ""
  ]

  service_configs = {
    for service_id, definition in local.service_definitions :
    service_id => {
      image_tag = coalesce(var.service_config[service_id].image_tag, "")
      environment_variables = merge(
        try(definition.defaults.environment_variables, {}),
        try(definition.overrides.environment_variables, {}),
        try(var.service_config[service_id].environment_variables, {})
      )
      allow_unauthenticated_access = try(var.service_config[service_id].allow_unauthenticated_access, try(definition.overrides.allow_unauthenticated_access, try(definition.defaults.allow_unauthenticated_access, false)))
      deletion_protection          = try(var.service_config[service_id].deletion_protection, try(definition.overrides.deletion_protection, try(definition.defaults.deletion_protection, true)))
    }
    if !try(var.service_config[service_id].skip, false)
  }
}

module "cloud_run_services" {
  for_each = local.service_configs

  source = "../../../modules/cloud-run"

  project_id                    = var.project_id
  location                      = var.location
  service_name                  = local.service_definitions[each.key].service_name
  container_image               = "${data.terraform_remote_state.artifact_registry.outputs.repository_url}/${local.service_definitions[each.key].image_name}:${each.value.image_tag}"
  runtime_service_account_email = data.terraform_remote_state.runtime_account.outputs.service_accounts[each.key].email
  environment_variables         = each.value.environment_variables
  allow_unauthenticated_access  = each.value.allow_unauthenticated_access
  deletion_protection           = each.value.deletion_protection
}
