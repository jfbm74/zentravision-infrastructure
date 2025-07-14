#!/bin/bash
set -e

echo "🔧 Deshabilitando Certbot en Zentravision Infrastructure"
echo "========================================================"

# Check if we're in the right directory
if [ ! -f "ansible/roles/django-monolith/tasks/main.yml" ]; then
    echo "❌ Error: Must be run from zentravision-infrastructure root directory"
    exit 1
fi

echo "📍 Current directory: $(pwd)"

# Create backups with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
echo "📄 Creating backups..."

# Backup main.yml
cp ansible/roles/django-monolith/tasks/main.yml ansible/roles/django-monolith/tasks/main.yml.backup.$TIMESTAMP

# Backup nginx template
cp ansible/roles/django-monolith/templates/nginx.conf.j2 ansible/roles/django-monolith/templates/nginx.conf.j2.backup.$TIMESTAMP

# Backup inventory files
cp ansible/inventories/dev/hosts.yml ansible/inventories/dev/hosts.yml.backup.$TIMESTAMP
cp ansible/inventories/uat/hosts.yml ansible/inventories/uat/hosts.yml.backup.$TIMESTAMP

echo "✅ Backups created with timestamp: $TIMESTAMP"

# Update inventory files to disable SSL
echo "🔄 Updating inventory files to disable SSL..."

# Update DEV inventory
sed -i.bak 's/ssl_enabled: true/ssl_enabled: false/g' ansible/inventories/dev/hosts.yml

# Update UAT inventory  
sed -i.bak 's/ssl_enabled: true/ssl_enabled: false/g' ansible/inventories/uat/hosts.yml

# Check if PROD inventory exists and update it
if [ -f ansible/inventories/prod/hosts.yml ]; then
    cp ansible/inventories/prod/hosts.yml ansible/inventories/prod/hosts.yml.backup.$TIMESTAMP
    sed -i.bak 's/ssl_enabled: true/ssl_enabled: false/g' ansible/inventories/prod/hosts.yml
    echo "✅ PROD inventory SSL disabled"
fi

echo "✅ Inventory files updated"

# Update the main tasks file to remove certbot installation and SSL configuration
echo "🔄 Updating main tasks file..."

# Create a new version of main.yml without certbot
cat > ansible/roles/django-monolith/tasks/main.yml << 'MAINTASK_EOF'
---
# Variables
- name: Set application variables
  set_fact:
    app_user: "{{ app_user | default('zentravision') }}"
    app_home: "{{ app_home | default('/opt/zentravision') }}"
    app_name: "{{ app_name | default('zentravision') }}"

# Python and system packages (REMOVED certbot packages)
- name: Install Python and system dependencies
  apt:
    name:
      - python3
      - python3-pip
      - python3-venv
      - python3-dev
      - python3-psycopg2
      - build-essential
      - libpq-dev
      - postgresql
      - postgresql-contrib
      - redis-server
      - nginx
      - supervisor
      - gettext
    state: present

# PostgreSQL setup
- name: Start and enable PostgreSQL
  systemd:
    name: postgresql
    state: started
    enabled: yes

- name: Create PostgreSQL database user
  postgresql_user:
    name: "{{ app_user }}"
    password: "{{ vault_db_password | default('ZentravisionUAT2024!') }}"
    state: present
  become_user: postgres

- name: Create PostgreSQL database
  postgresql_db:
    name: "{{ app_name }}"
    owner: "{{ app_user }}"
    state: present
  become_user: postgres

# Redis setup
- name: Start and enable Redis
  systemd:
    name: redis-server
    state: started
    enabled: yes

# Application setup
- name: Ensure app directories exist
  file:
    path: "{{ item }}"
    state: directory
    owner: "{{ app_user }}"
    group: "{{ app_user }}"
    mode: '0755'
  loop:
    - "{{ app_home }}"
    - "{{ app_home }}/app"
    - "{{ app_home }}/logs"
    - "{{ app_home }}/static"
    - "{{ app_home }}/media"
    - "{{ app_home }}/backups"

