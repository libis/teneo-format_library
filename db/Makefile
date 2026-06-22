include ../help.mk

.DEFAULT_GOAL := helpstack
STACK := db

### Container actions

up: ## Start the database and pgadmin containers
	mkdir -p data/db/pgdata
	docker compose up -d

down: ## Stop the database and pgadmin containers
	docker compose down --remove-orphans

status: ## Show the status of the database containers
	docker compose ps

logs: ## Show the logs of the running containers
	docker compose logs -f || true

restart: down up ## Restart the database containers

### Data actions

clear: down ### Remove the database storage
	rm -fr data/db/pgdata

migrate: ### Create the database tables
	$(MAKE) -C ../gem migrate

seed: ### Populate the database
	$(MAKE) -C ../gem seed

reset: down clear up migrate seed ### Reset the database

.PHONY: base gem rest grpc
