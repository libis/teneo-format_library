include .env
-include .env.local
export

include help.mk

USER_ID ?= $(shell id -u)
GROUP_ID ?= $(shell id -g)

GEM_VERSION := $(shell ruby -e 'require_relative "lib/teneo/format_library/version"; puts Teneo::FormatLibrary::VERSION')

RUN_TOOL := docker compose --profile gem run --rm gem_tools
RUN_TEST := docker compose --profile gem run --rm gem_test

.SILENT:

### Gem actions

shell_tool:
	$(RUN_TOOL) bash

build: install ## Build the gem
	$(RUN_TOOL) gem build teneo-format_library.gemspec

release: build ## Build and release the gem
	$(RUN_TOOL) '(git commit -am "Version bump: v$(GEM_VERSION)" || true) && \
	(git tag --force "v$(GEM_VERSION)") && \
	(git push --force --tags) && \
	(bundle exec rake changelog) && \
	(git commit -a -m "Changelog update" || true) && \
	(git push --force) && \
	(bundle exec rake release)

install: ## Install the gem dependencies
	$(RUN_TOOL) bundle install

update: ## Update the gem dependencies
	$(RUN_TOOL) bundle update

### Gem actions that need the database

test: ## Run the test suite
	$(RUN_TOOL) rspec

console: ## Start a console with the gem loaded
	$(RUN_TOOL) irb -I lib -r teneo/format_library

### Docker container actions

up: ## Start the database and pgadmin containers
	mkdir -p data/db/pgdata
	docker compose up -d

down: ## Stop the database and pgadmin containers
	docker compose down

status: ## container status
	docker compose ps

logs: ## Show container logs
	docker compose logs -f || true

### Database actions

clear: down ## Remove the database storage
	rm -fr data/db/pgdata

migrate: ## Create the database tables - make sure the DB is running
	$(RUN_TOOL) rake teneo:format_library:migrate

seed: ## Populate the database - run migration first
	$(RUN_TOOL) rake teneo:format_library:seed

reset: down clear up migrate seed ## Reset the database
