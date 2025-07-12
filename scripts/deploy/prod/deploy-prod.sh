#!/bin/bash
set -e

echo "🚀 Zentravision PRODUCCIÓN - Despliegue Completo con IP Dinámica"
echo "==============================================================="

# Verificar prerrequisitos
echo "🔍 Verificando prerrequisitos..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform no está instalado"
    exit 1
fi

if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Ansible no está instalado"
    exit 1
fi

if ! command -v gcloud &> /dev/null; then
    echo "❌ Google Cloud CLI no está instalado"
    exit 1
fi

# Verificar archivos de configuración
if [ ! -f terraform/environments/prod/terraform.tfvars ]; then
    echo "❌ terraform.tfvars no encontrado para PROD"
    echo "Copia terraform.tfvars.example y configúralo"
    exit 1
fi

# Verificar variables de entorno requeridas para PROD
if [ -z "$DOMAIN_NAME" ]; then
    echo "❌ DOMAIN_NAME es REQUERIDO para producción"
    echo "Configura: export DOMAIN_NAME='tu-dominio.com'"
    exit 1
fi

if [ -z "$ADMIN_EMAIL" ]; then
    echo "⚠️  ADMIN_EMAIL no configurado, usando por defecto"
    export ADMIN_EMAIL="consultoria@zentratek.com"
fi

if [ -z "$DJANGO_ADMIN_PASSWORD" ]; then
    echo "❌ DJANGO_ADMIN_PASSWORD es REQUERIDO para producción"
    echo "Configura: export DJANGO_ADMIN_PASSWORD='TuPasswordSeguro123!'"
    exit 1
fi

echo "✅ Prerrequisitos verificados"
echo "🌐 Dominio configurado: $DOMAIN_NAME"
echo "📧 Email admin: $ADMIN_EMAIL"

# Confirmación adicional para producción
echo ""
echo "⚠️  ADVERTENCIA: Vas a desplegar en PRODUCCIÓN"
echo "==============================================="
echo "Dominio: $DOMAIN_NAME"
echo "Email: $ADMIN_EMAIL"
echo ""
echo "¿Estás seguro de continuar? (escribir 'SI' para confirmar)"
read -r confirmation
if [ "$confirmation" != "SI" ]; then
    echo "❌ Despliegue cancelado"
    exit 1
fi

# Paso 1: Configurar secretos para PROD
echo ""
echo "🔐 Paso 1: Configurando secretos..."

# Solicitar OpenAI API Key si no está configurada
if ! gcloud secrets describe zentraflow-prod-openai-key >/dev/null 2>&1; then
    echo ""
    echo "🤖 Configuración de OpenAI API Key"
    echo "=================================="
    echo "El secret de OpenAI API Key no existe. Por favor, proporciona tu API Key:"
    echo ""
    read -s -p "🔑 OpenAI API Key: " OPENAI_API_KEY
    echo ""
    
    if [ -z "$OPENAI_API_KEY" ]; then
        echo "❌ OpenAI API Key es requerida para el funcionamiento de la aplicación"
        exit 1
    fi
    
    # Validar formato básico para PROD
    if [[ ! "$OPENAI_API_KEY" =~ ^sk-[A-Za-z0-9] ]]; then
        echo "❌ Error: La API Key no tiene el formato esperado (debe empezar con 'sk-')"
        exit 1
    fi
    
    echo "📝 Creando secret de OpenAI API Key..."
    echo -n "$OPENAI_API_KEY" | gcloud secrets create zentraflow-prod-openai-key --data-file=-
    echo "✅ Secret de OpenAI API Key creado exitosamente"
    
    # Limpiar variable por seguridad
    unset OPENAI_API_KEY
else
    echo "✅ Secret de OpenAI API Key ya existe"
fi

# Configurar otros secretos
./scripts/setup-secrets.sh zentraflow prod

# Paso 2: Desplegar infraestructura
echo ""
echo "🏗️  Paso 2: Desplegando infraestructura..."
cd terraform/environments/prod
terraform init
echo ""
echo "🔍 Revisando plan de Terraform..."
terraform plan
echo ""
echo "¿Continuar con terraform apply para PRODUCCIÓN? (escribir 'APLICAR' para confirmar)"
read -r apply_confirmation
if [ "$apply_confirmation" != "APLICAR" ]; then
    echo "❌ Despliegue cancelado"
    exit 1
fi
terraform apply

