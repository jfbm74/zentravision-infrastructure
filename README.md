# Zentravision Infrastructure

Infrastructure as Code (IaC) y Configuration as Code (CaC) para **Zentravision** - Una aplicación Django para procesamiento inteligente de glosas médicas con IA.

## 🩺 Sobre Zentravision

**Zentravision** es una aplicación Django especializada en el procesamiento automático de glosas médicas utilizando Inteligencia Artificial. La aplicación permite:

- **Extracción de texto** de documentos PDF médicos
- **Procesamiento inteligente** de glosas con OpenAI GPT
- **Análisis automático** de contenido médico
- **Gestión de batches** para procesamiento masivo
- **Tareas asíncronas** con Celery para procesamiento en background
- **API REST** para integración con otros sistemas

### 🏗️ Arquitectura Técnica

- **Backend**: Django 4.x + Python 3.10
- **Base de datos**: PostgreSQL
- **Cache & Queue**: Redis + Celery
- **Web Server**: Nginx + Gunicorn
- **IA Processing**: OpenAI GPT API
- **Infraestructura**: Google Cloud Platform
- **IaC**: Terraform + Ansible
- **Monitoreo**: Google Cloud Monitoring

## 🚀 Comandos de Supervivencia

### 🔄 Reiniciar Servicios

```bash
# Conectar al servidor
ssh zentravision@34.45.112.122  # DEV
ssh zentravision@<IP_UAT>        # UAT  
ssh admin@<IP_PROD>              # PROD

# Reiniciar todos los servicios
sudo systemctl restart zentravision zentravision-celery nginx

# Reiniciar servicios individualmente
sudo systemctl restart zentravision        # Django/Gunicorn
sudo systemctl restart zentravision-celery # Celery workers  
sudo systemctl restart nginx               # Nginx
sudo systemctl restart postgresql          # Base de datos
sudo systemctl restart redis-server        # Redis/Cache
```

### 📊 Ver Logs en Tiempo Real

```bash
# Logs de la aplicación Django
sudo journalctl -u zentravision -f

# Logs de Celery workers
sudo journalctl -u zentravision-celery -f

# Logs de Nginx
sudo journalctl -u nginx -f

# Logs de aplicación (si existen)
tail -f /opt/zentravision/logs/zentravision.log

# Ver todos los logs juntos
sudo journalctl -u zentravision -u zentravision-celery -u nginx -f

# Logs específicos de errores
sudo journalctl -u zentravision --since "1 hour ago" | grep -i error
```

### 🔍 Verificar Estado de Servicios

```bash
# Estado de todos los servicios principales
sudo systemctl status zentravision zentravision-celery nginx postgresql redis-server

# Solo verificar si están activos
sudo systemctl is-active zentravision zentravision-celery nginx

# Ver procesos de Celery
ps aux | grep celery

# Verificar conectividad web
curl -I http://localhost:8000/
curl -I http://localhost/  # A través de Nginx
```

### 🧪 Probar Funcionalidad

```bash
# Test de conectividad de Celery
cd /opt/zentravision/app
python manage.py shell << 'EOF'
from celery import current_app
i = current_app.control.inspect()
print("Workers activos:", i.stats())
exit()
EOF

# Test de OpenAI configuración
python manage.py shell << 'EOF'
from django.conf import settings
print("OpenAI configurado:", hasattr(settings, 'OPENAI_API_KEY'))
exit()
EOF

# Verificar base de datos
python manage.py check --database default

# Test de health check
curl http://localhost:8000/health/
```

### 🔑 Configurar OpenAI Token

```bash
# Método 1: Via Google Secret Manager (recomendado)
echo "tu-openai-api-key" | gcloud secrets create zentraflow-dev-openai-key --data-file=-

# Método 2: Editar settings.py directamente (temporal)
cd /opt/zentravision/app
nano zentravision/settings.py
# Agregar: OPENAI_API_KEY = "tu-api-key-aqui"

# Reiniciar Django para aplicar cambios
sudo systemctl restart zentravision

# Verificar que se aplicó
python manage.py shell -c "from django.conf import settings; print('OpenAI:', hasattr(settings, 'OPENAI_API_KEY'))"
```

### 🗄️ Gestión de Base de Datos

```bash
# Conectar a PostgreSQL
sudo -u postgres psql zentravision

# Backup manual
sudo -u zentravision /opt/zentravision/backup-db.sh

# Ver migraciones pendientes
cd /opt/zentravision/app
python manage.py showmigrations

# Aplicar migraciones
python manage.py migrate

# Crear superusuario
python manage.py createsuperuser
```

