.PHONY: help init plan apply destroy ssh init-dev plan-dev apply-dev deploy-dev destroy-dev ssh-dev init-uat plan-uat apply-uat deploy-uat destroy-uat ssh-uat

help: ## Mostrar ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# ============================================================================
# COMANDOS PARA DESARROLLO (DEV)
# ============================================================================
init-dev: ## Inicializar Terraform (DEV)
	cd terraform/environments/dev && terraform init

plan-dev: ## Planear infraestructura (DEV)
	cd terraform/environments/dev && terraform plan

apply-dev: ## Aplicar infraestructura (DEV)
	cd terraform/environments/dev && terraform apply

deploy-dev: ## Configurar aplicación con Ansible (DEV)
	@echo "🔄 Generando inventario dinámico para DEV..."
	./scripts/deploy/dev/generate-inventory-dev.sh
	@echo "⚙️  Ejecutando Ansible para DEV..."
	cd ansible && ansible-playbook -i inventories/dev playbooks/site.yml

destroy-dev: ## Destruir infraestructura (DEV - CUIDADO)
	cd terraform/environments/dev && terraform destroy

ssh-dev: ## Conectar por SSH a la instancia (DEV)
	@INSTANCE_IP=$(cd terraform/environments/dev && terraform output -raw instance_ip 2>/dev/null || echo "No encontrado"); \
	if [ "$INSTANCE_IP" != "No encontrado" ]; then \
		ssh zentravision@$INSTANCE_IP; \
	else \
		echo "Primero ejecuta 'make apply-dev' para crear la infraestructura"; \
	fi

check-dns-dev: ## Verificar configuración DNS (DEV)
	./scripts/deploy/dev/check-dns.sh

check-ssl-dev: ## Verificar y configurar SSL (DEV)
	./scripts/deploy/dev/check-dns.sh

# ============================================================================
# COMANDOS PARA UAT
# ============================================================================
init-uat: ## Inicializar Terraform (UAT)
	cd terraform/environments/uat && terraform init

plan-uat: ## Planear infraestructura (UAT)
	cd terraform/environments/uat && terraform plan

apply-uat: ## Aplicar infraestructura (UAT)
	cd terraform/environments/uat && terraform apply

deploy-uat: ## Configurar aplicación con Ansible (UAT)
	@echo "🔄 Generando inventario dinámico para UAT..."
	./scripts/deploy/uat/generate-inventory-uat.sh
	@echo "⚙️  Ejecutando Ansible para UAT..."
	cd ansible && ansible-playbook -i inventories/uat playbooks/site.yml

destroy-uat: ## Destruir infraestructura (UAT - CUIDADO)
	cd terraform/environments/uat && terraform destroy

ssh-uat: ## Conectar por SSH a la instancia (UAT)
	@INSTANCE_IP=$$(cd terraform/environments/uat && terraform output -raw instance_ip 2>/dev/null || echo "No encontrado"); \
	if [ "$$INSTANCE_IP" != "No encontrado" ]; then \
		ssh zentravision@$$INSTANCE_IP; \
	else \
		echo "Primero ejecuta 'make apply-uat' para crear la infraestructura"; \
	fi

check-dns-uat: ## Verificar configuración DNS (UAT)
	./scripts/deploy/uat/check-dns.sh

check-ssl-uat: ## Verificar y configurar SSL (UAT)
	./scripts/deploy/uat/check-ssl.sh

# ============================================================================
# COMANDOS PARA PRODUCCIÓN (PROD)
# ============================================================================
init: ## Inicializar Terraform (PROD)
	cd terraform/environments/prod && terraform init

plan: ## Planear infraestructura (PROD)
	cd terraform/environments/prod && terraform plan

apply: ## Aplicar infraestructura (PROD)
	@echo "⚠️  ADVERTENCIA: Vas a aplicar cambios en PRODUCCIÓN"
	@echo "¿Continuar? (Ctrl+C para cancelar, Enter para continuar)"
	@read dummy
	cd terraform/environments/prod && terraform apply

deploy: ## Configurar aplicación con Ansible (PROD)
	@echo "🔄 Generando inventario dinámico para PRODUCCIÓN..."
	./scripts/deploy/prod/generate-inventory-prod.sh
	@echo "⚙️  Ejecutando Ansible para PRODUCCIÓN..."
	cd ansible && ansible-playbook -i inventories/prod playbooks/site.yml

