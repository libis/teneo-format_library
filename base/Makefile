include ../help.mk

.DEFAULT_GOAL := helpstack

.SILENT:

build: ## Build the base docker images
	docker buildx bake all

.PHONY: build
