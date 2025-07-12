#!/bin/bash
set -e

DOMAIN="uat-zentravision.zentratek.com"

# Obtener IP actual de la instancia
cd terraform/environments/uat
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")
cd ../../..

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ No se pudo obtener la IP de la instancia UAT"
    exit 1
fi

echo "🔍 Verificando configuración DNS para $DOMAIN"
echo "📍 IP esperada: $INSTANCE_IP"
echo ""

# Verificar DNS
DNS_IP=$(dig +short $DOMAIN | tail -1)

if [ -z "$DNS_IP" ]; then
    echo "❌ DNS no resuelve para $DOMAIN"
    echo ""
    echo "🛠️  Configurar en tu proveedor DNS:"
    echo "   Tipo: A"
    echo "   Nombre: uat-zentravision"
    echo "   Valor: $INSTANCE_IP"
    echo "   TTL: 300"
elif [ "$DNS_IP" = "$INSTANCE_IP" ]; then
    echo "✅ DNS configurado correctamente"
    echo "📍 $DOMAIN → $DNS_IP"
    
    # Verificar SSL
    echo ""
    echo "🔐 Verificando SSL..."
    if curl -s -I "https://$DOMAIN" | grep -q "HTTP/2 200\|HTTP/1.1 200"; then
        echo "✅ SSL funcionando correctamente"
        echo "🌐 Aplicación disponible en: https://$DOMAIN"
    else
        echo "⚠️  SSL aún no configurado (puede tardar 5-10 minutos)"
        echo "🌐 Aplicación temporal en: http://$INSTANCE_IP:8000"
    fi
else
    echo "❌ DNS apunta a IP incorrecta"
    echo "📍 DNS actual: $DOMAIN → $DNS_IP"
    echo "📍 IP esperada: $INSTANCE_IP"
    echo ""
    echo "🛠️  Actualizar DNS para que apunte a: $INSTANCE_IP"
fi