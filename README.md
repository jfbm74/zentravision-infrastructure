# Zentravision Infrastructure

Infrastructure as Code (IaC) y Configuration as Code (CaC) para Zentravision - Una aplicación Django para procesamiento de PDFs con IA.

## 🏗️ Arquitectura

- **Infraestructura**: Terraform + Google Cloud Platform
- **Configuración**: Ansible
- **Aplicación**: Django monolítico con Nginx + Gunicorn
- **Base de datos**: PostgreSQL
- **Cache**: Redis
- **Almacenamiento**: Google Cloud Storage
- **Monitoreo**: Google Cloud Monitoring

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

3. **Configurar Terraform (solo para el primer ambiente)**
   ```bash
   # Para cualquier ambiente (ej: prod)
   cp terraform/environments/prod/terraform.tfvars.example terraform/environments/prod/terraform.tfvars
   
   # Editar con tus valores
   nano terraform/environments/prod/terraform.tfvars
   ```

4. **Generar y configurar claves SSH**
   ```bash
   # Si no tienes claves SSH
   ssh-keygen -t rsa -b 4096 -C "consultoria@zentratek.com"
   
   # Agregar la clave pública a terraform.tfvars
   cat ~/.ssh/id_rsa.pub
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

# Verificar DNS y SSL
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

# Verificar DNS y SSL
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

# Verificar DNS y SSL
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

### Comandos de Despliegue Completo
```bash
make full-deploy-dev       # Despliegue completo DEV (automático)
make full-deploy-uat       # Despliegue completo UAT (con confirmaciones)
make full-deploy-prod      # Despliegue completo PROD (múltiples confirmaciones)
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
- **SSL**: Habilitado con Let's Encrypt
- **Debug**: Habilitado
- **Backups**: Deshabilitados
- **Recursos**: Mínimos (2 workers Gunicorn)
- **Usuario SSH**: `admin`
- **Generación de inventario**: Automática en cada despliegue
- **IP**: Dinámica (se obtiene automáticamente de Terraform)

### UAT
- **Dominio**: `uat-zentravision.zentratek.com`
- **SSL**: Habilitado con Let's Encrypt
- **Debug**: Deshabilitado
- **Backups**: Habilitados (15 días retención)
- **Recursos**: Medios (2 workers Gunicorn, timeouts 300s)
- **Usuario SSH**: `zentravision`
- **Generación de inventario**: Automática en cada despliegue
- **IP**: Dinámica (se obtiene automáticamente de Terraform)

### Producción (PROD)
- **Dominio**: Configurable via `DOMAIN_NAME`
- **SSL**: Habilitado con Let's Encrypt
- **Debug**: Deshabilitado
- **Backups**: Habilitados (30 días retención)
- **Recursos**: Optimizados para producción (3 workers, timeouts 300s)
- **Usuario SSH**: `admin`
- **Generación de inventario**: Automática en cada despliegue
- **IP**: Dinámica (se obtiene automáticamente de Terraform)
- **Confirmaciones**: Múltiples confirmaciones de seguridad

## 🔧 Configuración Avanzada

### Variables de Terraform

Edita `terraform/environments/{env}/terraform.tfvars`:

```hcl
# GCP Configuration
project_id = "zentraflow"
region     = "us-central1"
zone       = "us-central1-a"
environment = "prod"  # o "dev", "uat"

# Instance Configuration
machine_type = "e2-standard-2"  # Ajustar según necesidades
disk_size    = 20               # GB

# Domain Configuration
domain_name = "zentravision.zentratek.com"  # Tu dominio
admin_email = "consultoria@zentratek.com"

# SSH Configuration
admin_user = "admin"  # "zentravision" para UAT
ssh_public_key = "ssh-rsa AAAAB3N... tu-clave-publica"
ssh_source_ranges = ["TU_IP/32"]  # Restringir acceso SSH

# Backup Configuration
backup_retention_days = 30
```

### Sistema de Inventarios Dinámicos

Los inventarios de Ansible se generan automáticamente en cada despliegue:

#### ✅ Antes (Problemático - IP hardcodeada)
```yaml
zentravision:
  hosts:
    zentravision-uat:
      ansible_host: 34.58.128.35  # ❌ IP fija, se rompe al recrear
```

#### ✅ Ahora (Dinámico)
```bash
# El script obtiene la IP automáticamente de Terraform
INSTANCE_IP=$(terraform output -raw instance_ip)
# Y genera el inventario con la IP actual
```

#### Scripts de generación automática:
- **DEV**: `scripts/deploy/dev/generate-inventory-dev.sh`
- **UAT**: `scripts/deploy/uat/generate-inventory-uat.sh`
- **PROD**: `scripts/deploy/prod/generate-inventory-prod.sh`

### Variables de Ansible por Ambiente

Las variables se configuran automáticamente en `ansible/inventories/{env}/group_vars/all.yml`:

