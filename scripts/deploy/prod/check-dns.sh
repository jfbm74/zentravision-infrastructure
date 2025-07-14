#!/bin/bash
set -e

# Obtener dominio de variable de entorno o usar por defecto
DOMAIN="${DOMAIN_NAME:-zentravision.zentratek.com}"

# Obtener IP actual de la instancia
cd terraform/environments/prod
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")
cd ../../..

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ No se pudo obtener la IP de la instancia PROD"
    exit 1
fi

echo "🌐 Verificando HTTP para $DOMAIN (PRODUCCIÓN - SSL DISABLED)"
echo "============================================================"
echo "📍 IP: $INSTANCE_IP"
echo ""

# Verificar DNS
DNS_IP=$(dig +short $DOMAIN | tail -1)
if [ "$DNS_IP" != "$INSTANCE_IP" ]; then
    echo "❌ DNS no resuelve correctamente"
    echo "   DNS: $DOMAIN → $DNS_IP"
    echo "   Esperado: $INSTANCE_IP"
    echo ""
    echo "🔴 CRÍTICO: Configurar DNS INMEDIATAMENTE"
    echo "=========================================="
    echo "Configura en tu proveedor DNS:"
    echo "   Tipo: A"
    echo "   Nombre: $(echo $DOMAIN | cut -d. -f1) (o @ si es dominio raíz)"
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

echo ""
echo "🎉 PRODUCCIÓN HTTP FUNCIONANDO"
echo "=============================="
echo "🌐 Aplicación: http://$DOMAIN"
echo "🔧 Admin panel: http://$DOMAIN/admin/"
echo "👤 Usuario: admin"
echo "🔑 ⚠️  CAMBIAR PASSWORD INMEDIATAMENTE"
echo ""
echo "⚠️  SSL/HTTPS DESHABILITADO para evitar límites de Let's Encrypt"
echo "💡 Configura SSL manualmente cuando sea necesario"

echo ""
echo "📊 Health check de PRODUCCIÓN:"
echo "=============================="
echo "HTTP: $(curl -s -o /dev/null -w '%{http_code}' http://$DOMAIN || echo 'Error')"
echo "Internal: $(curl -s -o /dev/null -w '%{http_code}' http://$INSTANCE_IP:8000/ 2>/dev/null || echo 'Error')"