### 🔧 Solución de Problemas Rápidos

```bash
# Error 502 Bad Gateway
sudo systemctl restart zentravision nginx
sudo systemctl status zentravision

# Celery no procesa tareas
sudo systemctl restart zentravision-celery
sudo journalctl -u zentravision-celery --since "5 minutes ago"

# Espacio en disco
df -h
du -sh /opt/zentravision/logs/*

# Limpiar logs antiguos
find /opt/zentravision/logs -name "*.log" -mtime +7 -delete

# Verificar conectividad de red
ping 8.8.8.8
curl -I https://api.openai.com/v1/models

# Reiniciar todo si falla
sudo systemctl stop zentravision zentravision-celery nginx
sleep 5
sudo systemctl start postgresql redis-server
sleep 2  
sudo systemctl start zentravision zentravision-celery nginx
```

## 📁 Estructura del Proyecto

```
zentravision-infrastructure/
├── README.md                    # Este archivo
├── Makefile                     # Comandos simplificados
├── ansible/                     # Configuración con Ansible
│   ├── inventories/            # Inventarios por ambiente
│   ├── playbooks/              # Playbooks de despliegue
│   └── roles/                  # Roles reutilizables
├── scripts/                    # Scripts de utilidad
│   ├── deploy/                 # Scripts de despliegue por ambiente
│   ├── backup/                 # Scripts de backup
│   └── monitoring/             # Scripts de monitoreo
└── terraform/                  # Infraestructura con Terraform
    ├── environments/           # Configuraciones por ambiente
    ├── modules/               # Módulos reutilizables
    └── shared/                # Configuración compartida
```

## 🚀 Quick Start

### Prerrequisitos

1. **Google Cloud CLI**
   ```bash
   # Instalar gcloud CLI
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud auth login
   gcloud auth application-default login
   gcloud config set project zentraflow
   ```

2. **Terraform**
   ```bash
   # Ubuntu/Debian
   wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   ```

3. **Ansible**
   ```bash
   # Ubuntu/Debian
   sudo apt update
   sudo apt install ansible
   
   # macOS
   brew install ansible
   ```

### Configuración Inicial

1. **Clonar el repositorio**
   ```bash
   git clone https://github.com/jfbm74/zentravision-infrastructure.git
   cd zentravision-infrastructure
   ```

2. **Configurar variables de entorno**
   ```bash
   # Para DEV (valores por defecto incluidos)
   export DOMAIN_NAME="dev-zentravision.zentratek.com"
   export ADMIN_EMAIL="consultoria@zentratek.com"
   export DJANGO_ADMIN_PASSWORD="DevPassword123!"
   
   # Para UAT (automático)
   # Dominio: uat-zentravision.zentratek.com
   
   # Para PROD (REQUERIDO)
   export DOMAIN_NAME="zentravision.zentratek.com"  # Tu dominio
   export ADMIN_EMAIL="consultoria@zentratek.com"
   export DJANGO_ADMIN_PASSWORD="TuPasswordMuySeguro123!"
   ```

3. **Configurar OpenAI API Key**
   ```bash
   # Configurar para DEV
   ./scripts/configure-openai-key.sh zentraflow dev
   
   # Para UAT
   ./scripts/configure-openai-key.sh zentraflow uat
   
   # Para PROD
   ./scripts/configure-openai-key.sh zentraflow prod
   ```

### 🎯 Despliegue Completo (Con IPs Dinámicas)

#### Ambiente de Desarrollo (DEV)
```bash
# Despliegue completo automático
make full-deploy-dev

# O paso a paso
make init-dev
make plan-dev
make apply-dev
make deploy-dev

# Verificar DNS y funcionalidad
make check-dns-dev
```

#### Ambiente de UAT
```bash
# Despliegue completo (con confirmaciones)
make full-deploy-uat

# O paso a paso
make init-uat
make plan-uat
make apply-uat
make deploy-uat

# Verificar DNS y funcionalidad
make check-dns-uat
```

#### Ambiente de Producción
```bash
# IMPORTANTE: Configurar variables antes
export DOMAIN_NAME="zentravision.zentratek.com"
export ADMIN_EMAIL="consultoria@zentratek.com"
export DJANGO_ADMIN_PASSWORD="TuPasswordMuySeguro123!"

# Despliegue completo (con múltiples confirmaciones)
make full-deploy-prod

# O paso a paso (recomendado para producción)
make init
make plan
make apply
make deploy

# Verificar DNS y funcionalidad
make check-dns
```

