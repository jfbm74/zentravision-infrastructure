#!/bin/bash
set -e

# Obtener IP de Terraform UAT
cd terraform/environments/uat
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ Error: No se pudo obtener la IP de la instancia UAT"
    exit 1
fi

# Crear directorio si no existe
mkdir -p ../../../ansible/inventories/uat

# Generar inventario para UAT con repositorio real
cat > ../../../ansible/inventories/uat/hosts.yml << EOFUAT
---
zentravision:
  hosts:
    zentravision-uat:
      ansible_host: $INSTANCE_IP
      ansible_user: zentravision
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

  vars:
    gcp_project_id: zentraflow
    environment: uat
    domain_name: "uat-zentravision.zentratek.com"
    admin_email: "admin@zentratek.com"
    app_repo_url: "https://github.com/jfbm74/zentravision.git"
    app_version: main
    
    # Django superuser
    django_create_superuser: true
    django_superuser_username: admin
    django_superuser_email: "admin@zentratek.com"
    django_superuser_password: "UatPassword123!"
    
    # UAT settings
    debug_mode: false
    ssl_enabled: true
    backup_enabled: true
EOFUAT

echo "✅ Inventario UAT generado: ansible/inventories/uat/hosts.yml"
echo "Instance IP: $INSTANCE_IP"
echo "Repositorio: https://github.com/jfbm74/zentravision.git"
echo "Rama: main"

# Volver al directorio raíz
cd ../../..
