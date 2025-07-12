output "instance_ip" {
  description = "External IP of the instance"
  value       = google_compute_address.static_ip.address
}

output "instance_name" {
  description = "Name of the compute instance"
  value       = google_compute_instance.zentravision_instance.name
}

output "instance_zone" {
  description = "Zone of the compute instance"
  value       = google_compute_instance.zentravision_instance.zone
}

output "backup_bucket" {
  description = "Name of the backup bucket"
  value       = google_storage_bucket.backup_bucket.name
}

output "media_bucket" {
  description = "Name of the media bucket"
  value       = google_storage_bucket.media_bucket.name
}

output "service_account_email" {
  description = "Email of the service account"
  value       = google_service_account.zentravision_sa.email
}

output "domain_name" {
  description = "Configured domain name"
  value       = var.domain_name
}

output "ssl_certificate_domains" {
  description = "Domains configured for SSL"
  value       = [var.domain_name]
}