## 🎯 Comandos Makefile

### Comandos de Desarrollo (DEV)
```bash
make help                  # Mostrar ayuda
make init-dev              # Inicializar Terraform (DEV)
make plan-dev              # Planear infraestructura (DEV)
make apply-dev             # Aplicar infraestructura (DEV)
make deploy-dev            # Configurar aplicación (DEV) - genera inventario automático
make ssh-dev               # Conectar por SSH (DEV)
make destroy-dev           # ⚠️  Destruir infraestructura (DEV)
make check-dns-dev         # Verificar configuración DNS (DEV)
make update-app-dev        # Actualizar solo la aplicación (DEV)
```

### Comandos de UAT
```bash
make init-uat              # Inicializar Terraform (UAT)
make plan-uat              # Planear infraestructura (UAT)
make apply-uat             # Aplicar infraestructura (UAT)
make deploy-uat            # Configurar aplicación (UAT) - genera inventario automático
make ssh-uat               # Conectar por SSH (UAT)
make destroy-uat           # ⚠️  Destruir infraestructura (UAT)
make check-dns-uat         # Verificar configuración DNS (UAT)
make update-app-uat        # Actualizar solo la aplicación (UAT)
```

### Comandos de Producción
```bash
make init                  # Inicializar Terraform (PROD)
make plan                  # Planear infraestructura (PROD)
make apply                 # Aplicar infraestructura (PROD) - con confirmación
make deploy                # Configurar aplicación (PROD) - genera inventario automático
make ssh                   # Conectar por SSH (PROD)
make destroy               # ⚠️  Destruir infraestructura (PROD) - doble confirmación
make check-dns             # Verificar configuración DNS (PROD)
make update-app-prod       # Actualizar solo la aplicación (PROD)
```

### Comandos de Utilidad
```bash
make show-ips              # Mostrar IPs de todas las instancias
make health-check          # Verificar salud de todas las instancias
make clean-inventories     # Limpiar inventarios generados dinámicamente
```

## 🌍 Configuración por Ambiente

