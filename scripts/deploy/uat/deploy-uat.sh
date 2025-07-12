#!/bin/bash
set -e

echo "🚀 Zentravision UAT - Despliegue Completo con IP Dinámica"
echo "========================================================="

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
if [ ! -f terraform/environments/uat/terraform.tfvars ]; then
    echo "❌ terraform.tfvars no encontrado para UAT"
    echo "Copia terraform.tfvars.example y configúralo"
    exit 1
fi

echo "✅ Prerrequisitos verificados"

# Paso 1: Configurar secretos para UAT
echo ""
echo "🔐 Paso 1: Configurando secretos..."

# Solicitar OpenAI API Key si no está configurada
if ! gcloud secrets describe zentraflow-uat-openai-key >/dev/null 2>&1; then
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
    
    echo "📝 Creando secret de OpenAI API Key..."
    echo -n "$OPENAI_API_KEY" | gcloud secrets create zentraflow-uat-openai-key --data-file=-
    echo "✅ Secret de OpenAI API Key creado exitosamente"
else
    echo "✅ Secret de OpenAI API Key ya existe"
fi

# Configurar otros secretos
./scripts/setup-secrets.sh zentraflow uat

# Paso 2: Desplegar infraestructura
echo ""
echo "🏗️  Paso 2: Desplegando infraestructura..."
cd terraform/environments/uat
terraform init
terraform plan
echo "¿Continuar con terraform apply? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    terraform apply
else
    echo "❌ Despliegue cancelado"
    exit 1
fi

# Obtener la IP dinámica
INSTANCE_IP=$(terraform output -raw instance_ip)
echo "📍 IP obtenida: $INSTANCE_IP"
cd ../../..

# Paso 3: Generar inventario dinámico
echo ""
echo "📋 Paso 3: Generando inventario dinámico de Ansible..."
./scripts/deploy/uat/generate-inventory-uat.sh

# Paso 4: Esperar a que la instancia esté lista
echo ""
echo "⏳ Paso 4: Esperando a que la instancia esté lista (120s)..."
sleep 120

# Verificar conectividad SSH
echo "🔗 Verificando conectividad SSH..."
ssh-keyscan -H $INSTANCE_IP >> ~/.ssh/known_hosts 2>/dev/null || true

# Paso 5: Configurar aplicación
echo ""
echo "⚙️  Paso 5: Configurando aplicación..."
cd ansible
ansible-playbook -i inventories/uat playbooks/site.yml
cd ..

# Paso 6: Verificación final
echo ""
echo "🔍 Paso 6: Verificación final..."

echo "Esperando a que la aplicación esté lista..."
sleep 30

# Test HTTP health check (local)
if curl -f -s "http://localhost:8000/" > /dev/null; then
    echo "✅ HTTP local: OK"
else
    echo "⚠️  HTTP local: Failed"
fi

# Test HTTP via domain
if curl -f -s "http://$INSTANCE_IP/" > /dev/null; then
    echo "✅ HTTP via IP: OK"
else
    echo "⚠️  HTTP via IP: Failed"
fi

# Test HTTPS if SSL is configured
if curl -f -s "https://uat-zentravision.zentratek.com/" > /dev/null; then
    echo "✅ HTTPS: OK"
    SSL_READY=true
else
    echo "⚠️  HTTPS: Not ready yet (puede tardar unos minutos)"
    SSL_READY=false
fi

# Mostrar información final
echo ""
echo "🎉 ¡Despliegue UAT completado!"
echo "=============================="

if [ "$SSL_READY" = true ]; then
    echo "🌐 URL Principal: https://uat-zentravision.zentratek.com"
    echo "🔧 Admin Panel: https://uat-zentravision.zentratek.com/admin/"
else
    echo "🌐 URL Temporal: http://uat-zentravision.zentratek.com"
    echo "🔧 Admin Panel: http://uat-zentravision.zentratek.com/admin/"
    echo "🔐 HTTPS estará disponible en 5-10 minutos"
fi

echo "📍 IP de la instancia: $INSTANCE_IP"
echo "🔗 SSH: ssh zentravision@$INSTANCE_IP"
echo "📊 Logs: ssh zentravision@$INSTANCE_IP 'tail -f /opt/zentravision/logs/zentravision.log'"
echo ""
echo "⚠️  IMPORTANTE: DNS ya configurado"
echo "================================="
echo "✅ DNS: uat-zentravision.zentratek.com → $INSTANCE_IP"
echo ""
echo "📝 Próximos pasos:"
echo "1. ✅ DNS ya configurado"
echo "2. ⏳ Esperar 5-10 minutos para configuración SSL automática"
echo "3. 🌐 Acceder a https://uat-zentravision.zentratek.com"
echo "4. 🔑 Login: admin / UatPassword123!"

# Guardar IP para referencia futura
echo "$INSTANCE_IP" > .last-uat-ip
echo ""
echo "💾 IP guardada en .last-uat-ip para referencia"