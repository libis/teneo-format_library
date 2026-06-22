define help-targets
	awk -F ':|## ' '/^[^\t]+\s*:[^#]*## / {printf "    \033[36m%-30s\033[0m %s\n", $$1, $$NF}' $(1)
endef

define help-stacks
	awk -F ':|#s# ' '/^[^\t]+\s*:[^#]*#s# / {printf "    \033[36m%-30s\033[0m %s\n", $$1, $$NF}' $(1)
endef

define help-admins
	awk -F ':|### ' '/^[^\t]+\s*:[^#]*### / {printf "  * \033[36m%-30s\033[0m %s\n", $$1, $$NF}' $(1)
endef

define HELPTEXT

usage: make $(STACK) <command>

endef

define STACKTEXT

usage: make <stack> <command>

stacks:

endef

define ADMINTEXT

Note: Administrative tasks are indicated with an '*' in front of them. These tasks are intended
      for trouble shooting. Do not run them unless you undestand the task action and its impact.
endef

.SILENT:
MAKEFLAGS += --no-print-directory

# task comments starting with double # will be part of the help list
# task comments starting with triple # will be part of the help_admin list

helpstack: # Show list of targets
	@echo "$$HELPTEXT"
	$(call help-targets, $(MAKEFILE_LIST))
	$(call help-admins, $(MAKEFILE_LIST))
	@echo "$$ADMINTEXT"

helpmain: # Show list of stacks
	@echo "$$STACKTEXT"
	$(call help-stacks, $(MAKEFILE_LIST))
	$(call help-targets, $(MAKEFILE_LIST))
