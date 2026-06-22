include ../help.mk

.DEFAULT_GOAL := helpstack

.SILENT:

.mk.ruby: Dockerfile.ruby docker-bake.hcl
	docker buildx bake ruby_base
	touch .mk.ruby

.mk.gem: Dockerfile.gem docker-bake.hcl
	docker buildx bake gem_base
	touch .mk.gem

build: .mk.ruby .mk.gem ## Build the base docker images

.PHONY: build
