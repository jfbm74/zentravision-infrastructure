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

echo "🔐 Verificando SSL para $DOMAIN (DEV)"
echo "====================================="
echo "📍 IP: $INSTANCE_IP"
echo ""

# Verificar DNS
DNS_IP=$(dig +short $DOMAIN | tail -1)
if [ "$DNS_IP" != "$INSTANCE_IP" ]; then
    echo "❌ DNS no resuelve correctamente"
    echo "   DNS: $DOMAIN → $DNS_IP"
    echo "   Esperado: $INSTANCE_IP"
    exit 1
fi
echo "✅ DNS: $DOMAIN → $DNS_IP"

# Verificar HTTP
echo ""
echo "🌐 Verificando HTTP..."
if curl -s -I "http://$DOMAIN" | grep -q "HTTP/1.1 200\|HTTP/1.1 302"; then
    echo "✅ HTTP funcionando"
else
    echo "❌ HTTP no responde"
    echo "🔍 Debugging HTTP:"
    curl -I "http://$DOMAIN" || echo "Error de conexión HTTP"
    exit 1
fi

# Verificar HTTPS
echo ""
echo "🔐 Verificando HTTPS..."
if curl -s -I "https://$DOMAIN" 2>/dev/null | grep -q "HTTP"; then
    echo "✅ HTTPS funcionando correctamente"
    
    # Verificar certificado
    echo ""
    echo "📋 Información del certificado:"
    echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "No se pudo obtener info del certificado"
    
    echo ""
    echo "🎉 SSL completamente configurado"
    echo "================================"
    echo "🌐 Aplicación: https://$DOMAIN"
    echo "🔧 Admin: https://$DOMAIN/admin/"
    echo "👤 Usuario: admin"
    echo "🔑 Password: DevPassword123!"
    
else
    echo "⚠️  HTTPS aún no disponible"
    
    # Verificar si certbot está instalado y funcionando
    echo ""
    echo "🔍 Diagnosticando SSL..."
    
    # Conectar por SSH y verificar estado de SSL
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no zentravision@$INSTANCE_IP << 'EOFREMOTE'
echo "🔍 Estado de certbot en el servidor:"

# Verificar si certbot está instalado
if command -v certbot &> /dev/null; then
    echo "✅ Certbot instalado"
    
    # Verificar certificados existentes
    if sudo ls /etc/letsencrypt/live/ 2>/dev/null | grep -q zentravision; then
        echo "✅ Certificados encontrados:"
        sudo ls -la /etc/letsencrypt/live/
    else
        echo "⚠️  No hay certificados configurados"
        echo ""
        echo "🔧 Configurando SSL manualmente..."
        sudo certbot --nginx -d dev-zentravision.zentratek.com --non-interactive --agree-tos --email consultoria@zentratek.com
    fi
    
    # Verificar configuración de nginx
    echo ""
    echo "📋 Configuración actual de Nginx:"
    sudo nginx -t && echo "✅ Configuración válida" || echo "❌ Error en configuración"
    
else
    echo "❌ Certbot no está instalado"
    echo "🔧 Instalando certbot..."
    sudo apt update
    sudo apt install certbot python3-certbot-nginx -y
    sudo certbot --nginx -d dev-zentravision.zentratek.com --non-interactive --agree-tos --email consultoria@zentratek.com
fi

echo ""
echo "🔄 Reiniciando nginx..."
sudo systemctl restart nginx
EOFREMOTE

    echo ""
    echo "⏳ Esperando 30 segundos y verificando de nuevo..."
    sleep 30
    
    if curl -s -I "https://$DOMAIN" 2>/dev/null | grep -q "HTTP"; then
        echo "✅ HTTPS ahora funcionando!"
    else
        echo "⚠️  HTTPS aún no disponible. Puede tardar unos minutos más."
        echo ""
        echo "💡 Comandos para verificar manualmente:"
        echo "   ssh zentravision@$INSTANCE_IP"
        echo "   sudo certbot certificates"
        echo "   sudo nginx -t"
        echo "   sudo systemctl status nginx"
    fi
fi

echo ""
echo "📊 Health check completo:"
echo "========================"
echo "HTTP: $(curl -s -o /dev/null -w '%{http_code}' http://$DOMAIN || echo 'Error')"
echo "HTTPS: $(curl -s -o /dev/null -w '%{http_code}' https://$DOMAIN 2>/dev/null || echo 'Error')"