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
# COMANDOS DE MONITOREO - Agregar al final del Makefile
# ============================================================================

# Comandos de monitoreo
deploy-monitoring-dev: ## Desplegar solo monitoreo (DEV)
	@echo "🔄 Generando inventario dinámico para DEV..."
	./scripts/deploy/dev/generate-inventory-dev.sh
	@echo "📊 Desplegando monitoreo en DEV..."
	cd ansible && ansible-playbook -i inventories/dev playbooks/site.yml --tags monitoring

deploy-monitoring-uat: ## Desplegar solo monitoreo (UAT)
	@echo "🔄 Generando inventario dinámico para UAT..."
	./scripts/deploy/uat/generate-inventory-uat.sh
	@echo "📊 Desplegando monitoreo en UAT..."
	cd ansible && ansible-playbook -i inventories/uat playbooks/site.yml --tags monitoring

deploy-monitoring-prod: ## Desplegar solo monitoreo (PROD)
	@echo "⚠️  Desplegando monitoreo en PRODUCCIÓN"
	@echo "¿Continuar? (Ctrl+C para cancelar, Enter para continuar)"
	@read dummy
	@echo "🔄 Generando inventario dinámico para PROD..."
	./scripts/deploy/prod/generate-inventory-prod.sh
	@echo "📊 Desplegando monitoreo en PROD..."
	cd ansible && ansible-playbook -i inventories/prod playbooks/site.yml --tags monitoring

check-monitoring: ## Verificar estado del monitoreo
	@echo "🔍 Verificando servicios de monitoreo..."
	@ENV=${1:-dev}; \
	INSTANCE_IP=$$(cat .last-$$ENV-ip 2>/dev/null || echo ""); \
	if [ -z "$$INSTANCE_IP" ]; then \
		echo "❌ No se pudo obtener la IP de $$ENV"; \
		exit 1; \
	fi; \
	echo "📍 Verificando monitoreo en $$ENV ($$INSTANCE_IP)"; \
	ssh zentravision@$$INSTANCE_IP 'bash -s' << 'REMOTE_SCRIPT'
		echo "=== Servicios de Monitoreo ==="
		for service in grafana-agent node_exporter postgres_exporter redis_exporter; do
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
		echo "Node Exporter:"
		curl -s http://localhost:9100/metrics | head -3 || echo "❌ Error"
	REMOTE_SCRIPT

setup-grafana: ## Configurar monitoreo de Grafana Cloud
	@echo "Ambientes disponibles: dev, uat, prod"
	@read -p "¿Para qué ambiente? " env; \
	./scripts/monitoring/setup-grafana-monitoring.sh $$env

test-metrics-dev: ## Probar métricas en DEV
	@INSTANCE_IP=$$(cat .last-dev-ip 2>/dev/null || echo ""); \
	if [ -z "$$INSTANCE_IP" ]; then \
		echo "❌ No se pudo obtener IP de DEV"; \
		exit 1; \
	fi; \
	echo "🧪 Probando métricas en DEV ($$INSTANCE_IP)"; \
	echo "Django: $$(curl -s -o /dev/null -w '%{http_code}' http://dev-zentravision.zentratek.com/metrics/ || echo 'Error')"; \
	ssh zentravision@$$INSTANCE_IP 'curl -s http://localhost:9100/metrics | grep -c node_' 2>/dev/null && echo "✅ Node Exporter OK" || echo "❌ Node Exporter FAIL"

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
# Agregar al final del Makefile existente
# ============================================================================

# Configurar Grafana API Token
configure-grafana-dev: ## Configurar Grafana API Token para DEV
	./scripts/configure-grafana-token.sh zentraflow dev

configure-grafana-uat: ## Configurar Grafana API Token para UAT
	./scripts/configure-grafana-token.sh zentraflow uat

configure-grafana-prod: ## Configurar Grafana API Token para PROD
	./scripts/configure-grafana-token.sh zentraflow prod

# Verificar secrets existentes
check-secrets-dev: ## Verificar secrets de DEV
	@echo "🔍 Verificando secrets para DEV..."
	@echo "=================================="
	@gcloud secrets describe zentraflow-dev-django-secret >/dev/null 2>&1 && echo "✅ Django secret: OK" || echo "❌ Django secret: Missing"
	@gcloud secrets describe zentraflow-dev-db-password >/dev/null 2>&1 && echo "✅ DB password: OK" || echo "❌ DB password: Missing"
	@gcloud secrets describe zentraflow-dev-openai-key >/dev/null 2>&1 && echo "✅ OpenAI key: OK" || echo "❌ OpenAI key: Missing"
	@gcloud secrets describe zentraflow-dev-grafana-token >/dev/null 2>&1 && echo "✅ Grafana token: OK" || echo "❌ Grafana token: Missing"