# Clone or update application code
- name: Clone/update application repository
  git:
    repo: "{{ app_repo_url }}"
    dest: "{{ app_home }}/app"
    version: "{{ app_version | default('main') }}"
    force: yes
  become_user: "{{ app_user }}"
  when: app_repo_url is defined

# Python virtual environment
- name: Create Python virtual environment
  command: python3 -m venv {{ app_home }}/venv
  args:
    creates: "{{ app_home }}/venv/bin/activate"
  become_user: "{{ app_user }}"

# Install Python dependencies (if requirements.txt exists)
- name: Check if requirements.txt exists
  stat:
    path: "{{ app_home }}/app/requirements.txt"
  register: requirements_file

- name: Install Python dependencies
  pip:
    requirements: "{{ app_home }}/app/requirements.txt"
    virtualenv: "{{ app_home }}/venv"
  become_user: "{{ app_user }}"
  when: requirements_file.stat.exists

# Install additional dependencies script
- name: Create additional dependencies install script
  template:
    src: install_additional_deps.sh.j2
    dest: "{{ app_home }}/install_additional_deps.sh"
    owner: "{{ app_user }}"
    group: "{{ app_user }}"
    mode: '0755'

- name: Install additional Python dependencies
  command: "{{ app_home }}/install_additional_deps.sh"
  become_user: "{{ app_user }}"

# Create minimal Django project if app doesn't exist
- name: Check if Django project exists
  stat:
    path: "{{ app_home }}/app/manage.py"
  register: django_project

- name: Create minimal Django project
  block:
    - name: Install Django and essential packages in venv
      pip:
        name:
          - django
          - psycopg2-binary
          - gunicorn
          - django-redis
          - google-cloud-secret-manager
        virtualenv: "{{ app_home }}/venv"
      become_user: "{{ app_user }}"
    
    - name: Create Django project
      command: "{{ app_home }}/venv/bin/django-admin startproject {{ app_name }} ."
      args:
        chdir: "{{ app_home }}/app"
        creates: "{{ app_home }}/app/manage.py"
      become_user: "{{ app_user }}"
    
    - name: Create health check view file
      copy:
        dest: "{{ app_home }}/app/health_views.py"
        content: |
          from django.http import JsonResponse
          
          def health_check(request):
              return JsonResponse({
                  "status": "healthy", 
                  "environment": "{{ app_environment | default(environment) }}",
                  "service": "zentravision"
              })
        owner: "{{ app_user }}"
        group: "{{ app_user }}"
    
    - name: Update Django URLs to include health check
      copy:
        dest: "{{ app_home }}/app/{{ app_name }}/urls.py"
        content: |
          from django.contrib import admin
          from django.urls import path
          from health_views import health_check
          
          urlpatterns = [
              path('admin/', admin.site.urls),
              path('health/', health_check, name='health_check'),
          ]
        owner: "{{ app_user }}"
        group: "{{ app_user }}"

  when: not django_project.stat.exists

# Environment file
- name: Create/update environment file
  template:
    src: env.j2
    dest: "{{ app_home }}/.env"
    owner: "{{ app_user }}"
    group: "{{ app_user }}"
    mode: '0600'

# Django operations (con mejor manejo de errores)
- name: Run Django migrations
  django_manage:
    command: migrate
    app_path: "{{ app_home }}/app"
    virtualenv: "{{ app_home }}/venv"
  become_user: "{{ app_user }}"
  environment:
    DATABASE_URL: "postgresql://{{ app_user }}:{{ vault_db_password | default('ZentravisionUAT2024!') }}@localhost:5432/{{ app_name }}"
  ignore_errors: yes
  register: migrate_result

- name: Show migration output if failed
  debug:
    var: migrate_result
  when: migrate_result.failed | default(false)

