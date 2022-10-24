# TODO: disable AppArmor
# TODO: add symbolic links to MySQL and Nginx config
# TODO: modify /etc/hosts (?)

MAKEFILE_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

include $(MAKEFILE_DIR)/env.sh

define REQUIRED_ENVVARS :=
GIT_EMAIL
GIT_USERNAME
endef

define definedcheck
$(eval undefine missing_vars)
$(foreach v,$(1),$(if $($(v)),,$(eval missing_vars += $(v))))
$(if $(missing_vars),$(error unset variables: $(missing_vars); see $(MAKEFILE_DIR)/env.sh),)
endef

$(call definedcheck,$(REQUIRED_ENVVARS))

# In some environments, $HOME is not /home/user
HOME := /home/$(USER)

.PHONY: first
first:
	@if [ ! -e $(HOME)/env.sh ] || [ $(force) -eq 1 ]; then \
		ln -f -s $(MAKEFILE_DIR)/env.sh $(HOME)/env.sh; \
	else \
		echo $(HOME)/env.sh already exists; \
		echo skip copying $(MAKEFILE_DIR)/env.sh; \
	fi
	@if [ ! -e $(HOME)/alp ] || [ $(force) -eq 1 ]; then \
		ln -f -s $(MAKEFILE_DIR)/alp $(HOME)/alp; \
	else \
		echo $(HOME)/alp already exists; \
		echo skip copying $(MAKEFILE_DIR)/alp; \
	fi
	@if [ ! -e $(HOME)/Makefile ] || [ $(force) -eq 1 ]; then \
		ln -f -s $(MAKEFILE_DIR)/toolkit.mk $(HOME)/Makefile; \
	else \
		echo $(HOME)/Makefile already exists; \
		echo skip copying $(MAKEFILE_DIR)/Makefile; \
	fi
	@if [ ! -e $(HOME)/sync-all.sh ] || [ $(force) -eq 1 ]; then \
		ln -f -s $(MAKEFILE_DIR)/sync-all.sh $(HOME)/sync-all.sh; \
	else \
		echo $(HOME)/sync-all.sh already exists; \
		echo skip copying $(MAKEFILE_DIR)/sync-all.sh; \
	fi
	@if [ ! -e $(HOME)/sync.sh ] || [ $(force) -eq 1 ]; then \
		ln -f -s $(MAKEFILE_DIR)/sync.sh $(HOME)/sync.sh; \
	else \
		echo $(HOME)/sync.sh already exists; \
		echo skip copying $(MAKEFILE_DIR)/sync.sh; \
	fi

.PHONY: install-tools
install-tools:
	$(eval TMPDIR := $(shell mktemp -d))
	sudo apt install -y percona-toolkit

	cd $(TMPDIR) && \
	curl -LO https://github.com/tkuchiki/alp/releases/download/v1.0.11/alp_linux_amd64.tar.gz && \
	tar xf alp_linux_amd64.tar.gz && \
	sudo install alp /usr/local/bin

	cd $(TMPDIR) && \
	curl -LO https://github.com/catatsuy/notify_slack/releases/download/v0.4.13/notify_slack-linux-amd64.tar.gz && \
	tar xf notify_slack-linux-amd64.tar.gz && \
	sudo install notify_slack /usr/local/bin

	$(eval VERSION := v0.22.0)
	$(eval FILE := dsq-$(shell uname -s | awk '{ print tolower($$0) }')-x64-$(VERSION).zip)
	cd $(TMPDIR) && \
	curl -LO "https://github.com/multiprocessio/dsq/releases/download/$(VERSION)/$(FILE)" && \
	unzip $(FILE) && \
	sudo install dsq /usr/local/bin

	rm -r $(TMPDIR)

.PHONY: git-setup
git-setup:
	git config --global user.email $(GIT_EMAIL)
	git config --global user.name $(GIT_USERNAME)

.PHONY: ssh-setup
ssh-setup:
	mkdir -p $(HOME)/.ssh
ifeq ($(wildcard $(HOME)/.ssh/id_rsa),)
	ssh-keygen -f $(HOME)/.ssh/id_rsa -N ""
endif

.PHONY: setup
setup: first git-setup ssh-setup install-tools
