SHELL         := /bin/bash
.SHELLFLAGS   := -eu -o pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS     += --no-print-directory

TF_DIR := terraform
ARGS   ?=

# Two root modules with separate states. foundation (networks, volumes, credentials) outlives
# platform (images, containers, bootstrap jobs), which reads it through terraform_remote_state.
LAYERS         := foundation platform
TF_FOUNDATION  := terraform -chdir=$(TF_DIR)/foundation
TF_PLATFORM    := terraform -chdir=$(TF_DIR)/platform

.PHONY: help init validate plan apply up destroy down nuke output credentials test fmt fmt-check lint pre-commit clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m [ARGS=\"...\"]\n\n"} \
		/^[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

## Terraform lifecycle

# ARGS is passed to every layer, so set variables with TF_VAR_<name> (ignored by the layer that
# does not declare it) rather than -var.

init: ## terraform init (both layers)
	@for l in $(LAYERS); do terraform -chdir=$(TF_DIR)/$$l init $(ARGS); done

validate: init ## terraform validate (both layers)
	@for l in $(LAYERS); do terraform -chdir=$(TF_DIR)/$$l validate; done

plan: init ## terraform plan (both layers; platform needs foundation applied first)
	@for l in $(LAYERS); do terraform -chdir=$(TF_DIR)/$$l plan $(ARGS); done

apply: init ## terraform apply, foundation then platform (ARGS=-auto-approve to skip prompts)
	@for l in $(LAYERS); do terraform -chdir=$(TF_DIR)/$$l apply $(ARGS); done

up: init ## Deploy the whole stack without prompting
	$(TF_FOUNDATION) apply -auto-approve $(ARGS)
	$(TF_PLATFORM) apply -auto-approve $(ARGS)

destroy: ## terraform destroy of the platform layer only (data is kept)
	$(TF_PLATFORM) destroy $(ARGS)

down: ## Tear down containers without prompting (volumes, networks, credentials are kept)
	$(TF_PLATFORM) destroy -auto-approve $(ARGS)

nuke: down ## Tear down everything, data included, without prompting
	$(TF_FOUNDATION) destroy -auto-approve $(ARGS)

output: ## terraform output of the platform layer (non-sensitive)
	$(TF_PLATFORM) output $(ARGS)

credentials: ## Print endpoints and credentials needed to test the stack
	@out=$$($(TF_PLATFORM) output -json); \
	if [ "$$out" = "{}" ]; then echo "No outputs in state — run 'make up' first." >&2; exit 1; fi; \
	jq -r ' \
		"MinIO", \
		"  API:            \(.minio.value.api_url)", \
		"  Console:        \(.minio.value.console_url)", \
		"  Root user:      \(.minio.value.root_user)", \
		"  Root password:  \(.minio_root_password.value)", \
		"  App user:       \(.minio.value.app_user)", \
		"  App password:   \(.minio_app_password.value)", \
		"  Buckets:        \(.minio.value.buckets | join(", "))", \
		"", \
		"PostgreSQL (\(.postgres.value.host_endpoint))", \
		(.postgres_passwords.value | to_entries[] | \
			"  \(.key | . + ":" | .[0:14] + (" " * (14 - length)))  \(.value)"), \
		"", \
		"Monitoring", \
		"  Prometheus:     \(.monitoring.value.prometheus_url)", \
		"  Grafana:        \(.monitoring.value.grafana_url)", \
		"  Grafana user:   \(.monitoring.value.grafana_user)", \
		"  Grafana pass:   \(.grafana_admin_password.value)" \
	' <<< "$$out"

test: ## Run the integration tests against the deployed stack
	./tests/run.sh

## Code quality

fmt: ## Format all Terraform files
	terraform -chdir=$(TF_DIR) fmt -recursive

fmt-check: ## Check Terraform formatting (CI-friendly)
	terraform -chdir=$(TF_DIR) fmt -recursive -check -diff

lint: fmt-check validate ## fmt check + validate + tflint
	tflint --chdir=$(TF_DIR) --config=$(CURDIR)/.tflint.hcl --init
	tflint --chdir=$(TF_DIR) --config=$(CURDIR)/.tflint.hcl --recursive

pre-commit: ## Run every pre-commit hook on all files
	pre-commit run --all-files

clean: ## Remove local .terraform dirs (keeps state)
	find $(TF_DIR) -type d -name .terraform -prune -exec rm -rf {} +
