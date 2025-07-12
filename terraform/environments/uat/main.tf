terraform {
  required_version = ">= 1.0"
  
  backend "gcs" {
    bucket = "zentraflow-terraform-state"
    prefix = "terraform/state/uat"
  }
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Usar VPC default para MVP
data "google_compute_network" "default" {
  name = "default"
}

# Deploy single instance module
module "zentravision_instance" {
  source = "../../modules/single-instance"

  project_id    = var.project_id
  region        = var.region
  zone          = var.zone
  environment   = var.environment
  project_name  = "zentravision"

  # Instance configuration
  machine_type = var.machine_type
  disk_size    = var.disk_size
  vpc_network  = data.google_compute_network.default.name

  # Domain and SSL
  domain_name = var.domain_name
  subdomain   = var.subdomain
  dns_zone    = var.dns_zone
  admin_email = var.admin_email

  # SSH access
  admin_user         = var.admin_user
  ssh_public_key     = var.ssh_public_key
  ssh_source_ranges  = var.ssh_source_ranges

  # Backup configuration
  backup_retention_days = var.backup_retention_days

  # Monitoring
  notification_channels = var.notification_channels
}
