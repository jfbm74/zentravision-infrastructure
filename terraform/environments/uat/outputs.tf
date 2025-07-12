output "instance_ip" {
  description = "External IP address of the instance"
  value       = module.zentravision_instance.instance_ip
}

output "instance_name" {
  description = "Name of the compute instance"
  value       = module.zentravision_instance.instance_name
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh ${var.admin_user}@${module.zentravision_instance.instance_ip}"
}

output "application_url" {
  description = "URL of the application"
  value       = "https://${var.domain_name}"
}

output "backup_bucket" {
  description = "Backup bucket name"
  value       = module.zentravision_instance.backup_bucket
}
