include .env
-include .env.local
export

UID ?= $(shell id -u)
GID ?= $(shell id -g)

include help.mk

GEM_VERSION := $(shell ruby -e 'require_relative "gem/lib/teneo/format_library/version"; puts Teneo::FormatLibrary::VERSION')

.SILENT:

build: build-tools build-app ## Build the app and tools containers

### APP tasks

build-app: ## Build the app container
	docker compose build app

push: build ## Push the app image to the registry
	docker compose push app

app: build ## Run as shell in the app container
	docker compose run --rm app bash

### STACK tasks

status: ## Show the status of the services
	docker compose ps

up: ## Start the stack
	docker compose up -d

down: ## Stop the stack
	docker compose down

### DEVELOPMENT tasks

build-tools: ## Build the tools container
	docker compose build tools

clear: down ### Stop the services and remove the database data
	rm -fr db_data/db/pgdata

reset: clear up migrate seed ### Recreate the database to initial content

migrate: up ## Run the database migrations
	docker compose run --rm tools rake teneo:format_library:migrate

seed: up ## Run the database seeds
	docker compose run --rm tools rake teneo:format_library:seed

test: up ## Run the test suite
	docker compose run --rm tools rake spec

install: ## Install the gems in the tools container
	docker compose run --rm tools bundle install

update: ## Update the gems in the tools container
	docker compose run --rm tools bundle update

console: up ## Start a console in the tools container
	docker compose run --rm tools irb -I lib -r teneo/format_library

tools: up ## Run a shell in the tools container
	docker compose run --rm tools bash