```yaml
# Performance Configuration (ejemplo para PROD)
gunicorn_workers: 3              # Número de workers
gunicorn_timeout: 300            # Timeout para procesamiento IA
nginx_max_body_size: "100M"     # Tamaño máximo de archivos
nginx_proxy_timeout: "300s"     # Timeout de proxy

# Security
ssl_enabled: true
firewall_enabled: true
fail2ban_enabled: true

# Application
django_create_superuser: true
django_superuser_username: admin
debug_mode: false                # Solo true en DEV
```

### 🔄 Flujo de IP Dinámica

1. **Terraform crea** la instancia con IP dinámica
2. **Script de generación** obtiene la IP: `terraform output -raw instance_ip`
3. **Inventario se genera** automáticamente con la IP actual
4. **Ansible se ejecuta** con el inventario dinámico
5. **DNS se configura** manualmente con la IP mostrada

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
make check-dns-dev      # Verifica DEV + DNS + SSL
make check-dns-uat      # Verifica UAT + DNS + SSL  
make check-dns         # Verifica PROD + DNS + SSL

# Health check de todos los ambientes
make health-check

# Ver IPs de todas las instancias
make show-ips

# Conectarse y verificar servicios
make ssh-dev           # SSH a DEV
make ssh-uat           # SSH a UAT  
make ssh               # SSH a PROD
sudo systemctl status zentravision nginx postgresql redis
```

### Logs de la aplicación
```bash
# En el servidor
tail -f /opt/zentravision/logs/zentravision.log

# Logs de sistema
journalctl -u zentravision -f
journalctl -u nginx -f
```

### Scripts de verificación automática
- **`scripts/deploy/dev/check-dns.sh`**: Verifica DNS y SSL para DEV
- **`scripts/deploy/uat/check-dns.sh`**: Verifica DNS y SSL para UAT  
- **`scripts/deploy/prod/check-dns.sh`**: Verifica DNS y SSL para PROD

### Métricas disponibles
- Estado de servicios (zentravision, nginx, postgresql, redis)
- Uso de CPU, memoria y disco
- Logs de errores de aplicación
- Respuesta HTTP de health check
- Verificación automática de DNS y SSL
- IPs dinámicas de todas las instancias

## 🗄️ Backups

### Backup automático
Los backups se ejecutan automáticamente vía cron en producción y UAT.

### Backup manual
```bash
# Ejecutar backup manual
./scripts/backup/manual-backup.sh

# En el servidor
sudo -u zentravision /opt/zentravision/backup-db.sh
```

### Restaurar backup
```bash
# Listar backups disponibles
gsutil ls gs://zentraflow-prod-backups/

# Descargar y restaurar
gsutil cp gs://zentraflow-prod-backups/zentravision_backup_YYYYMMDD_HHMMSS.sql.gz .
gunzip zentravision_backup_YYYYMMDD_HHMMSS.sql.gz
psql -h localhost -U zentravision zentravision < zentravision_backup_YYYYMMDD_HHMMSS.sql
```

## 🔄 Actualización de la Aplicación

### Actualización automática (solo aplicación, sin infraestructura)
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

# O paso a paso
make deploy-dev         # Solo la parte de Ansible para DEV
make deploy-uat         # Solo la parte de Ansible para UAT
make deploy             # Solo la parte de Ansible para PROD
```

### 🔄 Ventajas del Sistema Dinámico

1. **Sin IPs hardcodeadas**: Los inventarios se generan automáticamente
2. **Recreación sin problemas**: Destruir y recrear infraestructura funciona perfectamente
3. **DNS automático**: Scripts te dicen exactamente qué configurar
4. **Verificación integrada**: Comandos `check-dns-*` verifican todo
5. **Información clara**: Cada despliegue te muestra la IP actual

## 🐛 Troubleshooting

### Problemas comunes

1. **Error de autenticación de Google Cloud**
   ```bash
   gcloud auth revoke --all
   gcloud auth login
   gcloud auth application-default login
   gcloud config set project zentraflow
   ```

2. **Error de SSH**
   ```bash
   # Verificar que la clave pública esté en terraform.tfvars
   # Verificar que el firewall permita tu IP
   gcloud compute firewall-rules list --filter="name~ssh"
   
   # Generar inventario y obtener IP actual
   make show-ips
   ```

3. **Error de certificado SSL**
   ```bash
   # Los certificados pueden tardar 5-10 minutos en configurarse
   # Verificar logs de certbot
   make ssh-{env}  # ssh-dev, ssh-uat, o ssh
   sudo journalctl -u snap.certbot.renew.service -f
   
   # Verificar DNS primero
   make check-dns-{env}
   ```

4. **Error 502 Bad Gateway**
   ```bash
   # Verificar que Gunicorn esté ejecutándose
   make ssh-{env}
   sudo systemctl status zentravision
   tail -f /opt/zentravision/logs/zentravision.log
   
   # Verificar que el inventario sea correcto
   cat ansible/inventories/{env}/hosts.yml
   ```

