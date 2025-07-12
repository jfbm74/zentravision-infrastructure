variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the instance"
  type        = string
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
}

variable "vpc_network" {
  description = "VPC network name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = ""
}

variable "dns_zone" {
  description = "Cloud DNS zone name"
  type        = string
  default     = ""
}

variable "admin_email" {
  description = "Administrator email"
  type        = string
}

variable "admin_user" {
  description = "Admin user for SSH"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
}

variable "ssh_source_ranges" {
  description = "Source ranges for SSH"
  type        = list(string)
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
}

variable "notification_channels" {
  description = "Notification channels for monitoring"
  type        = list(string)
  default     = []
}
