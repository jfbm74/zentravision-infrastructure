#!/bin/bash
set -e

PROJECT_ID=${1:-"zentravision"}
ENV=${2:-"uat"}

if [ "$#" -lt 2 ]; then
    echo "Uso: $0 <project_id> <environment>"
    echo "Ejemplo: $0 zentraflow uat"
    echo "Ejemplo: $0 zentraflow dev"
    echo "Ejemplo: $0 zentraflow prod"
    exit 1
fi

OPENAI_SECRET_NAME="${PROJECT_ID}-${ENV}-openai-key"

echo "🤖 Configurar OpenAI API Key para $PROJECT_ID-$ENV"
echo "=================================================="

# Verificar si ya existe
if gcloud secrets describe $OPENAI_SECRET_NAME >/dev/null 2>&1; then
    echo "⚠️  El secret $OPENAI_SECRET_NAME ya existe."
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
echo "📝 Para obtener tu OpenAI API Key:"
echo "1. Ve a https://platform.openai.com/api-keys"
echo "2. Inicia sesión en tu cuenta de OpenAI"
echo "3. Crea una nueva API Key o copia una existente"
echo "4. La API Key debe empezar con 'sk-'"
echo ""

# Solicitar API Key de forma segura
read -s -p "🔑 Ingresa tu OpenAI API Key: " OPENAI_API_KEY
echo ""

# Validaciones
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Error: OpenAI API Key no puede estar vacía"
    exit 1
fi

if [[ ! "$OPENAI_API_KEY" =~ ^sk-[A-Za-z0-9] ]]; then
    echo "⚠️  Advertencia: La API Key no tiene el formato esperado (debe empezar con 'sk-')"
    echo "¿Continuar de todas formas? (y/N)"
    read -r confirm
    if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "❌ Operación cancelada"
        exit 1
    fi
fi

# Crear o actualizar el secret
if [ "$UPDATE_MODE" = true ]; then
    echo "📝 Actualizando OpenAI API Key..."
    echo -n "$OPENAI_API_KEY" | gcloud secrets versions add $OPENAI_SECRET_NAME --data-file=-
    echo "✅ OpenAI API Key actualizada exitosamente"
else
    echo "📝 Creando OpenAI API Key..."
    echo -n "$OPENAI_API_KEY" | gcloud secrets create $OPENAI_SECRET_NAME --data-file=-
    echo "✅ OpenAI API Key creada exitosamente"
fi

# Limpiar variable por seguridad
unset OPENAI_API_KEY

echo ""
echo "🎉 Configuración completada"
echo "=========================="
echo "✅ Secret name: $OPENAI_SECRET_NAME"
echo "🔒 La API Key está guardada de forma segura en Google Secret Manager"
echo ""
echo "📝 Próximos pasos:"
echo "1. Ejecutar el despliegue: make full-deploy-$ENV"
echo "2. O continuar con el despliegue si ya estaba en progreso"