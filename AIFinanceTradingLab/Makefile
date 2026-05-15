.PHONY: xcode setup backend backend-docker backend-local clean

# ── Xcode Project ─────────────────────────────────────────────────────────────
xcode: ## Generate AIFinanceTradingLab.xcodeproj from project.yml using xcodegen
	@which xcodegen > /dev/null 2>&1 || (echo "Installing xcodegen via Homebrew..." && brew install xcodegen)
	xcodegen generate --spec project.yml
	@echo "✓ AIFinanceTradingLab.xcodeproj generated — open it in Xcode."
	open AIFinanceTradingLab.xcodeproj

# ── Backend (Docker) ──────────────────────────────────────────────────────────
backend-docker: ## Start all 13 microservices + Postgres + Redis via Docker Compose
	@cp -n backend/.env.example backend/.env 2>/dev/null || true
	@echo "Edit backend/.env and add ALPACA_API_KEY / ALPACA_API_SECRET before trading."
	docker compose -f backend/docker-compose.yml up --build

backend-docker-down: ## Stop Docker Compose services
	docker compose -f backend/docker-compose.yml down

# ── Backend (local, no Docker) ────────────────────────────────────────────────
backend-local: ## Start all services locally (requires Python 3.11 venv)
	@$(MAKE) _check-venv
	@cp -n backend/.env.example backend/.env 2>/dev/null || true
	@echo "Starting all services in background…"
	@cd backend && \
		(cd gateway-service       && uvicorn main:app --port 8000 --reload &) && \
		(cd market-data-service   && uvicorn main:app --port 8101 --reload &) && \
		(cd ai-research-service   && uvicorn main:app --port 8102 --reload &) && \
		(cd portfolio-service     && uvicorn main:app --port 8103 --reload &) && \
		(cd risk-service          && uvicorn main:app --port 8104 --reload &) && \
		(cd brokerage-service     && uvicorn main:app --port 8105 --reload &) && \
		(cd blockchain-service    && uvicorn main:app --port 8106 --reload &) && \
		(cd wallet-service        && uvicorn main:app --port 8107 --reload &) && \
		(cd compliance-service    && uvicorn main:app --port 8108 --reload &) && \
		(cd reporting-service     && uvicorn main:app --port 8109 --reload &) && \
		(cd social-intel-service  && uvicorn main:app --port 8110 --reload &)
	@echo "✓ All services started. Gateway at http://localhost:8000"
	@echo "  Stop all with: make backend-stop"

backend-stop: ## Kill all locally running uvicorn processes
	@pkill -f "uvicorn main:app" && echo "✓ Services stopped." || echo "No services running."

# ── Setup ─────────────────────────────────────────────────────────────────────
setup: ## Create Python venv and install backend dependencies
	python3 -m venv backend/.venv
	backend/.venv/bin/pip install --upgrade pip
	backend/.venv/bin/pip install -r backend/requirements.txt
	@echo "✓ Python venv ready at backend/.venv"
	@echo "  Activate with: source backend/.venv/bin/activate"

_check-venv:
	@test -d backend/.venv || (echo "Run 'make setup' first." && exit 1)

clean: ## Remove generated Xcode project and Python cache
	rm -rf AIFinanceTradingLab.xcodeproj
	find backend -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find backend -name "*.pyc" -delete 2>/dev/null || true
	rm -f backend/aifinance.db

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
