# ──────────────────────────────────────────────────────────────────────
# AIS Data Analytics Pipeline Makefile
# Run `make help` to see all available targets.
# ──────────────────────────────────────────────────────────────────────

SHELL := /bin/bash
.DEFAULT_GOAL := help

# ── Paths ─────────────────────────────────────────────────────────────
ROOT_DIR := $(shell pwd)
DBT_DIR  := $(ROOT_DIR)/ais_transformations

# ── Derived from .env ─────────────────────────────────────────────────
-include .env
export

# ── Colours ───────────────────────────────────────────────────────────
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m

# ======================================================================
#  SETUP
# ======================================================================

.PHONY: help
help: ## Show this help
	@printf "\n$(GREEN)AIS Data Analytics$(NC) — available targets:\n\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@printf "\n"

.PHONY: init
init: ## Create .env file from template
	@printf "$(GREEN)Initializing project...$(NC)\n"
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		printf "  ✓ Created .env from .env.example\n"; \
		printf "\n$(YELLOW)ACTION REQUIRED: Edit .env and fill in required values$(NC)\n\n"; \
	else \
		printf "  .env already exists (skipping)\n"; \
	fi
	@printf "$(GREEN)Init complete.$(NC)\n"

# ======================================================================
#  INFRASTRUCTURE
# ======================================================================

.PHONY: build
build: ## Build Docker images
	@printf "$(GREEN)Building Docker images...$(NC)\n"
	docker compose build
	@printf "$(GREEN)Build complete.$(NC)\n"

.PHONY: up
up: ## Start all services
	@printf "$(GREEN)Starting infrastructure...$(NC)\n"
	docker compose up -d
	@printf "\n$(GREEN)Services started.$(NC)\n"
	@printf "  ClickHouse:  http://localhost:8123\n"
	@printf "  Airflow:     http://localhost:8080\n"
	@printf "  Grafana:     http://localhost:3000\n\n"

.PHONY: down
down: ## Stop all services and remove volumes
	@printf "$(YELLOW)Stopping all services...$(NC)\n"
	docker compose down -v
	@printf "$(GREEN)Stopped.$(NC)\n"

# ======================================================================
#  DEPENDENCIES
# ======================================================================

.PHONY: deps
deps: ## Install Python dependencies
	@printf "$(GREEN)Installing dependencies...$(NC)\n"
	uv sync
	@printf "$(GREEN)Done.$(NC)\n"

# ======================================================================
#  STREAMING
# ======================================================================

.PHONY: producer
producer: ## Start AIS data producer
	@printf "$(GREEN)Starting producer...$(NC)\n"
	@printf "$(YELLOW)Press Ctrl+C to stop$(NC)\n\n"
	uv run python streaming/producer.py

# ======================================================================
#  CLICKHOUSE
# ======================================================================

.PHONY: check-clickhouse
check-clickhouse: ## Check ClickHouse data
	@printf "$(GREEN)Checking ClickHouse...$(NC)\n"
	@printf "  Connection: "
	@curl -s 'http://localhost:8123/' -u "$(CLICKHOUSE_USER):$(CLICKHOUSE_PASSWORD)" --data-binary "SELECT 1" > /dev/null && \
		printf "$(GREEN)✓$(NC)\n" || printf "$(RED)✗$(NC)\n"
	@printf "  Records: "
	@curl -s 'http://localhost:8123/' -u "$(CLICKHOUSE_USER):$(CLICKHOUSE_PASSWORD)" \
		--data-binary "SELECT count(*) FROM ais_db.position_reports"
	@printf "\n"

# ======================================================================
#  DBT
# ======================================================================

.PHONY: dbt-run
dbt-run: ## Run dbt transformations
	@printf "$(GREEN)Running dbt...$(NC)\n"
	cd $(DBT_DIR) && dbt run

# ======================================================================
#  AIRFLOW
# ======================================================================

.PHONY: airflow-ui
airflow-ui: ## Open Airflow UI
	@printf "$(GREEN)Airflow UI: http://localhost:8080$(NC)\n"
	@printf "  User: $(AIRFLOW_ADMIN_USERNAME) / Pass: $(AIRFLOW_ADMIN_PASSWORD)\n"

# ======================================================================
#  GRAFANA
# ======================================================================

.PHONY: grafana-ui
grafana-ui: ## Open Grafana UI
	@printf "$(GREEN)Grafana UI: http://localhost:3000$(NC)\n"
	@printf "  User: $(GRAFANA_USER) / Pass: $(GRAFANA_PASSWORD)\n"

# ======================================================================
#  STATUS & CLEANUP
# ======================================================================

.PHONY: status
status: ## Show system status
	@printf "$(GREEN)System Status$(NC)\n\n"
	@docker compose ps

.PHONY: clean
clean: down ## Stop services and clean artifacts
	rm -rf $(DBT_DIR)/target $(DBT_DIR)/dbt_packages $(DBT_DIR)/logs
	@printf "$(GREEN)Clean complete.$(NC)\n"
