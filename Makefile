SHELL         := /bin/bash
.SHELLFLAGS   := -eu -o pipefail -c
.DEFAULT_GOAL := help
MAKEFLAGS     += --no-print-directory

TF_DIR := terraform
TF     := terraform -chdir=$(TF_DIR)
ARGS   ?=

.PHONY: help init validate plan apply up destroy down output credentials fmt fmt-check lint pre-commit clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m [ARGS=\"...\"]\n\n"} \
		/^[a-zA-Z_-]+:.*##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

## Terraform lifecycle

init: ## terraform init
	$(TF) init $(ARGS)

validate: init ## terraform validate
	$(TF) validate

plan: init ## terraform plan
	$(TF) plan $(ARGS)

apply: init ## terraform apply (pass ARGS=-auto-approve to skip the prompt)
	$(TF) apply $(ARGS)

up: init ## Deploy the whole stack without prompting
	$(TF) apply -auto-approve $(ARGS)

destroy: ## terraform destroy
	$(TF) destroy $(ARGS)

down: ## Tear down the whole stack without prompting
	$(TF) destroy -auto-approve $(ARGS)

output: ## terraform output (non-sensitive)
	$(TF) output $(ARGS)

credentials: ## Print endpoints and credentials needed to test the stack
	@out=$$($(TF) output -json); \
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
			"  \(.key | . + ":" | .[0:14] + (" " * (14 - length)))  \(.value)") \
	' <<< "$$out"

## Code quality

fmt: ## Format all Terraform files
	$(TF) fmt -recursive

fmt-check: ## Check Terraform formatting (CI-friendly)
	$(TF) fmt -recursive -check -diff

lint: fmt-check validate ## fmt check + validate + tflint
	tflint --chdir=$(TF_DIR) --config=$(CURDIR)/.tflint.hcl --init
	tflint --chdir=$(TF_DIR) --config=$(CURDIR)/.tflint.hcl --recursive

pre-commit: ## Run every pre-commit hook on all files
	pre-commit run --all-files

clean: ## Remove local .terraform dirs (keeps state)
	find $(TF_DIR) -type d -name .terraform -prune -exec rm -rf {} +
