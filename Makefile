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
	@INSTANCE_IP=$$(cd terraform/environments/dev && terraform output -raw instance_ip 2>/dev/null || echo "No encontrado"); \
	if [ "$$INSTANCE_IP" != "No encontrado" ]; then \
		ssh admin@$$INSTANCE_IP; \
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