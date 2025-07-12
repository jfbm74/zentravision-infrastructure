variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "zentraflow"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "machine_type" {
  description = "Machine type for the instance"
  type        = string
  default     = "e2-standard-2"
}

variable "disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "admin_email" {
  description = "Administrator email for SSL certificates"
  type        = string
}

variable "admin_user" {
  description = "Admin user for SSH access"
  type        = string
  default     = "admin"
}

variable "ssh_public_key" {
  description = "SSH public key for admin access"
  type        = string
}

variable "ssh_source_ranges" {
  description = "Source IP ranges for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 30
}

variable "dns_zone" {
  description = "Cloud DNS zone name (optional)"
  type        = string
  default     = ""
}

variable "subdomain" {
  description = "Subdomain for the application (optional)"
  type        = string
  default     = ""
}

variable "notification_channels" {
  description = "Notification channels for alerts"
  type        = list(string)
  default     = []
}
