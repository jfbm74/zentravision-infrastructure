#!/bin/bash
set -e

# Obtener IP de Terraform DEV
cd terraform/environments/dev
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ Error: No se pudo obtener la IP de la instancia DEV"
    echo "Ejecuta primero: cd terraform/environments/dev && terraform apply"
    exit 1
fi

# Generar inventario para DEV
cat > ansible/inventories/dev/hosts.yml << EOF
---
zentravision:
  hosts:
    zentravision-dev:
      ansible_host: $INSTANCE_IP
      ansible_user: admin
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

  vars:
    gcp_project_id: zentraflow
    environment: dev
    domain_name: "${DOMAIN_NAME:-dev-zentravision.ejemplo.com}"
    admin_email: "${ADMIN_EMAIL:-admin@ejemplo.com}"
    app_version: develop
    
    # Django superuser
    django_create_superuser: true
    django_superuser_username: admin
    django_superuser_email: "${ADMIN_EMAIL:-admin@ejemplo.com}"
    django_superuser_password: "${DJANGO_ADMIN_PASSWORD:-DevPassword123!}"
    
    # Dev settings
    debug_mode: true
    ssl_enabled: false
    backup_enabled: false
EOF

echo "✅ Inventario DEV generado: ansible/inventories/dev/hosts.yml"
echo "Instance IP: $INSTANCE_IP"

# Volver al directorio raíz
cd ../../..