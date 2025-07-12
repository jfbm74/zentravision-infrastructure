#!/bin/bash
set -e

INSTANCE_IP=$(cd terraform/environments/prod && terraform output -raw instance_ip 2>/dev/null || echo "")

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ No se pudo obtener la IP de la instancia"
    exit 1
fi

echo "🗄️  Ejecutando backup manual..."
ssh admin@$INSTANCE_IP "sudo -u zentravision /opt/zentravision/backup-db.sh"

echo "📦 Listando backups disponibles..."
ssh admin@$INSTANCE_IP "gsutil ls gs://zentraflow-prod-backups/ | tail -5"

echo "✅ Backup completado"
