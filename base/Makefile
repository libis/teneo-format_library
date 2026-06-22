include ../help.mk

.DEFAULT_GOAL := helpstack

.SILENT:

.make/.ruby: Dockerfile.ruby docker-bake.hcl
	docker buildx bake ruby_base
	mkdir -p .make
	touch .make/.ruby

.make/.gem: Dockerfile.gem docker-bake.hcl
	docker buildx bake gem_base
	mkdir -p .make
	touch .make/.gem

build: .make/.ruby .make/.gem ## Build the base docker images

.PHONY: build
