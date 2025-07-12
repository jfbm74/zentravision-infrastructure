#!/bin/bash
set -e

echo "🔧 Fixing Reserved Variable Issue in Zentravision DEV"
echo "===================================================="

# Check if we're in the right directory
if [ ! -f "ansible/roles/django-monolith/templates/env.j2" ]; then
    echo "❌ Error: Must be run from zentravision-infrastructure root directory"
    exit 1
fi

echo "📍 Current directory: $(pwd)"

# Create backups with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
echo "📄 Creating backups..."

cp ansible/inventories/dev/hosts.yml ansible/inventories/dev/hosts.yml.backup.$TIMESTAMP
cp ansible/roles/django-monolith/templates/env.j2 ansible/roles/django-monolith/templates/env.j2.backup.$TIMESTAMP

# Fix the sed commands for macOS
echo "🔄 Updating inventory files..."

# For macOS, we need different sed syntax
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' 's/environment: /app_environment: /g' ansible/inventories/dev/hosts.yml
    sed -i '' 's/environment: /app_environment: /g' ansible/inventories/uat/hosts.yml
    if [ -f ansible/inventories/prod/hosts.yml ]; then
        sed -i '' 's/environment: /app_environment: /g' ansible/inventories/prod/hosts.yml
    fi
else
    # Linux
    sed -i 's/environment: /app_environment: /g' ansible/inventories/dev/hosts.yml
    sed -i 's/environment: /app_environment: /g' ansible/inventories/uat/hosts.yml
    if [ -f ansible/inventories/prod/hosts.yml ]; then
        sed -i 's/environment: /app_environment: /g' ansible/inventories/prod/hosts.yml
    fi
fi

# Update the .env template to use app_environment
echo "🔄 Updating .env template..."
cat > ansible/roles/django-monolith/templates/env.j2 << 'TEMPLATE_EOF'
# Environment: {{ app_environment }}
DEBUG={{ debug_mode | default('False') }}
ENVIRONMENT={{ app_environment }}
DOMAIN_NAME={{ domain_name }}

# Database configuration
DATABASE_URL=postgresql://{{ app_user | default('zentravision') }}:{{ vault_db_password | default('ZentravisionUAT2024!') }}@localhost:5432/{{ app_name | default('zentravision') }}
REDIS_URL=redis://localhost:6379/0

# Django settings
ALLOWED_HOSTS={{ domain_name }},{{ ansible_host }},localhost,127.0.0.1
SECRET_KEY=change-me-in-production

# GCP Project for secrets
GCP_PROJECT_ID={{ gcp_project_id }}

# Secret names (will be fetched from GCP Secret Manager)
DJANGO_SECRET_KEY_SECRET=projects/{{ gcp_project_id }}/secrets/{{ gcp_project_id }}-{{ app_environment }}-django-secret/versions/latest
DATABASE_PASSWORD_SECRET=projects/{{ gcp_project_id }}/secrets/{{ gcp_project_id }}-{{ app_environment }}-db-password/versions/latest
OPENAI_API_KEY_SECRET=projects/{{ gcp_project_id }}/secrets/{{ gcp_project_id }}-{{ app_environment }}-openai-key/versions/latest

# Static and media settings
STATIC_URL=/static/
MEDIA_URL=/media/
STATIC_ROOT={{ app_home | default('/opt/zentravision') }}/static/
MEDIA_ROOT={{ app_home | default('/opt/zentravision') }}/media/
TEMPLATE_EOF

echo "✅ Templates updated successfully"

# Check if the changes were applied correctly
echo "🔍 Verifying changes..."
echo "DEV inventory environment variable:"
grep "app_environment:" ansible/inventories/dev/hosts.yml || echo "Not found in DEV"

echo "UAT inventory environment variable:"
grep "app_environment:" ansible/inventories/uat/hosts.yml || echo "Not found in UAT"

echo ""
echo "✅ Fix completed successfully!"
echo "=============================="
echo ""
echo "📝 Next steps:"
echo "1. Run: make deploy-dev"
echo "2. Watch for the absence of '[WARNING]: Found variable using reserved name: environment'"
echo "3. Verify the .env file after deployment:"
echo "   ssh zentravision@34.45.112.122 'cat /opt/zentravision/.env | grep ENVIRONMENT'"
