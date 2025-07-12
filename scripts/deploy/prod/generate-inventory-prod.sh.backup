#!/bin/bash
set -e

echo "🔄 Generando inventario dinámico para PRODUCCIÓN..."

# Obtener IP de Terraform PROD
cd terraform/environments/prod
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ Error: No se pudo obtener la IP de la instancia PROD"
    echo "Ejecuta primero: cd terraform/environments/prod && terraform apply"
    exit 1
fi

echo "✅ IP obtenida: $INSTANCE_IP"

# Crear directorio si no existe
mkdir -p ../../../ansible/inventories/prod

# Obtener variables de entorno o usar valores por defecto
DOMAIN_NAME="${DOMAIN_NAME:-zentravision.zentratek.com}"
ADMIN_EMAIL="${ADMIN_EMAIL:-consultoria@zentratek.com}"
DJANGO_ADMIN_PASSWORD="${DJANGO_ADMIN_PASSWORD:-ChangeMe123!}"

# Generar inventario para PROD dinámicamente
cat > ../../../ansible/inventories/prod/hosts.yml << EOFPROD
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
    domain_name: "$DOMAIN_NAME"
    admin_email: "$ADMIN_EMAIL"
    app_repo_url: "https://github.com/jfbm74/zentravision.git"
    app_version: main
    
    # Django superuser
    django_create_superuser: true
    django_superuser_username: admin
    django_superuser_email: "$ADMIN_EMAIL"
    django_superuser_password: "$DJANGO_ADMIN_PASSWORD"
    
    # Production settings
    debug_mode: false
    ssl_enabled: true
    backup_enabled: true
EOFPROD

echo "✅ Inventario PROD generado: ../../../ansible/inventories/prod/hosts.yml"
echo "📍 Instance IP: $INSTANCE_IP"
echo "🌐 Dominio: $DOMAIN_NAME"
echo "📧 Admin email: $ADMIN_EMAIL"
echo ""
echo "⚠️  IMPORTANTE: Configura el DNS para que $DOMAIN_NAME apunte a $INSTANCE_IP"

# Volver al directorio raíz
cd ../../..