# Collect static files - CRITICAL for fixing 404 errors on admin
- name: Collect Django static files
  django_manage:
    command: collectstatic
    app_path: "{{ app_home }}/app"
    virtualenv: "{{ app_home }}/venv"
  become_user: "{{ app_user }}"
  environment:
    DATABASE_URL: "postgresql://{{ app_user }}:{{ vault_db_password | default('ZentravisionUAT2024!') }}@localhost:5432/{{ app_name }}"
  ignore_errors: yes
  register: collectstatic_result

- name: Show collectstatic result
  debug:
    msg: "Collectstatic completed: {{ collectstatic_result.out | default('No output') }}"

# Ensure proper permissions on static files
- name: Set proper permissions on static directory
  file:
    path: "{{ app_home }}/static"
    owner: "{{ app_user }}"
    group: "{{ app_user }}"
    mode: '0755'
    recurse: yes
  ignore_errors: yes

# Create Django superuser if specified
- name: Create Django superuser
  django_manage:
    command: "createsuperuser --noinput --username={{ django_superuser_username }} --email={{ django_superuser_email }}"
    app_path: "{{ app_home }}/app"
    virtualenv: "{{ app_home }}/venv"
  become_user: "{{ app_user }}"
  environment:
    DATABASE_URL: "postgresql://{{ app_user }}:{{ vault_db_password | default('ZentravisionUAT2024!') }}@localhost:5432/{{ app_name }}"
    DJANGO_SUPERUSER_PASSWORD: "{{ django_superuser_password }}"
  when: django_create_superuser | default(false)
  ignore_errors: yes  # Puede fallar si el usuario ya existe

# Gunicorn service
- name: Create Gunicorn service file
  template:
    src: gunicorn.service.j2
    dest: "/etc/systemd/system/{{ app_name }}.service"
  notify:
    - reload systemd
    - restart zentravision

# Nginx configuration (HTTP ONLY - NO SSL)
- name: Create Nginx site configuration
  template:
    src: nginx.conf.j2
    dest: "/etc/nginx/sites-available/{{ app_name }}"
  notify: restart nginx

- name: Enable Nginx site
  file:
    src: "/etc/nginx/sites-available/{{ app_name }}"
    dest: "/etc/nginx/sites-enabled/{{ app_name }}"
    state: link
  notify: restart nginx

- name: Remove default Nginx site
  file:
    path: /etc/nginx/sites-enabled/default
    state: absent
  notify: restart nginx

# Test Nginx configuration before starting
- name: Test Nginx configuration
  command: nginx -t
  register: nginx_test
  failed_when: nginx_test.rc != 0
  changed_when: false

# Start services
- name: Start and enable application services
  systemd:
    name: "{{ item }}"
    state: started
    enabled: yes
    daemon_reload: yes
  loop:
    - "{{ app_name }}"
    - nginx
  ignore_errors: yes

# Wait for services to be ready
- name: Wait for Gunicorn to start
  wait_for:
    port: 8000
    host: 127.0.0.1
    delay: 5
    timeout: 30

# Final verification (HTTP ONLY)
- name: Verify application health
  uri:
    url: "http://127.0.0.1:8000/"
    method: GET
    status_code: [200, 302, 404]  # 302 redirect to login is OK, 404 is OK if no root URL
  retries: 3
  delay: 5
  ignore_errors: yes

# Display success message
- name: Display deployment info
  debug:
    msg: |
      ========================================
      🎉 Zentravision Deployed Successfully (HTTP Only)!
      ========================================
      
      🌐 Application URL: http://{{ domain_name }}
      🔧 Admin Panel: http://{{ domain_name }}/admin/
      📍 IP Access: http://{{ ansible_host }}:8000/
      
      ⚠️  SSL/HTTPS is DISABLED to avoid Let's Encrypt rate limits
      💡 You can configure SSL manually later if needed
      
      🔑 Admin Credentials:
      - Username: {{ django_superuser_username }}
      - Password: {{ django_superuser_password }}
      
      📋 Next Steps:
      1. Configure DNS: {{ domain_name }} → {{ ansible_host }}
      2. Test HTTP access: http://{{ domain_name }}
      3. Login to admin panel
      4. Upload test PDF
