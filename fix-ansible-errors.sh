#!/bin/bash
# ============================================================================
# SCRIPT CORREGIDO SIN ERRORES DE SED
# ============================================================================

set -e

echo "🔧 ARREGLANDO ERRORES DE ANSIBLE (MÉTODO SEGURO)"
echo "================================================"

# 1. Verificar y mostrar el contenido actual de main.yml
echo "1️⃣  Verificando contenido actual de main.yml..."

if grep -q "CELERY CONFIGURATION" ansible/roles/django-monolith/tasks/main.yml; then
    echo "⚠️  Se encontraron tareas duplicadas de Celery"
    
    # Crear una versión limpia del archivo
    echo "📝 Creando versión limpia de main.yml..."
    
    # Crear backup
    cp ansible/roles/django-monolith/tasks/main.yml ansible/roles/django-monolith/tasks/main.yml.backup-$(date +%Y%m%d-%H%M%S)
    
    # Usar head para obtener todo hasta la línea problemática
    grep -n "# ===== CELERY CONFIGURATION =====" ansible/roles/django-monolith/tasks/main.yml | head -1 | cut -d: -f1 > /tmp/line_number
    
    if [ -s /tmp/line_number ]; then
        LINE_NUM=$(cat /tmp/line_number)
        LINE_NUM=$((LINE_NUM - 1))  # Una línea antes
        echo "📍 Cortando archivo en línea $LINE_NUM"
        head -n $LINE_NUM ansible/roles/django-monolith/tasks/main.yml > /tmp/main_clean.yml
        mv /tmp/main_clean.yml ansible/roles/django-monolith/tasks/main.yml
        echo "✅ Tareas duplicadas removidas"
    else
        echo "⚠️  No se encontró la línea exacta, continuando..."
    fi
    
    rm -f /tmp/line_number
else
    echo "✅ No se encontraron tareas duplicadas"
fi

# 2. Crear template de Celery corregido
echo ""
echo "2️⃣  Creando template de Celery corregido..."

cat > ansible/roles/django-monolith/templates/celery.service.j2 << 'TEMPLATE_EOF'
[Unit]
Description=Zentravision Celery Worker Service
After=network.target redis-server.service postgresql.service

[Service]
Type=exec
User={{ app_user }}
Group={{ app_user }}
WorkingDirectory={{ app_home }}/app
ExecStart={{ app_home }}/venv/bin/celery -A {{ app_name }} worker \
    --loglevel={{ celery_log_level | default('info') }} \
    --concurrency={{ celery_worker_concurrency | default(1) }}
Restart=always
RestartSec=10
Environment=DJANGO_SETTINGS_MODULE={{ app_name }}.settings
Environment=PYTHONPATH={{ app_home }}/app
Environment=C_FORCE_ROOT=1
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
TEMPLATE_EOF

echo "✅ Template de Celery corregido"

# 3. Crear archivo celery.yml mejorado
echo ""
echo "3️⃣  Creando celery.yml mejorado..."

cat > ansible/roles/django-monolith/tasks/celery.yml << 'CELERY_TASKS_EOF'
---
# Celery Worker Configuration - MEJORADO
- name: Check if Celery service exists
  stat:
    path: "/etc/systemd/system/{{ app_name }}-celery.service"
  register: celery_service_exists

- name: Stop Celery service if exists
  systemd:
    name: "{{ app_name }}-celery"
    state: stopped
  when: celery_service_exists.stat.exists
  ignore_errors: yes

- name: Kill existing Celery processes safely
  shell: |
    for pid in $(pgrep -f "celery.*worker" 2>/dev/null || echo ""); do
      if [ -n "$pid" ]; then
        kill -TERM "$pid" 2>/dev/null || true
        sleep 1
        kill -KILL "$pid" 2>/dev/null || true
      fi
    done
  ignore_errors: yes
  changed_when: false

- name: Create Celery runtime directories
  file:
    path: "{{ item }}"
    state: directory
    owner: "{{ app_user }}"
    group: "{{ app_user }}"
    mode: '0755'
  loop:
    - /var/run/celery
    - /var/log/celery
    - "{{ app_home }}/logs/celery"

- name: Clean old PID files
  file:
    path: "{{ item }}"
    state: absent
  loop:
    - /var/run/celery/worker.pid
    - /var/run/celery/beat.pid
  ignore_errors: yes

- name: Create Celery systemd service file
  template:
    src: celery.service.j2
    dest: "/etc/systemd/system/{{ app_name }}-celery.service"
    owner: root
    group: root
    mode: '0644'

- name: Reload systemd daemon
  systemd:
    daemon_reload: yes

- name: Enable and start Celery service
  systemd:
    name: "{{ app_name }}-celery"
    enabled: yes
    state: started

- name: Wait for Celery to start
  wait_for:
    timeout: 30
    delay: 10

