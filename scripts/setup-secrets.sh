#!/bin/bash
set -e

PROJECT_ID=${1:-"zentraflow"}
ENV=${2:-"prod"}

echo "🔐 Configurando secretos para $PROJECT_ID-$ENV"

# Generar Django secret key si no existe
DJANGO_SECRET=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
echo -n "$DJANGO_SECRET" | gcloud secrets create ${PROJECT_ID}-${ENV}-django-secret --data-file=- || echo "Secret django-secret ya existe"

# Generar database password
DB_PASSWORD=$(python3 -c "import secrets; print(secrets.token_urlsafe(16))")
echo -n "$DB_PASSWORD" | gcloud secrets create ${PROJECT_ID}-${ENV}-db-password --data-file=- || echo "Secret db-password ya existe"

# OpenAI API Key (debe ser proporcionada)
echo "⚠️  IMPORTANTE: Crear manualmente el secret para OpenAI API Key:"
echo "echo -n 'YOUR_OPENAI_API_KEY' | gcloud secrets create ${PROJECT_ID}-${ENV}-openai-key --data-file=-"

echo "✅ Secretos configurados"
