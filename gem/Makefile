include ../help.mk

.DEFAULT_GOAL := helpstack
STACK := gem

GEM_VERSION := $(shell ruby -e 'require_relative "lib/teneo/format_library/version"; puts Teneo::FormatLibrary::VERSION')
export

GEM := teneo-format_library

.SILENT:

RUN_BUILD := docker compose run --rm -it build
RUN_TEST := docker compose run --rm -it test

### Gem actions

.mk.gem-build: install lib/**/*.rb Gemfile $(GEM).gemspec
	$(RUN_BUILD) gem build $(GEM).gemspec
	touch .mk.gem-build

build: .mk.gem-build ## Build the gem in the docker container

test: image-test build ## Run tests in the test container
	$(RUN_TEST) rspec

.mk.install: image-build Gemfile $(GEM).gemspec
	$(RUN_BUILD) bundle install
	touch .mk.install

install: .mk.install ## Install the gem dependencies

update: image-build ## Update the gem dependencies
	$(RUN_BUILD) bundle update --all

shell: image-build ## Open a shell in the build container
	$(RUN_BUILD) bash

test-shell: image-build ## Open a shell in the build container
	$(RUN_TEST) bash

release: ## Release a new gem version
	$(RUN_BUILD) bundle exec rake changelog
# 	$(RUN_BUILD) '(git commit -am "Version bump: v$(GEM_VERSION)" || true) && \
# 	(git tag --force "v$(GEM_VERSION)") && \
# 	(git push --force --tags) && \
# 	(bundle exec rake changelog) && \
# 	(git commit -a -m "Changelog update" || true) && \
# 	(git push --force) && \
# 	(bundle exec rake release)'

### Docker image actions

.mk.image_build: Dockerfile.build docker-bake.hcl
	docker buildx bake build
	touch .mk.image_build

image-build: .mk.image_build ### Build the docker image for building the gem

.mk.image_test: Dockerfile.test docker-bake.hcl Gemfile.test Rakefile.test spec/**/*.rb .mk.gem-build
	docker buildx bake test
	touch .mk.image_test

image-test: build .mk.image_test ### Build the docker image for building the gem

### Database actions

tasks:image-test build
	$(RUN_TEST) rake --tasks

migrate: image-test build ### Create the database tables
	$(RUN_TEST) rake teneo:format_library:migrate

seed: image-test build ### Seed the database with initial data
	$(RUN_TEST) rake teneo:format_library:seed

.PHONY: build test install update shell test-shell release image-build image-test migrate seed
