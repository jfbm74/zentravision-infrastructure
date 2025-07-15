#!/bin/bash
# ============================================================================
# ARCHIVO: scripts/configure-grafana-token.sh
# Script para configurar Grafana API Token en Google Secret Manager
# ============================================================================

set -e

PROJECT_ID=${1:-"zentraflow"}
ENV=${2:-"dev"}

if [ "$#" -lt 2 ]; then
    echo "Uso: $0 <project_id> <environment>"
    echo "Ejemplo: $0 zentraflow dev"
    echo "Ejemplo: $0 zentraflow uat"
    echo "Ejemplo: $0 zentraflow prod"
    exit 1
fi

GRAFANA_SECRET_NAME="${PROJECT_ID}-${ENV}-grafana-token"

echo "📊 Configurar Grafana API Token para $PROJECT_ID-$ENV"
echo "===================================================="

# Verificar si ya existe
if gcloud secrets describe $GRAFANA_SECRET_NAME >/dev/null 2>&1; then
    echo "⚠️  El secret $GRAFANA_SECRET_NAME ya existe."
    echo "¿Quieres actualizarlo? (y/N)"
    read -r confirm
    if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "❌ Operación cancelada"
        exit 0
    fi
    UPDATE_MODE=true
else
    UPDATE_MODE=false
fi

echo ""
echo "📝 Para obtener tu Grafana API Token:"
echo "1. Ve a https://zentratek.grafana.net/org/apikeys"
echo "2. Inicia sesión en tu cuenta de Grafana Cloud"
echo "3. Crea una nueva API Key con permisos de 'MetricsPublisher'"
echo "4. La API Key debe empezar con 'glc_'"
echo ""

# Solicitar API Token de forma segura
read -s -p "🔑 Ingresa tu Grafana API Token: " GRAFANA_API_TOKEN
echo ""

# Validaciones
if [ -z "$GRAFANA_API_TOKEN" ]; then
    echo "❌ Error: Grafana API Token no puede estar vacío"
    exit 1
fi

if [[ ! "$GRAFANA_API_TOKEN" =~ ^glc_[A-Za-z0-9] ]]; then
    echo "⚠️  Advertencia: La API Token no tiene el formato esperado (debe empezar con 'glc_')"
    echo "¿Continuar de todas formas? (y/N)"
    read -r confirm
    if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "❌ Operación cancelada"
        exit 1
    fi
fi

# Crear o actualizar el secret
if [ "$UPDATE_MODE" = true ]; then
    echo "📝 Actualizando Grafana API Token..."
    echo -n "$GRAFANA_API_TOKEN" | gcloud secrets versions add $GRAFANA_SECRET_NAME --data-file=-
    echo "✅ Grafana API Token actualizado exitosamente"
else
    echo "📝 Creando Grafana API Token..."
    echo -n "$GRAFANA_API_TOKEN" | gcloud secrets create $GRAFANA_SECRET_NAME --data-file=-
    echo "✅ Grafana API Token creado exitosamente"
fi

# Limpiar variable por seguridad
unset GRAFANA_API_TOKEN

echo ""
echo "🎉 Configuración completada"
echo "=========================="
echo "✅ Secret name: $GRAFANA_SECRET_NAME"
echo "🔒 La API Token está guardada de forma segura en Google Secret Manager"
echo ""
echo "📝 Próximos pasos:"
echo "1. El despliegue automáticamente usará este secret"
echo "2. Ejecutar: make deploy-monitoring-$ENV"
echo "3. O continuar con el despliegue si ya estaba en progreso"