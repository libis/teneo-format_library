include .env
-include .env.local
export

include help.mk

.DEFAULT_GOAL := helpmain

USER_ID ?= $(shell id -u)
GROUP_ID ?= $(shell id -g)

### Stacks

db: #s# All DB related targets
	$(MAKE) -C db $(filter-out $@,$(MAKECMDGOALS))

base: #s# All Base related targets
	$(MAKE) -C base $(filter-out $@,$(MAKECMDGOALS))

gem: #s# All GEM related targets
	$(MAKE) -C gem $(filter-out $@,$(MAKECMDGOALS))

rest: #s# All REST API related targets
	$(MAKE) -C api/rest $(filter-out $@,$(MAKECMDGOALS))
	
grpc: #s# All gRPC related targets
	$(MAKE) -C api/grpc $(filter-out $@,$(MAKECMDGOALS))

%: # dummy target to 'eat' the remaining goals and do nothing
	@true

.PHONY: db base gem rest grpc
