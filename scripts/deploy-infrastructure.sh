#!/bin/bash
set -e

echo "🚀 Deploying Infrastructure..."

# Verificar variables requeridas
if [ ! -f terraform/environments/prod/terraform.tfvars ]; then
    echo "❌ Error: terraform.tfvars no encontrado"
    echo "Copia terraform.tfvars.example y configúralo"
    exit 1
fi

# Deploy
cd terraform/environments/prod
terraform init
terraform plan
echo "Presiona Enter para continuar con apply..."
read
terraform apply

# Mostrar outputs
echo ""
echo "🎉 Infrastructure deployed successfully!"
echo ""
terraform output