destroy: ## Destruir infraestructura (PROD - CUIDADO)
	@echo "🔴 PELIGRO: Vas a DESTRUIR la infraestructura de PRODUCCIÓN"
	@echo "Escribir 'DESTRUIR PRODUCCION' para confirmar:"
	@read confirmation; \
	if [ "$$confirmation" = "DESTRUIR PRODUCCION" ]; then \
		cd terraform/environments/prod && terraform destroy; \
	else \
		echo "❌ Operación cancelada"; \
	fi

ssh: ## Conectar por SSH a la instancia (PROD)
	@INSTANCE_IP=$$(cd terraform/environments/prod && terraform output -raw instance_ip 2>/dev/null || echo "No encontrado"); \
	if [ "$$INSTANCE_IP" != "No encontrado" ]; then \
		ssh admin@$$INSTANCE_IP; \
	else \
		echo "Primero ejecuta 'make apply' para crear la infraestructura"; \
	fi

check-dns: ## Verificar configuración DNS (PROD)
	./scripts/deploy/prod/check-dns.sh

check-ssl: ## Verificar y configurar SSL (PROD)
	./scripts/deploy/prod/check-dns.sh

# ============================================================================
# COMANDOS DE DESPLIEGUE COMPLETO (SIN DUPLICADOS)
# ============================================================================
full-deploy-dev: ## Despliegue completo DEV (automático)
	@echo "🚀 Iniciando despliegue completo DEV..."
	@export DOMAIN_NAME="dev-zentravision.zentratek.com" && \
	export ADMIN_EMAIL="consultoria@zentratek.com" && \
	export DJANGO_ADMIN_PASSWORD="DevPassword123!" && \
	./scripts/deploy/dev/deploy-dev.sh

full-deploy-uat: ## Despliegue completo UAT (con confirmaciones)
	@echo "🚀 Iniciando despliegue completo UAT..."
	./scripts/deploy/uat/deploy-uat.sh

full-deploy-prod: ## Despliegue completo PROD (con múltiples confirmaciones)
	@echo "🚀 Iniciando despliegue completo PRODUCCIÓN..."
	@echo "⚠️  Asegúrate de tener configuradas las variables:"
	@echo "   export DOMAIN_NAME='tu-dominio.com'"
	@echo "   export ADMIN_EMAIL='tu-email@dominio.com'"
	@echo "   export DJANGO_ADMIN_PASSWORD='TuPasswordSeguro123!'"
	@echo ""
	@echo "¿Continuar? (Ctrl+C para cancelar, Enter para continuar)"
	@read dummy
	./scripts/deploy/prod/deploy-prod.sh

# ============================================================================
# COMANDOS DE ACTUALIZACIÓN (solo aplicación, sin infraestructura)
# ============================================================================
update-app-dev: ## Actualizar solo la aplicación DEV
	./scripts/deploy/dev/generate-inventory-dev.sh
	cd ansible && ansible-playbook -i inventories/dev playbooks/deploy-app.yml

update-app-uat: ## Actualizar solo la aplicación UAT
	./scripts/deploy/uat/generate-inventory-uat.sh
	cd ansible && ansible-playbook -i inventories/uat playbooks/deploy-app.yml

update-app-prod: ## Actualizar solo la aplicación PROD
	@echo "⚠️  Vas a actualizar la aplicación en PRODUCCIÓN"
	@echo "¿Continuar? (Ctrl+C para cancelar, Enter para continuar)"
	@read dummy
	./scripts/deploy/prod/generate-inventory-prod.sh
	cd ansible && ansible-playbook -i inventories/prod playbooks/deploy-app.yml

# ============================================================================
# COMANDOS DE UTILIDAD
# ============================================================================
clean-inventories: ## Limpiar inventarios generados dinámicamente
	rm -f ansible/inventories/dev/hosts.yml
	rm -f ansible/inventories/uat/hosts.yml
	rm -f ansible/inventories/prod/hosts.yml
	@echo "✅ Inventarios limpiados"

