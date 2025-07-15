#!/bin/bash
set -e

echo "🔄 Generando inventario dinámico para DEV..."

# Obtener IP de Terraform DEV
cd terraform/environments/dev
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ Error: No se pudo obtener la IP de la instancia DEV"
    echo "Ejecuta primero: cd terraform/environments/dev && terraform apply"
    exit 1
fi

echo "✅ IP obtenida: $INSTANCE_IP"

# Crear directorio si no existe
mkdir -p ../../../ansible/inventories/dev

# Generar inventario para DEV dinámicamente CON VARIABLES DE MONITOREO
cat > ../../../ansible/inventories/dev/hosts.yml << EOFDEV
---
zentravision:
  hosts:
    zentravision-dev:
      ansible_host: $INSTANCE_IP
      ansible_user: zentravision
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

  vars:
    gcp_project_id: zentraflow
    app_environment: dev
    domain_name: "dev-zentravision.zentratek.com"
    admin_email: "consultoria@zentratek.com"
    app_repo_url: "https://github.com/jfbm74/zentravision.git"
    app_version: develop
    
    # Django superuser
    django_create_superuser: true
    django_superuser_username: admin
    django_superuser_email: "consultoria@zentratek.com"
    django_superuser_password: "${DJANGO_ADMIN_PASSWORD:-DevPassword123!}"
    
    # Dev settings - HABILITAR SSL
    debug_mode: true
    ssl_enabled: true
    backup_enabled: false
    
    # Monitoring configuration
    monitoring_enabled: true
    vault_grafana_prometheus_url: "https://prometheus-prod-56-prod-us-east-2.grafana.net/api/prom/push"
    vault_grafana_username: "2353449"
    vault_grafana_password: "{{ lookup('env', 'GRAFANA_API_TOKEN') }}"
    vault_monitoring_db_password: "monitoring123"
EOFDEV

echo "✅ Inventario DEV generado: ../../../ansible/inventories/dev/hosts.yml"
echo "📍 Instance IP: $INSTANCE_IP"
echo "🌐 Dominio: dev-zentravision.zentratek.com"
echo "👤 Usuario SSH: zentravision"
echo "📊 Monitoreo: Variables incluidas"
echo ""
echo "⚠️  IMPORTANTE: Configura el DNS para que dev-zentravision.zentratek.com apunte a $INSTANCE_IP"

# Volver al directorio raíz
cd ../../..
