include .env
-include .env.local
export

UID ?= $(shell id -u)
GID ?= $(shell id -g)

IMAGE_VERSION := $(shell ruby -e 'require_relative "lib/teneo/format_library/version"; puts Teneo::FormatLibrary::VERSION')

.SILENT:

install:
	docker compose run --rm db_tool bundle install

update:
	docker compose run --rm db_tool bundle update

release:
	git commit -am "Version bump: v$(IMAGE_VERSION)" || true
	git tag --force "v$(IMAGE_VERSION)"
	git push --force --tags
	bundle exec rake changelog
	git commit -a -m "Changelog update" || true
	git push --force
	bundle exec rake release

up:
	docker compose up -d

down:
	docker compose down

clear: down
	rm -fr db/data/pgdata/*

migrate: up
	docker compose run --rm db_tool rake teneo:format_library:migrate

seed: up
	docker compose run --rm db_tool rake teneo:format_library:seed

test: up
	docker compose run --rm db_tool rspec

tool: up
	docker compose run --rm db_tool bash

build_tool:
	docker compose build db_tool