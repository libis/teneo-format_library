include ../../help.mk

GEM_VERSION := $(shell ruby -e 'require_relative "../../gem/lib/teneo/format_library/version"; puts Teneo::FormatLibrary::VERSION')
export

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
	docker compose exec dev bundle exec rspec

openapi: image-dev ## generate OpenAPI spec by running the the REST API tests
	docker compose exec -e OPENAPI_FORMAT=yaml dev bundle exec rspec
	docker compose exec -e OPENAPI_FORMAT=json dev bundle exec rspec

image-dev: .make/.image-dev ### Build docker image for development

.make/.image-dev: docker-bake.hcl Dockerfile.dev
	docker buildx bake development
	mkdir -p .make
	touch .make/.image-dev

image-prod: .make/.image-prod ### Build docker image for production

SRC_FILES := Gemfile Gemfile.lock app.rb config.ru $(wildcard config/*.rb) $(wildcard lib/*.rb) $(wildcard routes/*.rb) $(wildcard serializers/*.rb) 

.make/.image-prod: docker-bake.hcl Dockerfile.prod .dockerignore $(SRC_FILES)
	cp ../../gem/teneo-format_library-$(GEM_VERSION).gem ./
	docker buildx bake production
	docker image push registry.docker.libis.be/teneo/format_library/api/rest:$(GEM_VERSION)
	mkdir -p .make
	touch .make/.image-prod

shell: image-dev ### Start shell in development container
	$(RUN_DEV) bash

.PHONY: up test image-dev