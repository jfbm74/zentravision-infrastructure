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

echo "🔐 Verificando SSL para $DOMAIN (PRODUCCIÓN)"
echo "============================================="
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
    CERT_INFO=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "No se pudo obtener info del certificado")
    echo "$CERT_INFO"
    
    # Verificar que el certificado no expire pronto
    EXPIRY_DATE=$(echo | openssl s_client -servername $DOMAIN -connect $DOMAIN:443 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ ! -z "$EXPIRY_DATE" ]; then
        EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s 2>/dev/null || echo "0")
        CURRENT_EPOCH=$(date +%s)
        DAYS_LEFT=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
        
        if [ $DAYS_LEFT -gt 30 ]; then
            echo "✅ Certificado válido por $DAYS_LEFT días más"
        elif [ $DAYS_LEFT -gt 7 ]; then
            echo "⚠️  Certificado expira en $DAYS_LEFT días"
        else
            echo "🔴 CRÍTICO: Certificado expira en $DAYS_LEFT días!"
        fi
    fi
    
    echo ""
    echo "🎉 PRODUCCIÓN SSL COMPLETAMENTE CONFIGURADO"
    echo "==========================================="
    echo "🌐 Aplicación: https://$DOMAIN"
    echo "🔧 Admin panel: https://$DOMAIN/admin/"
    echo "👤 Usuario: admin"
    echo "🔑 ⚠️  CAMBIAR PASSWORD INMEDIATAMENTE"
    echo ""
    echo "📊 Monitoreo:"
    echo "   Health check: https://$DOMAIN/health/"
    echo "   SSH: ssh admin@$INSTANCE_IP"
    echo "   Logs: ssh admin@$INSTANCE_IP 'tail -f /opt/zentravision/logs/zentravision.log'"
    echo ""
    echo "🗄️  Backups automáticos configurados en:"
    echo "   gs://zentraflow-prod-backups/"
    echo ""
    echo "🔒 Próximos pasos de seguridad:"
    echo "1. 🔑 Cambiar password del admin"
    echo "2. 📧 Configurar notificaciones"
    echo "3. 🗄️  Verificar backups"
    echo "4. 📊 Configurar monitoreo adicional"
    
else
    echo "⚠️  HTTPS aún no disponible"
    
    # Verificar si certbot está instalado y funcionando
    echo ""
    echo "🔍 Diagnosticando SSL..."
    
    # Conectar por SSH y verificar estado de SSL
    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no admin@$INSTANCE_IP << EOFREMOTE
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
        sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email ${ADMIN_EMAIL:-consultoria@zentratek.com}
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
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email ${ADMIN_EMAIL:-consultoria@zentratek.com}
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
        echo "   ssh admin@$INSTANCE_IP"
        echo "   sudo certbot certificates"
        echo "   sudo nginx -t"
        echo "   sudo systemctl status nginx"
    fi
fi

# Verificar health check interno
echo ""
echo "🏥 Verificando health check interno..."
if curl -s -f "http://$INSTANCE_IP:8000/" > /dev/null 2>&1; then
    echo "✅ Aplicación funcionando internamente"
else
    echo "❌ Problema con la aplicación interna"
    echo "🔍 Revisar logs: ssh admin@$INSTANCE_IP 'tail -f /opt/zentravision/logs/zentravision.log'"
fi

echo ""
echo "📊 Health check completo de PRODUCCIÓN:"
echo "======================================="
echo "HTTP: $(curl -s -o /dev/null -w '%{http_code}' http://$DOMAIN || echo 'Error')"
echo "HTTPS: $(curl -s -o /dev/null -w '%{http_code}' https://$DOMAIN 2>/dev/null || echo 'Error')"
echo "Internal: $(curl -s -o /dev/null -w '%{http_code}' http://$INSTANCE_IP:8000/ 2>/dev/null || echo 'Error')"