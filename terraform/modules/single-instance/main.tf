# Service Account for the instance
resource "google_service_account" "zentravision_sa" {
  account_id   = "${var.project_name}-${var.environment}"
  display_name = "Zentravision ${title(var.environment)} Service Account"
  description  = "Service account for Zentravision ${var.environment} environment"
}

# IAM roles for the service account
resource "google_project_iam_member" "zentravision_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.zentravision_sa.email}"
}

resource "google_project_iam_member" "zentravision_secretmanager_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.zentravision_sa.email}"
}

resource "google_project_iam_member" "zentravision_monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.zentravision_sa.email}"
}

# Static IP address
resource "google_compute_address" "static_ip" {
  name   = "${var.project_name}-${var.environment}-ip"
  region = var.region
}

# Storage bucket for backups
resource "google_storage_bucket" "backup_bucket" {
  name     = "${var.project_id}-${var.environment}-backups"
  location = var.region

  lifecycle_rule {
    condition {
      age = var.backup_retention_days
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true
}

# Storage bucket for media files
resource "google_storage_bucket" "media_bucket" {
  name     = "${var.project_id}-${var.environment}-media"
  location = var.region

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  uniform_bucket_level_access = true
}

# Firewall rule for HTTP
resource "google_compute_firewall" "allow_http" {
  name    = "${var.project_name}-${var.environment}-allow-http"
  network = var.vpc_network

  allow {
    protocol = "tcp"
    ports    = ["80", "8000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.project_name}-${var.environment}"]
}

# Firewall rule for HTTPS
resource "google_compute_firewall" "allow_https" {
  name    = "${var.project_name}-${var.environment}-allow-https"
  network = var.vpc_network

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.project_name}-${var.environment}"]
}

# Firewall rule for SSH
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.project_name}-${var.environment}-allow-ssh"
  network = var.vpc_network

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.ssh_source_ranges
  target_tags   = ["${var.project_name}-${var.environment}"]
}

# Cloud DNS record (optional)
resource "google_dns_record_set" "domain_a_record" {
  count = var.dns_zone != "" ? 1 : 0

  name = "${var.subdomain != "" ? "${var.subdomain}." : ""}${var.domain_name}."
  type = "A"
  ttl  = 300

  managed_zone = var.dns_zone

  rrdatas = [google_compute_address.static_ip.address]
}

# Startup script - simplified to avoid variable conflicts
locals {
  startup_script = <<-EOF
#!/bin/bash
set -e

# Log startup
exec > >(tee /var/log/startup-script.log) 2>&1
echo "$(date): Starting Zentravision ${var.environment} instance setup..."

# Update system
apt-get update
apt-get upgrade -y

# Install basic packages
apt-get install -y curl wget unzip git htop vim python3 python3-pip python3-venv postgresql-client nginx ufw fail2ban

# Install Google Cloud SDK
if ! command -v gcloud &> /dev/null; then
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    apt-get update
    apt-get install -y google-cloud-cli
fi

# Create application user
if ! id "zentravision" &>/dev/null; then
    useradd -m -s /bin/bash zentravision
    usermod -aG sudo zentravision
fi

# Create application directories
mkdir -p /opt/zentravision/app /opt/zentravision/logs /opt/zentravision/backups /opt/zentravision/static /opt/zentravision/media
chown -R zentravision:zentravision /opt/zentravision

# Configure firewall
ufw --force enable
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 8000

# Set up environment file
cat > /opt/zentravision/.env << 'ENVEOF'
ENVIRONMENT=${var.environment}
DEBUG=False
DOMAIN_NAME=${var.domain_name}
GCP_PROJECT_ID=${var.project_id}
BACKUP_BUCKET=${google_storage_bucket.backup_bucket.name}
MEDIA_BUCKET=${google_storage_bucket.media_bucket.name}
DATABASE_URL=postgresql://zentravision:password@localhost:5432/zentravision
REDIS_URL=redis://localhost:6379/0
DJANGO_SECRET_KEY_SECRET=projects/${var.project_id}/secrets/${var.project_id}-${var.environment}-django-secret/versions/latest
DATABASE_PASSWORD_SECRET=projects/${var.project_id}/secrets/${var.project_id}-${var.environment}-db-password/versions/latest
OPENAI_API_KEY_SECRET=projects/${var.project_id}/secrets/${var.project_id}-${var.environment}-openai-key/versions/latest
ENVEOF

chown zentravision:zentravision /opt/zentravision/.env

# Create backup script without problematic variable interpolation
cat > /opt/zentravision/backup-db.sh << 'BACKUPEOF'
#!/bin/bash
set -e
BACKUP_DIR="/opt/zentravision/backups"
BUCKET_NAME="${google_storage_bucket.backup_bucket.name}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="zentravision_backup_$TIMESTAMP.sql"
pg_dump -h localhost -U zentravision zentravision > "$BACKUP_DIR/$BACKUP_FILE"
gzip "$BACKUP_DIR/$BACKUP_FILE"
gsutil cp "$BACKUP_DIR/$BACKUP_FILE.gz" "gs://$BUCKET_NAME/"
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +7 -delete
echo "Backup completed: $BACKUP_FILE.gz"
BACKUPEOF

chmod +x /opt/zentravision/backup-db.sh
chown zentravision:zentravision /opt/zentravision/backup-db.sh

# Signal completion
echo "$(date): Startup script completed. Ready for Ansible configuration."
touch /var/log/startup-complete
EOF
}

# Compute instance
resource "google_compute_instance" "zentravision_instance" {
  name         = "${var.project_name}-${var.environment}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["${var.project_name}-${var.environment}"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size
      type  = "pd-standard"
    }
  }

  network_interface {
    network = var.vpc_network
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  service_account {
    email  = google_service_account.zentravision_sa.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  metadata = {
    ssh-keys = "${var.admin_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = local.startup_script

  # Allow stopping for maintenance
  allow_stopping_for_update = true
}