show-ips: ## Mostrar IPs de todas las instancias
	@echo "📍 IPs de las instancias:"
	@echo "========================"
	@echo -n "DEV:  "; cd terraform/environments/dev && terraform output -raw instance_ip 2>/dev/null || echo "No desplegado"
	@echo -n "UAT:  "; cd terraform/environments/uat && terraform output -raw instance_ip 2>/dev/null || echo "No desplegado"
	@echo -n "PROD: "; cd terraform/environments/prod && terraform output -raw instance_ip 2>/dev/null || echo "No desplegado"

health-check: ## Verificar salud de todas las instancias
	@echo "🏥 Health Check - Todas las instancias"
	@echo "======================================"
	@./scripts/deploy/dev/check-dns.sh 2>/dev/null || echo "DEV: No desplegado"
	@echo ""
	@./scripts/deploy/uat/check-ssl.sh 2>/dev/null || echo "UAT: No desplegado"
	@echo ""
	@./scripts/deploy/prod/check-dns.sh 2>/dev/null || echo "PROD: No desplegado"

configure-openai: ## Configurar OpenAI API Key para un ambiente
	@echo "Ambientes disponibles: dev, uat, prod"
	@read -p "¿Para qué ambiente? " env; \
	./scripts/configure-openai-key.sh zentraflow $env

configure-ssl: ## Configurar SSL para un ambiente específico
	@echo "Ambientes disponibles: dev, uat, prod"
	@read -p "¿Para qué ambiente configurar SSL? " env; \
	if [ "$env" = "dev" ]; then ./scripts/deploy/dev/check-dns.sh; \
	elif [ "$env" = "uat" ]; then ./scripts/deploy/uat/check-ssl.sh; \
	elif [ "$env" = "prod" ]; then ./scripts/deploy/prod/check-dns.sh; \
	else echo "Ambiente no válido"; fi

# ============================================================================
# COMANDOS DE MONITOREO Y DJANGO METRICS (ACTUALIZADOS)
# ============================================================================

# Comandos de monitoreo completo (incluyendo Django metrics)
deploy-monitoring-dev: ## Desplegar monitoreo completo + Django metrics (DEV)
	@echo "📊 Desplegando monitoreo completo en DEV (incluyendo Django metrics)..."
	@echo "======================================================================"
	@echo "🔄 Generando inventario dinámico para DEV..."
	./scripts/deploy/dev/generate-inventory-dev.sh
	@echo "📊 Desplegando monitoreo + Django metrics en DEV..."
	cd ansible && ansible-playbook -i inventories/dev playbooks/site.yml --tags monitoring,django_metrics
	@echo ""
	@echo "✅ Despliegue completado. Verificando estado..."
	@make test-django-metrics-dev

deploy-monitoring-uat: ## Desplegar monitoreo completo + Django metrics (UAT)
	@echo "📊 Desplegando monitoreo completo en UAT (incluyendo Django metrics)..."
	@echo "======================================================================"
	@echo "🔄 Generando inventario dinámico para UAT..."
	./scripts/deploy/uat/generate-inventory-uat.sh
	@echo "📊 Desplegando monitoreo + Django metrics en UAT..."
	cd ansible && ansible-playbook -i inventories/uat playbooks/site.yml --tags monitoring,django_metrics
	@echo ""
	@echo "✅ Despliegue completado. Verificando estado..."
	@make test-django-metrics-uat

deploy-monitoring-prod: ## Desplegar monitoreo completo + Django metrics (PROD)
	@echo "⚠️  Desplegando monitoreo completo en PRODUCCIÓN (incluyendo Django metrics)"
	@echo "¿Continuar? (Ctrl+C para cancelar, Enter para continuar)"
	@read dummy
	@echo "🔄 Generando inventario dinámico para PROD..."
	./scripts/deploy/prod/generate-inventory-prod.sh
	@echo "📊 Desplegando monitoreo + Django metrics en PROD..."
	cd ansible && ansible-playbook -i inventories/prod playbooks/site.yml --tags monitoring,django_metrics
	@echo ""
	@echo "✅ Despliegue completado. Verificando estado..."
	@make test-django-metrics-prod

# Comandos específicos para Django metrics
deploy-django-metrics-dev: ## Desplegar solo Django metrics (DEV)
	@echo "🐍 Desplegando solo Django metrics en DEV..."
	@echo "============================================"
	./scripts/deploy/dev/generate-inventory-dev.sh
	cd ansible && ansible-playbook -i inventories/dev playbooks/site.yml --tags django_metrics
	@make test-django-metrics-dev

