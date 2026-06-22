include ../../help.mk

.DEFAULT_GOAL := helpstack
STACK := rest

RUN_DEV := docker compose run --rm dev

install: .make/.install ## install the dependencies

.make/.install: image-dev Gemfile
	$(RUN_DEV) bundle install
	mkdir -p .make
	touch .make/.install

console: install ## start an interactive console
	$(RUN_DEV) irb

up: image-dev install ## start the REST API server
	docker compose up -d dev

status: ## check status of REST API server
	docker compose ps

down: ## stop the REST API server
	docker compose down

logs: ## show logs of REST API server
	docker compose logs -f || true

restart: down up ## restart the REST API server

test: image-dev ## run the REST API tests
	docker compose exec dev rspec spec

image-dev: .make/.image-dev ### Build docker image for development

.make/.image-dev: docker-bake.hcl Dockerfile.dev Gemfile Gemfile.lock config/puma.rb $(wildcard lib/***/*.rb) $(wildcard routes/**/*.rb)
	docker buildx bake development
	mkdir -p .make
	touch .make/.image-dev

shell: image-dev ### Start shell in development container
	$(RUN_DEV) bash

.PHONY: up test image-dev