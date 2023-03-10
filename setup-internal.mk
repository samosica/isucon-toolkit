# TODO: disable AppArmor
# TODO: add symbolic links to MySQL and Nginx config
# TODO: modify /etc/hosts (?)

MAKEFILE_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

include $(MAKEFILE_DIR)/env.sh

define REQUIRED_ENVVARS :=
GIT_EMAIL
GIT_USERNAME
REPO_DIR
endef

define definedcheck
$(eval undefine missing_vars)
$(foreach v,$(1),$(if $($(v)),,$(eval missing_vars += $(v))))
$(if $(missing_vars),$(error [error] unset variables: $(missing_vars); see $(MAKEFILE_DIR)/env.sh),)
endef

$(call definedcheck,$(REQUIRED_ENVVARS))

# In some environments, $HOME is not /home/user
HOME := /home/$(USER)

ifneq ($(wildcard $(HOME)/.setup-lock),)
$(error [error] setup has been done; if you would like to set up again, remove $(HOME)/.setup-lock)
endif

.PHONY: place-files
place-files: ## Place scripts and config files
	cp $(MAKEFILE_DIR)/env.sh $(HOME)/
	cp -r $(MAKEFILE_DIR)/alp $(HOME)/
	cp $(MAKEFILE_DIR)/toolkit.mk $(HOME)/Makefile
	cp $(MAKEFILE_DIR)/sync-all.sh $(HOME)/
	cp $(MAKEFILE_DIR)/sync.sh $(HOME)/

.PHONY: install-tools
install-tools: ## Install tools
	$(eval tmpdir := $(shell mktemp -d))

# shell function does not start a new shell without `sh -c`
# https://stackoverflow.com/questions/12989869/calling-command-v-find-from-gnu-makefile
ifeq ($(shell sh -c "command -v pt-query-digest"),)
	sudo apt install -y percona-toolkit
endif

ifeq ($(shell sh -c "command -v alp"),)
	cd $(tmpdir) && \
	curl -LO https://github.com/tkuchiki/alp/releases/download/v1.0.11/alp_linux_amd64.tar.gz && \
	tar xf alp_linux_amd64.tar.gz && \
	sudo install alp /usr/local/bin
endif

ifeq ($(shell sh -c "command -v notify_slack"),)
	cd $(tmpdir) && \
	curl -LO https://github.com/catatsuy/notify_slack/releases/download/v0.4.13/notify_slack-linux-amd64.tar.gz && \
	tar xf notify_slack-linux-amd64.tar.gz && \
	sudo install notify_slack /usr/local/bin
endif

ifeq ($(shell sh -c "command -v unzip"),)
	sudo apt install -y unzip
endif

ifeq ($(shell sh -c "command -v dsq"),)
	$(eval version := v0.22.0)
	$(eval file := dsq-$(shell uname -s | awk '{ print tolower($$0) }')-x64-$(version).zip)
	cd $(tmpdir) && \
	curl -LO "https://github.com/multiprocessio/dsq/releases/download/$(version)/$(file)" && \
	unzip $(file) && \
	sudo install dsq /usr/local/bin
endif

	rm -r $(tmpdir)

.PHONY: git-setup
git-setup: ## Configure Git
	git config --global user.email $(GIT_EMAIL)
	git config --global user.name $(GIT_USERNAME)
# Older versions of Git do not use main branch in default
# TODO: (re)move?
# ifeq ($(wildcard $(REPO_DIR)/.git),)
# 	cd $(REPO_DIR) && \
# 	git init --initial-branch=main && \
# 	git remote add origin git@github.com:$(GITHUB_REPO).git && \
# 	git fetch && \
# 	git reset --hard origin/main && \
# 	git branch --set-upstream-to=origin/main
# else
# 	$(info [info] $(REPO_DIR) is already git-controlled; do nothing)
# endif

.PHONY: ssh-setup
ssh-setup: ## Generate SSH key
ifeq ($(wildcard $(HOME)/.ssh/id_rsa),)
	mkdir -p $(HOME)/.ssh
	ssh-keygen -f $(HOME)/.ssh/id_rsa -N ""
endif

.PHONY: setup
setup: place-files git-setup install-tools ## Full setup

.PHONY: help
.DEFAULT_GOAL := help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