deploy-django-metrics-uat: ## Desplegar solo Django metrics (UAT)
	@echo "🐍 Desplegando solo Django metrics en UAT..."
	@echo "============================================"
	./scripts/deploy/uat/generate-inventory-uat.sh
	cd ansible && ansible-playbook -i inventories/uat playbooks/site.yml --tags django_metrics
	@make test-django-metrics-uat

deploy-django-metrics-prod: ## Desplegar solo Django metrics (PROD)
	@echo "⚠️  Desplegando Django metrics en PRODUCCIÓN"
	@echo "¿Continuar? (Ctrl+C para cancelar, Enter para continuar)"
	@read dummy
	@echo "🐍 Desplegando solo Django metrics en PROD..."
	./scripts/deploy/prod/generate-inventory-prod.sh
	cd ansible && ansible-playbook -i inventories/prod playbooks/site.yml --tags django_metrics
	@make test-django-metrics-prod

# Tests específicos de Django metrics
test-django-metrics-dev: ## Test Django metrics endpoint (DEV)
	@echo "🧪 Probando Django metrics en DEV..."
	@echo "===================================="
	@INSTANCE_IP=$$(cat .last-dev-ip 2>/dev/null || echo ""); \
	if [ -z "$$INSTANCE_IP" ]; then \
		echo "❌ No se pudo obtener IP de DEV"; \
		exit 1; \
	fi; \
	echo "📍 Testing en $$INSTANCE_IP"; \
	echo "Django metrics endpoint:"; \
	HTTP_CODE=$$(curl -s -o /dev/null -w '%{http_code}' http://dev-zentravision.zentratek.com/metrics/ 2>/dev/null || echo 'Error'); \
	if [ "$$HTTP_CODE" = "200" ]; then \
		echo "✅ Django metrics: HTTP $$HTTP_CODE"; \
		METRICS_COUNT=$$(curl -s http://dev-zentravision.zentratek.com/metrics/ 2>/dev/null | grep -c 'zentravision_' || echo '0'); \
		echo "📊 Métricas zentravision encontradas: $$METRICS_COUNT"; \
		curl -s http://dev-zentravision.zentratek.com/metrics/ 2>/dev/null | grep 'zentravision_' | head -3; \
	else \
		echo "❌ Django metrics: HTTP $$HTTP_CODE"; \
		echo "🔍 Testing endpoint interno..."; \
		ssh zentravision@$$INSTANCE_IP 'curl -s -o /dev/null -w "Internal HTTP: %{http_code}\n" http://localhost:8000/metrics/' 2>/dev/null || echo "Error en test interno"; \
	fi

test-django-metrics-uat: ## Test Django metrics endpoint (UAT)
	@echo "🧪 Probando Django metrics en UAT..."
	@echo "===================================="
	@INSTANCE_IP=$$(cat .last-uat-ip 2>/dev/null || echo ""); \
	if [ -z "$$INSTANCE_IP" ]; then \
		echo "❌ No se pudo obtener IP de UAT"; \
		exit 1; \
	fi; \
	echo "📍 Testing en $$INSTANCE_IP"; \
	ssh zentravision@$$INSTANCE_IP 'bash -s' << 'REMOTE_SCRIPT'
		echo "Django metrics (local):"
		HTTP_CODE=$$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/metrics/)
		if [ "$$HTTP_CODE" = "200" ]; then
			echo "✅ Django metrics: HTTP $$HTTP_CODE"
			METRICS_COUNT=$$(curl -s http://localhost:8000/metrics/ | grep -c 'zentravision_')
			echo "📊 Métricas zentravision: $$METRICS_COUNT"
			curl -s http://localhost:8000/metrics/ | grep 'zentravision_' | head -3
		else
			echo "❌ Django metrics: HTTP $$HTTP_CODE"
		fi
	REMOTE_SCRIPT

test-django-metrics-prod: ## Test Django metrics endpoint (PROD)
	@echo "🧪 Probando Django metrics en PROD..."
	@echo "====================================="
	@INSTANCE_IP=$$(cd terraform/environments/prod && terraform output -raw instance_ip 2>/dev/null || echo "No encontrado"); \
	if [ "$$INSTANCE_IP" = "No encontrado" ]; then \
		echo "❌ No se pudo obtener IP de PROD"; \
		exit 1; \
	fi; \
	echo "📍 Testing en $$INSTANCE_IP"; \
	ssh admin@$$INSTANCE_IP 'bash -s' << 'REMOTE_SCRIPT'
		echo "Django metrics (local):"
		HTTP_CODE=$$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/metrics/)
		if [ "$$HTTP_CODE" = "200" ]; then
			echo "✅ Django metrics: HTTP $$HTTP_CODE"
			METRICS_COUNT=$$(curl -s http://localhost:8000/metrics/ | grep -c 'zentravision_')
			echo "📊 Métricas zentravision: $$METRICS_COUNT"
			curl -s http://localhost:8000/metrics/ | grep 'zentravision_' | head -3
		else
			echo "❌ Django metrics: HTTP $$HTTP_CODE"
		fi
	REMOTE_SCRIPT

check-monitoring: ## Verificar estado del monitoreo completo
	@echo "🔍 Verificando servicios de monitoreo completo..."
	@ENV=${1:-dev}; \
	INSTANCE_IP=$$(cat .last-$$ENV-ip 2>/dev/null || echo ""); \
	if [ -z "$$INSTANCE_IP" ]; then \
		echo "❌ No se pudo obtener la IP de $$ENV"; \
		exit 1; \
	fi; \
	echo "📍 Verificando monitoreo completo en $$ENV ($$INSTANCE_IP)"; \
	ssh zentravision@$$INSTANCE_IP 'bash -s' << 'REMOTE_SCRIPT'
		echo "=== Servicios de Monitoreo ==="
		for service in grafana-agent node_exporter postgres_exporter redis_exporter nginx_exporter; do
			if systemctl is-active --quiet $$service 2>/dev/null; then
				echo "✅ $$service: Activo"
			else
				echo "❌ $$service: Inactivo"
			fi
		done
		echo ""
		echo "=== Test de Métricas ==="
		echo "Django Metrics:"
		curl -s http://localhost:8000/metrics/ | head -3 || echo "❌ Error"
		echo ""
		echo "Node Exporter:"
		curl -s http://localhost:9100/metrics | head -3 || echo "❌ Error"
		echo ""
		echo "Grafana Agent:"
		curl -s http://localhost:12345/metrics | head -3 || echo "❌ Error"
	REMOTE_SCRIPT

setup-grafana: ## Configurar monitoreo de Grafana Cloud
	@echo "Ambientes disponibles: dev, uat, prod"
	@read -p "¿Para qué ambiente? " env; \
	./scripts/monitoring/setup-grafana-monitoring.sh $$env

logs-monitoring-dev: ## Ver logs de monitoreo en DEV
	@INSTANCE_IP=$$(cat .last-dev-ip 2>/dev/null || echo ""); \
	if [ -z "$$INSTANCE_IP" ]; then \
		echo "❌ No se pudo obtener IP de DEV"; \
		exit 1; \
	fi; \
	ssh zentravision@$$INSTANCE_IP 'sudo journalctl -u grafana-agent -f'

logs-monitoring-uat: ## Ver logs de monitoreo en UAT
	@INSTANCE_IP=$$(cat .last-uat-ip 2>/dev/null || echo ""); \
	if [ -z "$$INSTANCE_IP" ]; then \
		echo "❌ No se pudo obtener IP de UAT"; \
		exit 1; \
	fi; \
	ssh zentravision@$$INSTANCE_IP 'sudo journalctl -u grafana-agent -f'

# ============================================================================
# COMANDOS DE MONITOREO CON GOOGLE SECRET MANAGER
# ============================================================================

# Configurar Grafana API Token
configure-grafana-dev: ## Configurar Grafana API Token para DEV
	./scripts/configure-grafana-token.sh zentravision dev

configure-grafana-uat: ## Configurar Grafana API Token para UAT
	./scripts/configure-grafana-token.sh zentravision uat

configure-grafana-prod: ## Configurar Grafana API Token para PROD
	./scripts/configure-grafana-token.sh zentravision prod

# Verificar secrets existentes
check-secrets-dev: ## Verificar secrets de DEV
	@echo "🔍 Verificando secrets para DEV..."
	@echo "=================================="
	@gcloud secrets describe zentravision-dev-django-secret >/dev/null 2>&1 && echo "✅ Django secret: OK" || echo "❌ Django secret: Missing"
	@gcloud secrets describe zentravision-dev-db-password >/dev/null 2>&1 && echo "✅ DB password: OK" || echo "❌ DB password: Missing"
	@gcloud secrets describe zentravision-dev-openai-key >/dev/null 2>&1 && echo "✅ OpenAI key: OK" || echo "❌ OpenAI key: Missing"
	@gcloud secrets describe zentravision-dev-grafana-token >/dev/null 2>&1 && echo "✅ Grafana token: OK" || echo "❌ Grafana token: Missing"

check-secrets-uat: ## Verificar secrets de UAT
	@echo "🔍 Verificando secrets para UAT..."
	@echo "=================================="
	@gcloud secrets describe zentravision-uat-django-secret >/dev/null 2>&1 && echo "✅ Django secret: OK" || echo "❌ Django secret: Missing"
	@gcloud secrets describe zentravision-uat-db-password >/dev/null 2>&1 && echo "✅ DB password: OK" || echo "❌ DB password: Missing"
	@gcloud secrets describe zentravision-uat-openai-key >/dev/null 2>&1 && echo "✅ OpenAI key: OK" || echo "❌ OpenAI key: Missing"
	@gcloud secrets describe zentravision-uat-grafana-token >/dev/null 2>&1 && echo "✅ Grafana token: OK" || echo "❌ Grafana token: Missing"

check-secrets-prod: ## Verificar secrets de PROD
	@echo "🔍 Verificando secrets para PROD..."
	@echo "==================================="
	@gcloud secrets describe zentravision-prod-django-secret >/dev/null 2>&1 && echo "✅ Django secret: OK" || echo "❌ Django secret: Missing"
	@gcloud secrets describe zentravision-prod-db-password >/dev/null 2>&1 && echo "✅ DB password: OK" || echo "❌ DB password: Missing"
	@gcloud secrets describe zentravision-prod-openai-key >/dev/null 2>&1 && echo "✅ OpenAI key: OK" || echo "❌ OpenAI key: Missing"
	@gcloud secrets describe zentravision-prod-grafana-token >/dev/null 2>&1 && echo "✅ Grafana token: OK" || echo "❌ Grafana token: Missing"

# Comandos completos de despliegue con verificación de secrets
deploy-monitoring-dev-complete: ## Desplegar monitoreo completo DEV (con verificación de secrets)
	@echo "🔍 Verificando secrets antes del despliegue..."
	@make check-secrets-dev
	@echo ""
	@echo "¿Todos los secrets están OK? Si falta Grafana token, ejecuta 'make configure-grafana-dev' primero"
	@echo "¿Continuar con el despliegue? (y/N)"
	@read confirm && [ "$$confirm" = "y" ] || exit 1
	@make deploy-monitoring-dev

deploy-monitoring-uat-complete: ## Desplegar monitoreo completo UAT (con verificación de secrets)
	@echo "🔍 Verificando secrets antes del despliegue..."
	@make check-secrets-uat
	@echo ""
	@echo "¿Todos los secrets están OK? Si falta Grafana token, ejecuta 'make configure-grafana-uat' primero"
	@echo "¿Continuar con el despliegue? (y/N)"
	@read confirm && [ "$$confirm" = "y" ] || exit 1
	@make deploy-monitoring-uat

# Test de conectividad con Grafana Cloud
test-grafana-connectivity-dev: ## Test conectividad Grafana Cloud DEV
	@echo "🧪 Probando conectividad con Grafana Cloud (DEV)..."
	@TOKEN=$$(gcloud secrets versions access latest --secret="zentravision-dev-grafana-token" 2>/dev/null || echo "ERROR"); \
	if [ "$$TOKEN" = "ERROR" ]; then \
		echo "❌ No se pudo obtener token de Grafana. Ejecuta: make configure-grafana-dev"; \
		exit 1; \
	fi; \
	curl -s -o /dev/null -w "Status: %{http_code}\n" \
		-X POST \
		-H "Authorization: Basic $$(echo -n "2353449:$$TOKEN" | base64)" \
		-H "Content-Type: application/x-protobuf" \
		--data "" \
		"https://prometheus-prod-56-prod-us-east-2.grafana.net/api/prom/push" || echo "Test completado"

# Setup completo de monitoreo (incluyendo Django metrics)
setup-monitoring-dev: ## Setup completo de monitoreo + Django metrics para DEV
	@echo "🚀 Setup completo de monitoreo + Django metrics para DEV"
	@echo "========================================================"
	@echo "1. Verificando secrets existentes..."
	@make check-secrets-dev || true
	@echo ""
	@echo "2. ¿Necesitas configurar Grafana token? (y/N)"
	@read need_grafana && [ "$$need_grafana" = "y" ] && make configure-grafana-dev || true
	@echo ""
	@echo "3. Desplegando monitoreo completo + Django metrics..."
	@make deploy-monitoring-dev

setup-monitoring-uat: ## Setup completo de monitoreo + Django metrics para UAT
	@echo "🚀 Setup completo de monitoreo + Django metrics para UAT"
	@echo "========================================================"
	@echo "1. Verificando secrets existentes..."
	@make check-secrets-uat || true
	@echo ""
	@echo "2. ¿Necesitas configurar Grafana token? (y/N)"
	@read need_grafana && [ "$$need_grafana" = "y" ] && make configure-grafana-uat || true
	@echo ""
	@echo "3. Desplegando monitoreo completo + Django metrics..."
	@make deploy-monitoring-uat

# Troubleshooting
debug-grafana-config-dev: ## Debug configuración Grafana DEV
	@INSTANCE_IP=$$(cat .last-dev-ip 2>/dev/null || echo ""); \
	if [ -z "$$INSTANCE_IP" ]; then \
		echo "❌ No se pudo obtener IP de DEV"; \
		exit 1; \
	fi; \
	echo "🔍 Debugging Grafana Agent en DEV ($$INSTANCE_IP)"; \
	ssh zentravision@$$INSTANCE_IP 'bash -s' << 'REMOTE_SCRIPT'
		echo "=== Configuración Grafana Agent ==="
		sudo cat /etc/grafana-agent/grafana-agent.yml | head -20
		echo ""
		echo "=== Jobs Configurados ==="
		sudo cat /etc/grafana-agent/grafana-agent.yml | grep -A 2 "job_name:"
		echo ""
		echo "=== Estado del Servicio ==="
		sudo systemctl status grafana-agent
		echo ""
		echo "=== Últimos Logs ==="
		sudo journalctl -u grafana-agent --since "5 minutes ago" --no-pager
	REMOTE_SCRIPT

debug-django-metrics-dev: ## Debug Django metrics DEV
	@INSTANCE_IP=$$(cat .last-dev-ip 2>/dev/null || echo ""); \
	if [ -z "$$INSTANCE_IP" ]; then \
		echo "❌ No se pudo obtener IP de DEV"; \
		exit 1; \
	fi; \
	echo "🔍 Debugging Django metrics en DEV ($$INSTANCE_IP)"; \
	ssh zentravision@$$INSTANCE_IP 'bash -s' << 'REMOTE_SCRIPT'
		echo "=== Django Metrics Test ==="
		curl -v http://localhost:8000/metrics/ || echo "Error en endpoint"
		echo ""
		echo "=== Django URLs Configuration ==="
		find /opt/zentravision/app -name "urls.py" -exec grep -l "metrics" {} \; | head -2
		echo ""
		echo "=== Metrics Views File ==="
		ls -la /opt/zentravision/app/metrics_views.py 2>/dev/null || echo "metrics_views.py no encontrado"
		echo ""
		echo "=== Django Processes ==="
		ps aux | grep python | grep zentravision | grep -v grep
		echo ""
		echo "=== Django Service Status ==="
		sudo systemctl status gunicorn 2>/dev/null || sudo supervisorctl status 2>/dev/null || echo "No service found"
	REMOTE_SCRIPT

# Resumen de estado completo
status-monitoring-dev: ## Status completo del monitoreo DEV
	@echo "📊 Estado Completo del Monitoreo - DEV"
	@echo "======================================"
	@echo "1. Secrets:"
	@make check-secrets-dev
	@echo ""
	@echo "2. Servicios:"
	@make check-monitoring
	@echo ""
	@echo "3. Django Metrics:"
	@make test-django-metrics-dev
	@echo ""
	@echo "4. Grafana Cloud:"
	@make test-grafana-connectivity-dev