check-secrets-uat: ## Verificar secrets de UAT
	@echo "🔍 Verificando secrets para UAT..."
	@echo "=================================="
	@gcloud secrets describe zentraflow-uat-django-secret >/dev/null 2>&1 && echo "✅ Django secret: OK" || echo "❌ Django secret: Missing"
	@gcloud secrets describe zentraflow-uat-db-password >/dev/null 2>&1 && echo "✅ DB password: OK" || echo "❌ DB password: Missing"
	@gcloud secrets describe zentraflow-uat-openai-key >/dev/null 2>&1 && echo "✅ OpenAI key: OK" || echo "❌ OpenAI key: Missing"
	@gcloud secrets describe zentraflow-uat-grafana-token >/dev/null 2>&1 && echo "✅ Grafana token: OK" || echo "❌ Grafana token: Missing"

check-secrets-prod: ## Verificar secrets de PROD
	@echo "🔍 Verificando secrets para PROD..."
	@echo "==================================="
	@gcloud secrets describe zentraflow-prod-django-secret >/dev/null 2>&1 && echo "✅ Django secret: OK" || echo "❌ Django secret: Missing"
	@gcloud secrets describe zentraflow-prod-db-password >/dev/null 2>&1 && echo "✅ DB password: OK" || echo "❌ DB password: Missing"
	@gcloud secrets describe zentraflow-prod-openai-key >/dev/null 2>&1 && echo "✅ OpenAI key: OK" || echo "❌ OpenAI key: Missing"
	@gcloud secrets describe zentraflow-prod-grafana-token >/dev/null 2>&1 && echo "✅ Grafana token: OK" || echo "❌ Grafana token: Missing"

# Comandos completos de despliegue con verificación de secrets
deploy-monitoring-dev-complete: ## Desplegar monitoreo DEV (con verificación de secrets)
	@echo "🔍 Verificando secrets antes del despliegue..."
	@make check-secrets-dev
	@echo ""
	@echo "¿Todos los secrets están OK? Si falta Grafana token, ejecuta 'make configure-grafana-dev' primero"
	@echo "¿Continuar con el despliegue? (y/N)"
	@read confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "🔄 Generando inventario dinámico para DEV..."
	./scripts/deploy/dev/generate-inventory-dev.sh
	@echo "📊 Desplegando monitoreo en DEV..."
	cd ansible && ansible-playbook -i inventories/dev playbooks/site.yml --tags monitoring

deploy-monitoring-uat-complete: ## Desplegar monitoreo UAT (con verificación de secrets)
	@echo "🔍 Verificando secrets antes del despliegue..."
	@make check-secrets-uat
	@echo ""
	@echo "¿Todos los secrets están OK? Si falta Grafana token, ejecuta 'make configure-grafana-uat' primero"
	@echo "¿Continuar con el despliegue? (y/N)"
	@read confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "🔄 Generando inventario dinámico para UAT..."
	./scripts/deploy/uat/generate-inventory-uat.sh
	@echo "📊 Desplegando monitoreo en UAT..."
	cd ansible && ansible-playbook -i inventories/uat playbooks/site.yml --tags monitoring

# Test de conectividad con Grafana Cloud
test-grafana-connectivity-dev: ## Test conectividad Grafana Cloud DEV
	@echo "🧪 Probando conectividad con Grafana Cloud (DEV)..."
	@TOKEN=$$(gcloud secrets versions access latest --secret="zentraflow-dev-grafana-token" 2>/dev/null || echo "ERROR"); \
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

# Setup completo de monitoreo
setup-monitoring-dev: ## Setup completo de monitoreo para DEV
	@echo "🚀 Setup completo de monitoreo para DEV"
	@echo "======================================="
	@echo "1. Verificando secrets existentes..."
	@make check-secrets-dev || true
	@echo ""
	@echo "2. ¿Necesitas configurar Grafana token? (y/N)"
	@read need_grafana && [ "$$need_grafana" = "y" ] && make configure-grafana-dev || true
	@echo ""
	@echo "3. Desplegando monitoreo..."
	@make deploy-monitoring-dev-complete

setup-monitoring-uat: ## Setup completo de monitoreo para UAT
	@echo "🚀 Setup completo de monitoreo para UAT"
	@echo "======================================="
	@echo "1. Verificando secrets existentes..."
	@make check-secrets-uat || true
	@echo ""
	@echo "2. ¿Necesitas configurar Grafana token? (y/N)"
	@read need_grafana && [ "$$need_grafana" = "y" ] && make configure-grafana-uat || true
	@echo ""
	@echo "3. Desplegando monitoreo..."
	@make deploy-monitoring-uat-complete

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
		echo "=== Estado del Servicio ==="
		sudo systemctl status grafana-agent
		echo ""
		echo "=== Últimos Logs ==="
		sudo journalctl -u grafana-agent --since "5 minutes ago" --no-pager
		echo ""
		echo "=== Test de Configuración ==="
		sudo /usr/local/bin/grafana-agent --config.file=/etc/grafana-agent/grafana-agent.yml --config.validate
	REMOTE_SCRIPT