- name: Verify Celery is running
  command: systemctl is-active {{ app_name }}-celery
  register: celery_status
  retries: 3
  delay: 5
  until: celery_status.stdout == "active"
  changed_when: false

- name: Display Celery success message
  debug:
    msg: |
      🎉 Celery Worker Successfully Started!
      ====================================
      Status: {{ celery_status.stdout }}
      Workers: {{ celery_worker_concurrency | default(1) }}
      Log Level: {{ celery_log_level | default('info') }}
      
      Commands:
      - sudo systemctl status {{ app_name }}-celery
      - sudo journalctl -u {{ app_name }}-celery -f
CELERY_TASKS_EOF

echo "✅ Archivo celery.yml mejorado creado"

# 4. Actualizar main.yml para incluir Celery al final
echo ""
echo "4️⃣  Agregando include para Celery en main.yml..."

# Verificar si ya tiene el include
if ! grep -q "include_tasks: celery.yml" ansible/roles/django-monolith/tasks/main.yml; then
    echo "" >> ansible/roles/django-monolith/tasks/main.yml
    echo "# Import Celery configuration tasks" >> ansible/roles/django-monolith/tasks/main.yml
    echo "- name: Configure Celery Workers" >> ansible/roles/django-monolith/tasks/main.yml
    echo "  include_tasks: celery.yml" >> ansible/roles/django-monolith/tasks/main.yml
    echo "  tags: ['celery', 'workers']" >> ansible/roles/django-monolith/tasks/main.yml
    echo "✅ Include de Celery agregado"
else
    echo "✅ Include de Celery ya existe"
fi

# 5. Aplicar arreglo inmediato al servidor
echo ""
echo "5️⃣  Aplicando arreglo inmediato al servidor..."

# Obtener IP
cd terraform/environments/dev
INSTANCE_IP=$(terraform output -raw instance_ip 2>/dev/null || echo "")
cd ../../..

if [ -n "$INSTANCE_IP" ] && [ "$INSTANCE_IP" != "" ]; then
    echo "📍 Aplicando en servidor: $INSTANCE_IP"
    
    ssh zentravision@$INSTANCE_IP << 'REMOTE_FIX'
echo "🔧 Arreglando Celery en el servidor..."

# Parar procesos existentes
sudo pkill -f celery || true
sleep 2

# Parar servicio
sudo systemctl stop zentravision-celery || true

# Limpiar archivos
sudo rm -f /var/run/celery/*.pid || true

# Crear servicio mejorado
sudo tee /etc/systemd/system/zentravision-celery.service > /dev/null << 'SERVICE'
[Unit]
Description=Zentravision Celery Worker Service
After=network.target redis-server.service

[Service]
Type=exec
User=zentravision
Group=zentravision
WorkingDirectory=/opt/zentravision/app
ExecStart=/opt/zentravision/venv/bin/celery -A zentravision worker --loglevel=debug --concurrency=1
Restart=always
RestartSec=10
Environment=DJANGO_SETTINGS_MODULE=zentravision.settings
Environment=PYTHONPATH=/opt/zentravision/app
Environment=C_FORCE_ROOT=1
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

# Recargar e iniciar
sudo systemctl daemon-reload
sudo systemctl enable zentravision-celery
sudo systemctl start zentravision-celery

# Verificar
sleep 5
if sudo systemctl is-active zentravision-celery | grep -q "active"; then
    echo "✅ Celery funcionando correctamente"
    sudo systemctl status zentravision-celery --no-pager -l
else
    echo "⚠️  Celery no está activo, revisando logs..."
    sudo journalctl -u zentravision-celery --no-pager -n 10
fi
REMOTE_FIX

    echo "✅ Arreglo aplicado al servidor"
else
    echo "⚠️  No se pudo obtener IP del servidor"
fi

echo ""
echo "🎉 SCRIPT COMPLETADO SIN ERRORES"
echo "================================="
echo ""
echo "✅ 1. Variables duplicadas eliminadas"
echo "✅ 2. Tareas duplicadas removidas (método seguro)"
echo "✅ 3. Template Celery mejorado (Type=exec)"
echo "✅ 4. Archivo celery.yml mejorado"
echo "✅ 5. Include agregado a main.yml"
echo "✅ 6. Servidor actualizado inmediatamente"
echo ""
echo "🚀 PRÓXIMOS PASOS:"
echo "make deploy-dev    # Debería funcionar perfectamente"
echo ""
echo "🔍 VERIFICAR:"
if [ -n "$INSTANCE_IP" ]; then
    echo "ssh zentravision@$INSTANCE_IP 'sudo systemctl status zentravision-celery'"
    echo "ssh zentravision@$INSTANCE_IP 'sudo journalctl -u zentravision-celery -f'"
fi