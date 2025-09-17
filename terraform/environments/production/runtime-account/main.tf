terraform {
  required_version = ">= 1.13"
  backend "s3" {
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

moved {
  from = module.runtime_service_account
  to   = module.runtime_service_accounts["task-api"]
}

locals {
  repo_root       = abspath("${path.module}/../../..")
  service_catalog = jsondecode(file("${local.repo_root}/service_catalog.json"))
  environment     = var.environment

  runtime_service_configs = {
    for service_id, service in local.service_catalog.services :
    service_id => service.runtime.service_accounts[local.environment]
    if try(service.runtime.service_accounts[local.environment], null) != null
  }

  runtime_services = {
    for service_id, config in local.runtime_service_configs :
    service_id => {
      account_id            = config.account_id
      display_name          = coalesce(try(config.display_name, null), "${local.service_catalog.services[service_id].display_name} Runtime Service Account (${local.environment})")
      description           = coalesce(try(config.description, null), "Runtime service account for ${local.service_catalog.services[service_id].display_name} (${local.environment})")
      roles                 = try(config.roles, [])
      impersonation_targets = try(config.impersonation_targets, [])
    }
  }
}

module "runtime_service_accounts" {
  for_each = local.runtime_services

  source = "../../../modules/service-account"

  project_id                            = var.project_id
  account_id                            = each.value.account_id
  display_name                          = each.value.display_name
  description                           = each.value.description
  roles                                 = each.value.roles
  service_account_impersonation_targets = each.value.impersonation_targets
}