# Obtener la IP dinámica
INSTANCE_IP=$(terraform output -raw instance_ip)
echo "📍 IP obtenida: $INSTANCE_IP"
cd ../../..

# Paso 3: Generar inventario dinámico
echo ""
echo "📋 Paso 3: Generando inventario dinámico de Ansible..."
./scripts/deploy/prod/generate-inventory-prod.sh

# Paso 4: Esperar a que la instancia esté lista
echo ""
echo "⏳ Paso 4: Esperando a que la instancia esté lista (120s para PROD)..."
sleep 120

# Verificar conectividad SSH
echo "🔗 Verificando conectividad SSH..."
ssh-keyscan -H $INSTANCE_IP >> ~/.ssh/known_hosts 2>/dev/null || true

# Paso 5: Configurar aplicación
echo ""
echo "⚙️  Paso 5: Configurando aplicación..."
cd ansible
ansible-playbook -i inventories/prod playbooks/site.yml
cd ..

# Paso 6: Verificación final
echo ""
echo "🔍 Paso 6: Verificación final..."

echo "Esperando a que la aplicación esté lista..."
sleep 30

# Test HTTP health check (local)
if curl -f -s "http://localhost:8000/" > /dev/null 2>&1; then
    echo "✅ HTTP local: OK"
else
    echo "⚠️  HTTP local: Failed"
fi

# Test HTTP via IP
if curl -f -s "http://$INSTANCE_IP/" > /dev/null 2>&1; then
    echo "✅ HTTP via IP: OK"
else
    echo "⚠️  HTTP via IP: Failed"
fi

# Test HTTPS if SSL is configured
if curl -f -s "https://$DOMAIN_NAME/" > /dev/null 2>&1; then
    echo "✅ HTTPS: OK"
    SSL_READY=true
else
    echo "⚠️  HTTPS: Not ready yet (puede tardar unos minutos)"
    SSL_READY=false
fi

# Mostrar información final
echo ""
echo "🎉 ¡Despliegue de PRODUCCIÓN completado!"
echo "========================================"

if [ "$SSL_READY" = true ]; then
    echo "🌐 URL Principal: https://$DOMAIN_NAME"
    echo "🔧 Admin Panel: https://$DOMAIN_NAME/admin/"
else
    echo "🌐 URL Temporal: http://$DOMAIN_NAME"
    echo "🔧 Admin Panel: http://$DOMAIN_NAME/admin/"
    echo "🔐 HTTPS estará disponible en 5-10 minutos"
fi

echo "📍 IP de la instancia: $INSTANCE_IP"
echo "🔗 SSH: ssh admin@$INSTANCE_IP"
echo "📊 Logs: ssh admin@$INSTANCE_IP 'tail -f /opt/zentravision/logs/zentravision.log'"
echo ""
echo "⚠️  CRÍTICO: Configurar DNS INMEDIATAMENTE"
echo "============================================"
echo "Configura en tu proveedor de DNS:"
echo "- Tipo: A"
echo "- Nombre: $(echo $DOMAIN_NAME | cut -d. -f1) (o @ si es dominio raíz)"
echo "- Valor: $INSTANCE_IP"
echo "- TTL: 300 (5 minutos)"
echo ""
echo "📝 Próximos pasos CRÍTICOS:"
echo "1. 🔴 Configurar DNS para $DOMAIN_NAME → $INSTANCE_IP"
echo "2. ⏳ Esperar 5-10 minutos para propagación DNS"
echo "3. 🔐 Esperar 5-10 minutos para configuración SSL automática"
echo "4. 🔑 CAMBIAR contraseña del admin por defecto"
echo "5. 📧 Configurar notificaciones de monitoreo"
echo "6. 🗄️  Verificar que los backups funcionen"
echo ""
echo "🔒 SEGURIDAD:"
echo "- Usuario admin: admin"
echo "- Password: $DJANGO_ADMIN_PASSWORD"
echo "- ⚠️  CAMBIAR PASSWORD INMEDIATAMENTE después del primer login"

# Guardar información crítica
cat > .last-prod-deployment << EOF
DEPLOYMENT_DATE=$(date)
INSTANCE_IP=$INSTANCE_IP
DOMAIN_NAME=$DOMAIN_NAME
ADMIN_EMAIL=$ADMIN_EMAIL
SSH_COMMAND=ssh admin@$INSTANCE_IP
ADMIN_URL=https://$DOMAIN_NAME/admin/
EOF

echo ""
echo "💾 Información del despliegue guardada en .last-prod-deployment"