MAINTASK_EOF

echo "✅ Main tasks updated - SSL/Certbot removed"

# Update Nginx template to HTTP only
echo "🔄 Updating Nginx template for HTTP only..."

cat > ansible/roles/django-monolith/templates/nginx.conf.j2 << 'NGINX_EOF'
server {
    listen 80;
    server_name {{ domain_name }} {{ ansible_host }};

    # Increase client body size for PDF uploads
    client_max_body_size {{ nginx_max_body_size | default('50M') }};
    
    # Increase buffer sizes for large uploads
    client_body_buffer_size {{ nginx_body_buffer_size | default('128k') }};
    
    # Increase timeouts for AI processing
    proxy_connect_timeout {{ nginx_proxy_timeout | default('300s') }};
    proxy_send_timeout {{ nginx_proxy_timeout | default('300s') }};
    proxy_read_timeout {{ nginx_proxy_timeout | default('300s') }};
    send_timeout {{ nginx_send_timeout | default('300s') }};
    
    # Increase buffer sizes for proxy
    proxy_buffer_size {{ nginx_proxy_buffer_size | default('64k') }};
    proxy_buffers {{ nginx_proxy_buffers | default('8 64k') }};
    proxy_busy_buffers_size {{ nginx_proxy_busy_buffers | default('128k') }};

    location /static/ {
        alias {{ app_home }}/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias {{ app_home }}/media/;
        expires 1M;
        add_header Cache-Control "public";
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Prevent timeouts during file uploads and AI processing
        proxy_request_buffering off;
        proxy_buffering off;
        
        # Handle connection drops gracefully
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
    }

    # Security headers (without HTTPS)
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Health check endpoint
    location /health/ {
        proxy_pass http://127.0.0.1:8000/health/;
        access_log off;
    }
}
NGINX_EOF

echo "✅ Nginx template updated for HTTP only"

# Update check-dns scripts to remove SSL verification
echo "🔄 Updating check-dns scripts..."

# Update DEV check-dns script
cat > scripts/deploy/dev/check-dns.sh << 'CHECKDEV_EOF'
#!/bin/bash
set -e

DOMAIN="dev-zentravision.zentratek.com"

# Obtener IP actual de la instancia
cd terraform/environments/dev
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")
cd ../../..

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ No se pudo obtener la IP de la instancia DEV"
    exit 1
fi

echo "🌐 Verificando HTTP para $DOMAIN (DEV - SSL DISABLED)"
echo "===================================================="
echo "📍 IP: $INSTANCE_IP"
echo ""

# Verificar DNS
DNS_IP=$(dig +short $DOMAIN | tail -1)
if [ "$DNS_IP" != "$INSTANCE_IP" ]; then
    echo "❌ DNS no resuelve correctamente"
    echo "   DNS: $DOMAIN → $DNS_IP"
    echo "   Esperado: $INSTANCE_IP"
    echo ""
    echo "🛠️  ACCIÓN REQUERIDA: Configurar DNS"
    echo "====================================="
    echo "Configura en tu proveedor DNS:"
    echo "   Tipo: A"
    echo "   Nombre: dev-zentravision"
    echo "   Valor: $INSTANCE_IP"
    echo "   TTL: 300"
    exit 1
fi
echo "✅ DNS: $DOMAIN → $DNS_IP"

# Verificar HTTP
echo ""
echo "🌐 Verificando HTTP..."
if curl -s -I "http://$DOMAIN" | grep -q "HTTP/1.1 200\|HTTP/1.1 302"; then
    echo "✅ HTTP funcionando correctamente"
else
    echo "❌ HTTP no responde"
    echo "🔍 Debugging HTTP:"
    curl -I "http://$DOMAIN" || echo "Error de conexión HTTP"
    exit 1
fi

# Verificar aplicación directamente
echo ""
echo "🏥 Verificando aplicación..."
if curl -s -f "http://$INSTANCE_IP:8000/" > /dev/null 2>&1; then
    echo "✅ Aplicación funcionando en puerto 8000"
