#!/bin/bash
set -e

DOMAIN="dev-zentravision.zentratek.com"

# Obtener IP actual de la instancia
cd terraform/environments/dev
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")
cd ../../..

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ No se pudo obtener la IP de la instancia DEV"
    exit 1
fi

echo "🌐 Verificando HTTP para $DOMAIN (DEV - SSL DISABLED)"
echo "===================================================="
echo "📍 IP: $INSTANCE_IP"
echo ""

# Verificar DNS
DNS_IP=$(dig +short $DOMAIN | tail -1)
if [ "$DNS_IP" != "$INSTANCE_IP" ]; then
    echo "❌ DNS no resuelve correctamente"
    echo "   DNS: $DOMAIN → $DNS_IP"
    echo "   Esperado: $INSTANCE_IP"
    echo ""
    echo "🛠️  ACCIÓN REQUERIDA: Configurar DNS"
    echo "====================================="
    echo "Configura en tu proveedor DNS:"
    echo "   Tipo: A"
    echo "   Nombre: dev-zentravision"
    echo "   Valor: $INSTANCE_IP"
    echo "   TTL: 300"
    exit 1
fi
echo "✅ DNS: $DOMAIN → $DNS_IP"

# Verificar HTTP
echo ""
echo "🌐 Verificando HTTP..."
if curl -s -I "http://$DOMAIN" | grep -q "HTTP/1.1 200\|HTTP/1.1 302"; then
    echo "✅ HTTP funcionando correctamente"
else
    echo "❌ HTTP no responde"
    echo "🔍 Debugging HTTP:"
    curl -I "http://$DOMAIN" || echo "Error de conexión HTTP"
    exit 1
fi

# Verificar aplicación directamente
echo ""
echo "🏥 Verificando aplicación..."
if curl -s -f "http://$INSTANCE_IP:8000/" > /dev/null 2>&1; then
    echo "✅ Aplicación funcionando en puerto 8000"
else
    echo "⚠️  Aplicación no responde en puerto 8000"
fi

echo ""
echo "🎉 Verificación completada (HTTP Only)"
echo "======================================"
echo "🌐 URL Principal: http://$DOMAIN"
echo "🔧 Admin Panel: http://$DOMAIN/admin/"
echo "📍 IP directa: http://$INSTANCE_IP:8000/"
echo "👤 Usuario: admin"
echo "🔑 Password: DevPassword123!"
echo ""
echo "⚠️  SSL/HTTPS DESHABILITADO para evitar límites de Let's Encrypt"
echo "💡 Puedes configurar SSL manualmente más tarde si es necesario"

echo ""
echo "📊 Health check:"
echo "================"
echo "HTTP: $(curl -s -o /dev/null -w '%{http_code}' http://$DOMAIN || echo 'Error')"
echo "Direct: $(curl -s -o /dev/null -w '%{http_code}' http://$INSTANCE_IP:8000/ 2>/dev/null || echo 'Error')"
