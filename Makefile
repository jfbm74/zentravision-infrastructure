.PHONY: help init plan apply destroy ssh init-dev plan-dev apply-dev deploy-dev destroy-dev ssh-dev

help: ## Mostrar ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Comandos para PRODUCCIÓN
init: ## Inicializar Terraform (PROD)
	cd terraform/environments/prod && terraform init

plan: ## Planear infraestructura (PROD)
	cd terraform/environments/prod && terraform plan

apply: ## Aplicar infraestructura (PROD)
	cd terraform/environments/prod && terraform apply

deploy: ## Configurar aplicación con Ansible (PROD)
	cd ansible && ansible-playbook -i inventories/prod playbooks/site.yml

destroy: ## Destruir infraestructura (PROD - CUIDADO)
	cd terraform/environments/prod && terraform destroy

ssh: ## Conectar por SSH a la instancia (PROD)
	@INSTANCE_IP=$$(cd terraform/environments/prod && terraform output -raw instance_ip 2>/dev/null || echo "No encontrado"); \
	if [ "$$INSTANCE_IP" != "No encontrado" ]; then \
		ssh admin@$$INSTANCE_IP; \
	else \
		echo "Primero ejecuta 'make apply' para crear la infraestructura"; \
	fi

# Comandos para DESARROLLO
init-dev: ## Inicializar Terraform (DEV)
	cd terraform/environments/dev && terraform init

plan-dev: ## Planear infraestructura (DEV)
	cd terraform/environments/dev && terraform plan

apply-dev: ## Aplicar infraestructura (DEV)
	cd terraform/environments/dev && terraform apply

deploy-dev: ## Configurar aplicación con Ansible (DEV)
	./scripts/deploy/dev/generate-inventory-dev.sh && cd ansible && ansible-playbook -i inventories/dev playbooks/site.yml

destroy-dev: ## Destruir infraestructura (DEV - CUIDADO)
	cd terraform/environments/dev && terraform destroy

ssh-dev: ## Conectar por SSH a la instancia (DEV)
	@INSTANCE_IP=$$(cd terraform/environments/dev && terraform output -raw instance_ip 2>/dev/null || echo "No encontrado"); \
	if [ "$$INSTANCE_IP" != "No encontrado" ]; then \
		ssh admin@$$INSTANCE_IP; \
	else \
		echo "Primero ejecuta 'make apply-dev' para crear la infraestructura"; \
	fi

# Comandos para UAT
init-uat: ## Inicializar Terraform (UAT)
	cd terraform/environments/uat && terraform init

plan-uat: ## Planear infraestructura (UAT)
	cd terraform/environments/uat && terraform plan

apply-uat: ## Aplicar infraestructura (UAT)
	cd terraform/environments/uat && terraform apply

deploy-uat: ## Configurar aplicación con Ansible (UAT)
	./scripts/deploy/uat/generate-inventory-uat.sh && cd ansible && ansible-playbook -i inventories/uat playbooks/site.yml

destroy-uat: ## Destruir infraestructura (UAT - CUIDADO)
	cd terraform/environments/uat && terraform destroy

ssh-uat: ## Conectar por SSH a la instancia (UAT)
	@INSTANCE_IP=$(cd terraform/environments/uat && terraform output -raw instance_ip 2>/dev/null || echo "No encontrado"); \
	if [ "$INSTANCE_IP" != "No encontrado" ]; then \
		ssh admin@$INSTANCE_IP; \
	else \
		echo "Primero ejecuta 'make apply-uat' para crear la infraestructura"; \
	fi

# Comandos generales
full-deploy-dev: ## Despliegue completo DEV
	./scripts/deploy/dev/deploy-dev.sh

full-deploy-uat: ## Despliegue completo UAT
	./scripts/deploy/uat/deploy-uat.sh