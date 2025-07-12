.PHONY: help init plan apply destroy ssh

help: ## Mostrar ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

init: ## Inicializar Terraform
	cd terraform/environments/prod && terraform init

plan: ## Planear infraestructura
	cd terraform/environments/prod && terraform plan

apply: ## Aplicar infraestructura
	cd terraform/environments/prod && terraform apply

deploy: ## Configurar aplicación con Ansible
	cd ansible && ansible-playbook -i inventories/prod playbooks/site.yml

destroy: ## Destruir infraestructura (CUIDADO)
	cd terraform/environments/prod && terraform destroy

ssh: ## Conectar por SSH a la instancia
	@INSTANCE_IP=$$(cd terraform/environments/prod && terraform output -raw instance_ip 2>/dev/null || echo "No encontrado"); \
	if [ "$$INSTANCE_IP" != "No encontrado" ]; then \
		ssh admin@$$INSTANCE_IP; \
	else \
		echo "Primero ejecuta 'make apply' para crear la infraestructura"; \
	fi