else
    echo "⚠️  Aplicación no responde en puerto 8000"
fi

echo ""
echo "🎉 Verificación completada (HTTP Only)"
echo "======================================"
echo "🌐 URL Principal: http://$DOMAIN"
echo "🔧 Admin Panel: http://$DOMAIN/admin/"
echo "📍 IP directa: http://$INSTANCE_IP:8000/"
echo "👤 Usuario: admin"
echo "🔑 Password: DevPassword123!"
echo ""
echo "⚠️  SSL/HTTPS DESHABILITADO para evitar límites de Let's Encrypt"
echo "💡 Puedes configurar SSL manualmente más tarde si es necesario"

echo ""
echo "📊 Health check:"
echo "================"
echo "HTTP: $(curl -s -o /dev/null -w '%{http_code}' http://$DOMAIN || echo 'Error')"
echo "Direct: $(curl -s -o /dev/null -w '%{http_code}' http://$INSTANCE_IP:8000/ 2>/dev/null || echo 'Error')"
CHECKDEV_EOF

chmod +x scripts/deploy/dev/check-dns.sh

# Update UAT check-ssl script to be HTTP only
cat > scripts/deploy/uat/check-ssl.sh << 'CHECKUAT_EOF'
#!/bin/bash
set -e

DOMAIN="uat-zentravision.zentratek.com"

# Obtener IP actual de la instancia
cd terraform/environments/uat
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")
cd ../../..

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ No se pudo obtener la IP de la instancia UAT"
    exit 1
fi

echo "🌐 Verificando HTTP para $DOMAIN (UAT - SSL DISABLED)"
echo "===================================================="
echo "📍 IP: $INSTANCE_IP"
echo ""

# Verificar DNS
DNS_IP=$(dig +short $DOMAIN | tail -1)
if [ "$DNS_IP" != "$INSTANCE_IP" ]; then
    echo "❌ DNS no resuelve correctamente"
    echo "   DNS: $DOMAIN → $DNS_IP"
    echo "   Esperado: $INSTANCE_IP"
    echo ""
    echo "🛠️  ACCIÓN REQUERIDA: Configurar DNS"
    echo "====================================="
    echo "Configura en tu proveedor DNS:"
    echo "   Tipo: A"
    echo "   Nombre: uat-zentravision"
    echo "   Valor: $INSTANCE_IP"
    echo "   TTL: 300"
    exit 1
fi
echo "✅ DNS: $DOMAIN → $DNS_IP"

# Verificar HTTP
echo ""
echo "🌐 Verificando HTTP..."
if curl -s -I "http://$DOMAIN" | grep -q "HTTP/1.1 200\|HTTP/1.1 302"; then
    echo "✅ HTTP funcionando correctamente"
else
    echo "❌ HTTP no responde"
    echo "🔍 Debugging HTTP:"
    curl -I "http://$DOMAIN" || echo "Error de conexión HTTP"
    exit 1
fi

echo ""
echo "🎉 Verificación completada (HTTP Only)"
echo "======================================"
echo "🌐 URL Principal: http://$DOMAIN"
echo "🔧 Admin Panel: http://$DOMAIN/admin/"
echo "👤 Usuario: admin"
echo "🔑 Password: UatPassword123!"
echo ""
echo "⚠️  SSL/HTTPS DESHABILITADO para evitar límites de Let's Encrypt"

echo ""
echo "📊 Health check:"
echo "================"
echo "HTTP: $(curl -s -o /dev/null -w '%{http_code}' http://$DOMAIN || echo 'Error')"
CHECKUAT_EOF

chmod +x scripts/deploy/uat/check-ssl.sh

# Update PROD check-dns script
cat > scripts/deploy/prod/check-dns.sh << 'CHECKPROD_EOF'
#!/bin/bash
set -e

# Obtener dominio de variable de entorno o usar por defecto
DOMAIN="${DOMAIN_NAME:-zentravision.zentratek.com}"