5. **Error en la instalación de dependencias**
   ```bash
   # Reinstalar dependencias Python
   make ssh-{env}
   sudo -u zentravision /opt/zentravision/venv/bin/pip install -r /opt/zentravision/app/requirements.txt
   ```

6. **Inventario con IP incorrecta**
   ```bash
   # Regenerar inventario automáticamente
   ./scripts/deploy/{env}/generate-inventory-{env}.sh
   
   # O limpiar y regenerar todos
   make clean-inventories
   make deploy-{env}  # Regenera automáticamente
   ```

7. **DNS no resuelve**
   ```bash
   # Verificar configuración DNS
   make check-dns-{env}
   
   # Verificar IP actual de la instancia
   make show-ips
   
   # Configurar DNS manualmente con la IP mostrada
   ```

### Logs de diagnóstico
```bash
# Logs de startup de la instancia
make ssh-{env}
sudo cat /var/log/startup-script.log

# Ver información del último despliegue
cat .last-{env}-ip          # IP de DEV/UAT
cat .last-prod-deployment   # Información completa de PROD

# Logs de Terraform
cd terraform/environments/{env}
terraform show

# Estado de todos los ambientes
make health-check
```

### Scripts de recuperación
```bash
# Si perdiste la IP de una instancia
make show-ips

# Regenerar inventario para cualquier ambiente
./scripts/deploy/dev/generate-inventory-dev.sh
./scripts/deploy/uat/generate-inventory-uat.sh  
./scripts/deploy/prod/generate-inventory-prod.sh

# Verificar conectividad
make check-dns-dev
make check-dns-uat
make check-dns
```

## 🔒 Seguridad

### Configuración de seguridad incluida
- Firewall UFW configurado
- Fail2ban para protección SSH
- SSL/HTTPS automático con Let's Encrypt
- Acceso SSH restringido por IP
- Service Account con permisos mínimos
- Backups encriptados en Google Cloud Storage

### Recomendaciones adicionales
1. Cambiar la contraseña del admin por defecto
2. Configurar 2FA en Google Cloud Console
3. Revisar logs de seguridad regularmente
4. Mantener sistema actualizado
5. Restringir acceso SSH a IPs específicas

## 📝 Desarrollo

### Agregar nuevos ambientes
1. Crear directorio en `terraform/environments/nuevo-env/`
2. Copiar archivos de configuración de un ambiente existente
3. Crear script de generación de inventario en `scripts/deploy/nuevo-env/`
4. Agregar comandos al Makefile siguiendo el patrón existente

### Modificar configuración
1. **Infraestructura**: Editar archivos Terraform en `terraform/environments/{env}/`
2. **Aplicación**: Editar roles de Ansible en `ansible/roles/`
3. **Variables**: Editar archivos de variables en `ansible/inventories/{env}/group_vars/`
4. **Dominios**: Cambiar variables de entorno antes del despliegue

### Sistema de inventarios dinámicos
Los inventarios se generan automáticamente y **NO** deben editarse manualmente:

```bash
# ❌ NO hacer esto
nano ansible/inventories/uat/hosts.yml

# ✅ Hacer esto en su lugar
./scripts/deploy/uat/generate-inventory-uat.sh
# o simplemente
make deploy-uat  # Regenera automáticamente
```

### Flujo de desarrollo recomendado
1. **Desarrollar en DEV**: `make full-deploy-dev`
2. **Probar en UAT**: `make full-deploy-uat`  
3. **Promocionar a PROD**: `make full-deploy-prod`
4. **Actualizaciones rápidas**: `make update-app-{env}`

### Debugging del sistema dinámico
```bash
# Ver qué IPs están configuradas
make show-ips

# Verificar generación de inventarios
ls -la ansible/inventories/*/hosts.yml

# Limpiar y regenerar todo
make clean-inventories
make deploy-{env}
```

## 🆘 Soporte

### Enlaces útiles
- [Documentación de Terraform GCP](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Documentación de Ansible](https://docs.ansible.com/)
- [Google Cloud Console](https://console.cloud.google.com/)

### Información del proyecto
- **Proyecto GCP**: zentraflow
- **Repositorio aplicación**: https://github.com/jfbm74/zentravision.git
- **Repositorio infraestructura**: https://github.com/jfbm74/zentravision-infrastructure.git

### Dominios configurados
- **DEV**: `dev-zentravision.zentratek.com`
- **UAT**: `uat-zentravision.zentratek.com`  
- **PROD**: Configurable via `DOMAIN_NAME` (ej: `zentravision.zentratek.com`)

### Scripts clave
- **Inventarios dinámicos**: `scripts/deploy/{env}/generate-inventory-{env}.sh`
- **Verificación DNS**: `scripts/deploy/{env}/check-dns.sh`
- **Despliegue completo**: `scripts/deploy/{env}/deploy-{env}.sh`

---

**🔄 Nuevo Sistema de IPs Dinámicas**: Los inventarios se generan automáticamente en cada despliegue. ¡No más problemas con IPs hardcodeadas! 🚀