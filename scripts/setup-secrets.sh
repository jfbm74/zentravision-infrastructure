#!/bin/bash
set -e

PROJECT_ID=${1:-"zentraflow"}
ENV=${2:-"prod"}

echo "🔐 Configurando secretos para $PROJECT_ID-$ENV"

# Generar Django secret key si no existe
SECRET_NAME="${PROJECT_ID}-${ENV}-django-secret"
if ! gcloud secrets describe $SECRET_NAME >/dev/null 2>&1; then
    echo "📝 Generando Django secret key..."
    DJANGO_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    echo -n "$DJANGO_SECRET" | gcloud secrets create $SECRET_NAME --data-file=-
    echo "✅ Django secret key creado"
else
    echo "✅ Django secret key ya existe"
fi

# Generar database password si no existe
DB_SECRET_NAME="${PROJECT_ID}-${ENV}-db-password"
if ! gcloud secrets describe $DB_SECRET_NAME >/dev/null 2>&1; then
    echo "📝 Generando contraseña de base de datos..."
    DB_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))")
    echo -n "$DB_PASSWORD" | gcloud secrets create $DB_SECRET_NAME --data-file=-
    echo "✅ Contraseña de base de datos creada"
else
    echo "✅ Contraseña de base de datos ya existe"
fi

# OpenAI API Key - solicitar interactivamente si no existe
OPENAI_SECRET_NAME="${PROJECT_ID}-${ENV}-openai-key"
if ! gcloud secrets describe $OPENAI_SECRET_NAME >/dev/null 2>&1; then
    echo ""
    echo "🤖 OpenAI API Key requerida"
    echo "=========================="
    echo "Para que Zentravision funcione correctamente, necesitas proporcionar tu OpenAI API Key."
    echo "Puedes obtenerla en: https://platform.openai.com/api-keys"
    echo ""
    
    # Solicitar API Key de forma segura (sin mostrar en pantalla)
    read -s -p "🔑 Ingresa tu OpenAI API Key: " OPENAI_API_KEY
    echo ""
    
    # Validar que no esté vacía
    if [ -z "$OPENAI_API_KEY" ]; then
        echo "❌ Error: OpenAI API Key no puede estar vacía"
        echo "💡 Tip: Obten tu API Key en https://platform.openai.com/api-keys"
        exit 1
    fi
    
    # Validar formato básico (debe empezar con sk-)
    if [[ ! "$OPENAI_API_KEY" =~ ^sk-[A-Za-z0-9] ]]; then
        echo "⚠️  Advertencia: La API Key no tiene el formato esperado (debe empezar con 'sk-')"
        echo "¿Continuar de todas formas? (y/N)"
        read -r confirm
        if [[ ! "$confirm" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            echo "❌ Configuración cancelada"
            exit 1
        fi
    fi
    
    # Crear el secret
    echo "📝 Guardando OpenAI API Key en Google Secret Manager..."
    echo -n "$OPENAI_API_KEY" | gcloud secrets create $OPENAI_SECRET_NAME --data-file=-
    echo "✅ OpenAI API Key configurada exitosamente"
    
    # Limpiar variable por seguridad
    unset OPENAI_API_KEY
else
    echo "✅ OpenAI API Key ya existe"
fi

echo ""
echo "🎉 Configuración de secretos completada"
echo "========================================"
echo "✅ Django secret: $SECRET_NAME"
echo "✅ DB password: $DB_SECRET_NAME" 
echo "✅ OpenAI API Key: $OPENAI_SECRET_NAME"
echo ""
echo "🔒 Todos los secretos están guardados de forma segura en Google Secret Manager"