# Obtener IP actual de la instancia
cd terraform/environments/prod
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")
cd ../../..

if [ -z "$INSTANCE_IP" ]; then
    echo "❌ No se pudo obtener la IP de la instancia PROD"
    exit 1
fi

echo "🌐 Verificando HTTP para $DOMAIN (PRODUCCIÓN - SSL DISABLED)"
echo "============================================================"
echo "📍 IP: $INSTANCE_IP"
echo ""

# Verificar DNS
DNS_IP=$(dig +short $DOMAIN | tail -1)
if [ "$DNS_IP" != "$INSTANCE_IP" ]; then
    echo "❌ DNS no resuelve correctamente"
    echo "   DNS: $DOMAIN → $DNS_IP"
    echo "   Esperado: $INSTANCE_IP"
    echo ""
    echo "🔴 CRÍTICO: Configurar DNS INMEDIATAMENTE"
    echo "=========================================="
    echo "Configura en tu proveedor DNS:"
    echo "   Tipo: A"
    echo "   Nombre: $(echo $DOMAIN | cut -d. -f1) (o @ si es dominio raíz)"
    echo "   Valor: $INSTANCE_IP"
    echo "   TTL: 300"
    exit 1
fi
echo "✅ DNS: $DOMAIN → $DNS_IP"

# Verificar HTTP
echo ""
echo "🌐 Verificando HTTP..."
if curl -s -I "http://$DOMAIN" | grep -q "HTTP/1.1 200\|HTTP/1.1 302"; then
    echo "✅ HTTP funcionando correctamente"
else
    echo "❌ HTTP no responde"
    echo "🔍 Debugging HTTP:"
    curl -I "http://$DOMAIN" || echo "Error de conexión HTTP"
    exit 1
fi

echo ""
echo "🎉 PRODUCCIÓN HTTP FUNCIONANDO"
echo "=============================="
echo "🌐 Aplicación: http://$DOMAIN"
echo "🔧 Admin panel: http://$DOMAIN/admin/"
echo "👤 Usuario: admin"
echo "🔑 ⚠️  CAMBIAR PASSWORD INMEDIATAMENTE"
echo ""
echo "⚠️  SSL/HTTPS DESHABILITADO para evitar límites de Let's Encrypt"
echo "💡 Configura SSL manualmente cuando sea necesario"

echo ""
echo "📊 Health check de PRODUCCIÓN:"
echo "=============================="
echo "HTTP: $(curl -s -o /dev/null -w '%{http_code}' http://$DOMAIN || echo 'Error')"
echo "Internal: $(curl -s -o /dev/null -w '%{http_code}' http://$INSTANCE_IP:8000/ 2>/dev/null || echo 'Error')"
CHECKPROD_EOF

chmod +x scripts/deploy/prod/check-dns.sh

echo ""
echo "✅ Certbot removal completed successfully!"
echo "=========================================="
echo ""
echo "📝 Changes made:"
echo "1. ✅ Removed certbot packages from installation"
echo "2. ✅ Disabled SSL configuration in Ansible tasks"
echo "3. ✅ Updated all inventory files: ssl_enabled: false"
echo "4. ✅ Updated Nginx template to HTTP only"
echo "5. ✅ Updated all check-dns scripts for HTTP verification"
echo "6. ✅ Created backups with timestamp: $TIMESTAMP"
echo ""
echo "📋 Next steps:"
echo "1. Run deployment: make deploy-dev, make deploy-uat, or make deploy-prod"
echo "2. Applications will be available on HTTP only"
echo "3. No more Let's Encrypt rate limit issues!"
echo "4. Configure SSL manually later if needed"
echo ""
echo "🌐 Your applications will be available at:"
echo "- DEV: http://dev-zentravision.zentratek.com"
echo "- UAT: http://uat-zentravision.zentratek.com"
echo "- PROD: http://your-domain.com"
echo ""
echo "⚠️  Remember: SSL/HTTPS is now DISABLED to avoid certbot issues"