### Desarrollo (DEV)
- **Dominio**: `dev-zentravision.zentratek.com`
- **SSL**: Deshabilitado por defecto (evitar límites Let's Encrypt)
- **Debug**: Habilitado
- **Backups**: Deshabilitados
- **Celery Workers**: 1 worker
- **Usuario SSH**: `zentravision`
- **IP**: Dinámica (se obtiene automáticamente de Terraform)

### UAT
- **Dominio**: `uat-zentravision.zentratek.com`
- **SSL**: Configurable
- **Debug**: Deshabilitado
- **Backups**: Habilitados (15 días retención)
- **Celery Workers**: 2 workers
- **Usuario SSH**: `zentravision`
- **IP**: Dinámica (se obtiene automáticamente de Terraform)

### Producción (PROD)
- **Dominio**: Configurable via `DOMAIN_NAME`
- **SSL**: Habilitado con Let's Encrypt
- **Debug**: Deshabilitado
- **Backups**: Habilitados (30 días retención)
- **Celery Workers**: 3 workers
- **Usuario SSH**: `admin`
- **IP**: Dinámica (se obtiene automáticamente de Terraform)

## 🔐 Gestión de Secretos

Los secretos se almacenan en Google Secret Manager:

```bash
# Configurar secretos automáticamente
./scripts/setup-secrets.sh zentraflow prod

# O manualmente
echo -n "tu-api-key-openai" | gcloud secrets create zentraflow-prod-openai-key --data-file=-
```

Secretos requeridos:
- `zentraflow-{env}-django-secret`: Clave secreta de Django
- `zentraflow-{env}-db-password`: Contraseña de la base de datos
- `zentraflow-{env}-openai-key`: API Key de OpenAI

## 📊 Monitoreo y Logs

### Verificar estado de la aplicación
```bash
# Health check por ambiente
make check-dns-dev      # Verifica DEV + DNS
make check-dns-uat      # Verifica UAT + DNS  
make check-dns         # Verifica PROD + DNS

# Health check de todos los ambientes
make health-check

# Ver IPs de todas las instancias
make show-ips

# Conectarse y verificar servicios
make ssh-dev           # SSH a DEV
make ssh-uat           # SSH a UAT  
make ssh               # SSH a PROD
sudo systemctl status zentravision zentravision-celery nginx postgresql redis-server
```

### Scripts de verificación automática
- **`scripts/deploy/dev/check-dns.sh`**: Verifica DNS y conectividad para DEV
- **`scripts/deploy/uat/check-dns.sh`**: Verifica DNS y conectividad para UAT  
- **`scripts/deploy/prod/check-dns.sh`**: Verifica DNS y conectividad para PROD

## 🔄 Actualización de la Aplicación

### Actualización rápida (solo aplicación)
```bash
# DEV - Actualización rápida
make update-app-dev

# UAT - Actualización con inventario dinámico
make update-app-uat

# PROD - Actualización con confirmación
make update-app-prod
```

### Actualización completa (infraestructura + aplicación)
```bash
# Re-ejecutar despliegue completo por ambiente
make full-deploy-dev    # DEV
make full-deploy-uat    # UAT
make full-deploy-prod   # PROD (requiere variables de entorno)
```

## 🐛 Troubleshooting Específico de Zentravision

### Problemas con Procesamiento de PDFs

```bash
# Verificar logs de Celery para errores de procesamiento
sudo journalctl -u zentravision-celery --since "1 hour ago" | grep -i error

# Verificar OpenAI API Key
cd /opt/zentravision/app
python manage.py shell -c "from django.conf import settings; print('OpenAI OK:', hasattr(settings, 'OPENAI_API_KEY'))"

# Test de conectividad con OpenAI
curl -H "Authorization: Bearer $(python -c 'from django.conf import settings; print(settings.OPENAI_API_KEY)')" \
     https://api.openai.com/v1/models
```

### Problemas con Celery Workers

```bash
# Verificar workers activos
cd /opt/zentravision/app
python manage.py shell << 'EOF'
from celery import current_app
i = current_app.control.inspect()
print("Workers stats:", i.stats())
print("Active tasks:", i.active())
EOF

# Reiniciar Celery si no responde
sudo systemctl restart zentravision-celery
sudo systemctl status zentravision-celery

# Ver cola de tareas en Redis
redis-cli
> KEYS celery*
> LLEN celery
```

### Problemas de Performance

```bash
# Verificar uso de recursos
top
htop
df -h

# Ver logs de aplicación con timestamps
sudo journalctl -u zentravision --since "1 hour ago" -o short-iso

# Optimizar base de datos
cd /opt/zentravision/app
python manage.py dbshell << 'EOF'
VACUUM ANALYZE;
EOF
```

## 🔒 Seguridad

### Configuración de seguridad incluida
- Firewall UFW configurado
- Fail2ban para protección SSH
- SSL/HTTPS automático (configurable)
- Acceso SSH restringido por IP
- Service Account con permisos mínimos
- Backups encriptados en Google Cloud Storage
- Secretos gestionados via Google Secret Manager

### Recomendaciones específicas para Zentravision
1. **Rotar OpenAI API Key** regularmente
2. **Monitorear uso de API** de OpenAI
3. **Configurar límites** de procesamiento por usuario
4. **Revisar logs** de procesamiento de documentos
5. **Mantener backups** de documentos procesados

## 🆘 Contacto y Soporte

### Información del proyecto
- **Proyecto GCP**: zentraflow
- **Repositorio aplicación**: https://github.com/jfbm74/zentravision.git
- **Repositorio infraestructura**: https://github.com/jfbm74/zentravision-infrastructure.git

### Dominios configurados
- **DEV**: `dev-zentravision.zentratek.com`
- **UAT**: `uat-zentravision.zentratek.com`  
- **PROD**: Configurable via `DOMAIN_NAME`

### Scripts clave para emergencias
```bash
# Script de reinicio completo
ssh zentravision@<IP> << 'EOF'
sudo systemctl stop zentravision zentravision-celery nginx
sleep 5
sudo systemctl start postgresql redis-server
sleep 2
sudo systemctl start zentravision zentravision-celery nginx
sudo systemctl status zentravision zentravision-celery nginx
EOF

# Script de verificación rápida
ssh zentravision@<IP> << 'EOF'
echo "=== SERVICIOS ==="
sudo systemctl is-active zentravision zentravision-celery nginx postgresql redis-server
echo "=== CELERY WORKERS ==="
ps aux | grep [c]elery
echo "=== CONECTIVIDAD ==="
curl -s -o /dev/null -w "HTTP: %{http_code}\n" http://localhost:8000/
EOF
```

---

**🩺 Zentravision**: Procesamiento inteligente de glosas médicas con IA  
**🔄 Sistema de IPs Dinámicas**: Los inventarios se generan automáticamente en cada despliegue  
**🚀 Celery Workers**: Configurados para procesamiento asíncrono eficiente