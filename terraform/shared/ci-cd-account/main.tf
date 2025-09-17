terraform {
  required_version = ">= 1.13"
  backend "s3" {
    bucket                      = "terraform"
    key                         = "todo-poc/shared/ci-cd-account/terraform.tfstate"
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

locals {
  repo_root       = abspath("${path.module}/../..")
  service_catalog = jsondecode(file("${local.repo_root}/service_catalog.json"))

  ci_cd_services = {
    for service_id, service in local.service_catalog.services :
    service_id => {
      repo_owner = service.build.repository.owner
      repo_name  = service.build.repository.name
      service_account = {
        account_id   = service.build.service_account.account_id
        display_name = coalesce(try(service.build.service_account.display_name, null), "${service.display_name} CI Service Account")
        description  = coalesce(try(service.build.service_account.description, null), "Service account for ${service.display_name} CI/CD pipeline")
        roles        = try(service.build.service_account.roles, [])
      }
      workload_identity = {
        pool_id      = service.build.workload_identity.pool_id
        provider_id  = service.build.workload_identity.provider_id
        display_name = coalesce(try(service.build.workload_identity.provider_display_name, null), "${service.display_name} GitHub Provider")
        description  = coalesce(try(service.build.workload_identity.provider_description, null), "OIDC provider for ${service.display_name} GitHub Actions")
      }
    }
    if try(service.build, null) != null
  }

  workload_identity_pool_ids = distinct([
    for service in values(local.ci_cd_services) :
    service.workload_identity.pool_id
  ])

  workload_identity_pools = {
    for pool_id in local.workload_identity_pool_ids :
    pool_id => {
      display_name = "GitHub Workload Identity Pool"
      description  = "Workload Identity Pool for GitHub Actions CI/CD"
    }
  }
}

resource "google_project_service" "iamcredentials" {
  service = "iamcredentials.googleapis.com"
}

module "ci_cd_service_accounts" {
  for_each = local.ci_cd_services

  source = "../../modules/service-account"

  project_id   = var.project_id
  account_id   = each.value.service_account.account_id
  display_name = each.value.service_account.display_name
  description  = each.value.service_account.description
  roles        = each.value.service_account.roles
}

resource "google_iam_workload_identity_pool" "github_ci_cd" {
  for_each = local.workload_identity_pools

  project                   = var.project_id
  workload_identity_pool_id = each.key
  display_name              = each.value.display_name
  description               = each.value.description
}

resource "google_iam_workload_identity_pool_provider" "github_ci_cd" {
  for_each = local.ci_cd_services

  workload_identity_pool_id          = google_iam_workload_identity_pool.github_ci_cd[each.value.workload_identity.pool_id].workload_identity_pool_id
  workload_identity_pool_provider_id = each.value.workload_identity.provider_id
  display_name                       = each.value.workload_identity.display_name
  description                        = each.value.workload_identity.description

  attribute_condition = "assertion.repository == \"${each.value.repo_owner}/${each.value.repo_name}\""

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.owner"      = "assertion.repository_owner"
    "attribute.ref"        = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "ci_cd_workload_identity_user" {
  for_each = local.ci_cd_services

  service_account_id = module.ci_cd_service_accounts[each.key].service_account_name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_ci_cd[each.value.workload_identity.pool_id].name}/attribute.repository/${each.value.repo_owner}/${each.value.repo_name}"
}
