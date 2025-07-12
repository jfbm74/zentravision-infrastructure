#!/bin/bash
set -e

echo "🚀 Zentravision UAT - Despliegue Completo"
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
if [ ! -f terraform/environments/uat/terraform.tfvars ]; then
    echo "❌ terraform.tfvars no encontrado para UAT"
    exit 1
fi

echo "✅ Prerrequisitos verificados"

# Paso 1: Configurar secretos para UAT
echo ""
echo "🔐 Paso 1: Configurando secretos..."
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
cd ../../..

echo ""
echo "🎉 ¡Despliegue UAT completado!"
