#!/bin/bash
set -e

# Obtener IP de Terraform
cd terraform/environments/prod
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ Error: No se pudo obtener la IP de la instancia"
    echo "Ejecuta primero: make apply"
    exit 1
fi

# Generar inventario
cat > ../../ansible/inventories/prod/hosts.yml << EOF
---
zentravision:
  hosts:
    zentravision-prod:
      ansible_host: $INSTANCE_IP
      ansible_user: admin
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

  vars:
    gcp_project_id: zentraflow
    environment: prod
    domain_name: "${DOMAIN_NAME:-zentravision.ejemplo.com}"
    admin_email: "${ADMIN_EMAIL:-admin@ejemplo.com}"
    app_version: main
    
    # Django superuser
    django_create_superuser: true
    django_superuser_username: admin
    django_superuser_email: "${ADMIN_EMAIL:-admin@ejemplo.com}"
    django_superuser_password: "${DJANGO_ADMIN_PASSWORD:-ChangeMe123!}"
