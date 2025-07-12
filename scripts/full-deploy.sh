#!/bin/bash
set -e

echo "🚀 Zentravision MVP - Despliegue Completo"
echo "========================================"

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
    echo "❌ terraform.tfvars no encontrado"
    echo "Copia terraform.tfvars.example y configúralo"
    exit 1
fi

# Verificar variables de entorno requeridas
if [ -z "$DOMAIN_NAME" ]; then
    echo "⚠️  DOMAIN_NAME no configurado, usando ejemplo"
    export DOMAIN_NAME="zentravision.ejemplo.com"
fi

if [ -z "$ADMIN_EMAIL" ]; then
    echo "⚠️  ADMIN_EMAIL no configurado, usando ejemplo"
    export ADMIN_EMAIL="admin@ejemplo.com"
fi

echo "✅ Prerrequisitos verificados"

# Paso 1: Configurar secretos
echo ""
echo "🔐 Paso 1: Configurando secretos..."
./scripts/setup-secrets.sh zentraflow prod

# Paso 2: Desplegar infraestructura
echo ""
echo "🏗️  Paso 2: Desplegando infraestructura..."
cd terraform/environments/prod
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
cd ../../..

# Paso 3: Generar inventario
echo ""
echo "📋 Paso 3: Generando inventario de Ansible..."
./scripts/generate-inventory.sh

# Paso 4: Configurar aplicación
echo ""
echo "⚙️  Paso 4: Configurando aplicación..."
cd ansible
ansible-playbook -i inventories/prod playbooks/site.yml
cd ..

# Paso 5: Verificación final
echo ""
echo "🔍 Paso 5: Verificación final..."
INSTANCE_IP=$(cd terraform/environments/prod && terraform output -raw instance_ip)

echo "Esperando a que la aplicación esté lista..."
sleep 30

# Test HTTP health check
if curl -f -s "http://$INSTANCE_IP:8000/health/" > /dev/null; then
    echo "✅ HTTP health check: OK"
else
    echo "⚠️  HTTP health check: Failed (normal si SSL está configurándose)"
fi

# Mostrar información final
echo ""
echo "🎉 ¡Despliegue completado!"
echo "=========================="
echo "🌐 URL: https://$DOMAIN_NAME"
echo "🔧 Admin: https://$DOMAIN_NAME/admin/"
echo "🔗 SSH: ssh admin@$INSTANCE_IP"
echo "📊 Logs: ssh admin@$INSTANCE_IP 'tail -f /opt/zentravision/logs/zentravision.log'"
echo ""
echo "📝 Próximos pasos:"
echo "1. Configurar DNS para apuntar $DOMAIN_NAME a $INSTANCE_IP"
echo "2. Esperar a que SSL se configure automáticamente (5-10 min)"
echo "3. Probar subiendo un PDF en la aplicación"
echo "4. Cambiar la contraseña del admin por defecto"

