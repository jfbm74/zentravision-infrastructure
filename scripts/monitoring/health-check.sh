#!/bin/bash

INSTANCE_IP=$(cd terraform/environments/prod && terraform output -raw instance_ip 2>/dev/null || echo "")

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ No se pudo obtener la IP de la instancia"
    exit 1
fi

echo "🏥 Health Check - Zentravision MVP"
echo "=================================="
echo "Instance: $INSTANCE_IP"
echo "Time: $(date)"
echo ""

# SSH health check script remoto
ssh admin@$INSTANCE_IP 'bash -s' << 'REMOTE_SCRIPT'
echo "=== Servicios ==="
for service in zentravision zentravision-celery nginx postgresql redis; do
    if systemctl is-active --quiet $service; then
        echo "✅ $service: Activo"
    else
        echo "❌ $service: Inactivo"
    fi
done

echo ""
echo "=== Recursos ==="
echo "Disco: $(df -h / | tail -1 | awk '{print $5}') usado"
echo "RAM: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% usado"

echo ""
echo "=== Aplicación ==="
if curl -s -f http://localhost:8000/health/ > /dev/null; then
    echo "✅ HTTP: Healthy"
else
    echo "❌ HTTP: Unhealthy"
fi

echo ""
echo "=== Logs recientes ==="
echo "Últimos errores:"
tail -5 /opt/zentravision/logs/zentravision.log | grep -i error || echo "Sin errores recientes"
REMOTE_SCRIPT

echo ""
echo "✅ Health check completado"
