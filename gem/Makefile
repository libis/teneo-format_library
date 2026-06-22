sinclude ../help.mk

.DEFAULT_GOAL := helpstack
STACK := gem

GEM_VERSION := $(shell ruby -e 'require_relative "lib/teneo/format_library/version"; puts Teneo::FormatLibrary::VERSION')
export

GEM := teneo-format_library

.SILENT:

RUN_BUILD := docker compose run --rm -it build
RUN_TEST := docker compose run --rm -it test

### Gem actions

build: .make/.gem-build ## Build the gem in the docker container

.make/.gem-build: install Gemfile $(GEM).gemspec $(wildcard lib/**/*.rb)
	$(RUN_BUILD) gem build $(GEM).gemspec
	mkdir -p .make
	touch .make/.gem-build

test: image-test build ## Run tests in the test container
	$(RUN_TEST) rspec

console: image-test ## Run an interactive console
	$(RUN_BUILD) irb -I lib -r teneo/format_library

install: .make/.install ## Install the gem dependencies

.make/.install: image-build Gemfile $(GEM).gemspec
	$(RUN_BUILD) bundle install
	mkdir -p .make
	touch .make/.install

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

image-build: .make/.image_build ### Build the docker image for building the gem

.make/.image_build: Dockerfile.build docker-bake.hcl
	docker buildx bake build
	mkdir -p .make
	touch .make/.image_build

image-test: build .make/.image_test ### Build the docker image for building the gem

.make/.image_test: Dockerfile.test docker-bake.hcl Gemfile.test Rakefile.test $(wildcard spec/**/*.rb) .make/.gem-build
	docker buildx bake test
	mkdir -p .make
	touch .make/.image_test

### Database actions

tasks:image-test build
	$(RUN_TEST) rake --tasks

migrate: image-test build ### Create the database tables
	$(RUN_TEST) rake teneo:format_library:migrate

seed: image-test build ### Seed the database with initial data
	$(RUN_TEST) rake teneo:format_library:seed

.PHONY: build test install update shell test-shell release image-build image-test migrate seed
