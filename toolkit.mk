# In some environments, $HOME is not /home/user
HOME := /home/$(USER)
TOOLKIT_DIR := $(HOME)/.isucon-toolkit

include $(TOOLKIT_DIR)/env.sh

define REQUIRED_ENVVARS :=
SERVICE_NAME
REPO_DIR
MYSQL_USER
MYSQL_PASSWORD
NGINX_ACCESS_LOG
MYSQL_SLOW_LOG
STATS_DIR
endef

define definedcheck
$(eval undefine missing_vars)
$(foreach v,$(1),$(if $($(v)),,$(eval missing_vars += $(v))))
$(if $(missing_vars),$(error [error] unset variables: $(missing_vars); see $(HOME)/env.sh),)
endef

$(call definedcheck,$(REQUIRED_ENVVARS))

.PHONY: sync
sync: ## Sync files in this server with remote repository
	$(TOOLKIT_DIR)/sync.sh $(REPO_DIR) $(BRANCH)

.PHONY: sync-all
sync-all: ## Sync files in all servers with remote repository
	$(TOOLKIT_DIR)/sync-all.sh $(REPO_DIR) $(BRANCH)

.PHONY: log-rotate
log-rotate: ## Log rotate
	sudo rm -f $(NGINX_ACCESS_LOG) $(MYSQL_SLOW_LOG) $(SQLITE_TRACE_LOG)
	sudo nginx -s reopen
	sudo mysqladmin -u $(MYSQL_USER) -p$(MYSQL_PASSWORD) flush-logs

define restart-service
$(if $(shell systemctl list-unit-files "$(1)" | grep "$(1)"),sudo systemctl restart "$(1)",@echo "[info] $(1) does not exist")
endef

.PHONY: restart
restart: ## Restart the application
	$(call restart-service,nginx.service)
	$(call restart-service,mysql.service)
	$(call restart-service,redis.service)
	sudo systemctl daemon-reload
	$(call restart-service,$(SERVICE_NAME))

.PHONY: before-bench
before-bench: log-rotate restart ## Prepare for a benchmark

.PHONY: bench
bench: before-bench ## Run a benchmark. You must specify BENCHMARK_SERVER
	$(call definedcheck,BENCHMARK_SERVER)
	sleep 2
	ssh $(BENCHMARK_SERVER) "cd bench; ./bench"

.PHONY: analyze-nginx
analyze-nginx: $(TOOLKIT_DIR)/alp/config.yml ## Analyze a Nginx log
	mkdir -p $(STATS_DIR)

	@if sudo [ -e $(NGINX_ACCESS_LOG) ]; then \
		sudo alp ltsv \
			--file $(NGINX_ACCESS_LOG) \
			--config $(TOOLKIT_DIR)/alp/config.yml | \
		tee $(STATS_DIR)/nginx.log; \
	fi

.PHONY: analyze-sqlite
analyze-sqlite: ## Analyze a SQLite log
	$(call definedcheck,SQLITE_TRACE_LOG)
	mkdir -p $(STATS_DIR)
	# change this SQL statement
	@if sudo [ -e $(SQLITE_TRACE_LOG) ]; then \
		dsq --pretty $(SQLITE_TRACE_LOG) "SELECT statement, COUNT(*) AS count, AVG(query_time) AS avg FROM {} GROUP BY statement ORDER BY count DESC" | \
		tee $(STATS_DIR)/sqlite.log; \
	fi

.PHONY: analyze-mysql
analyze-mysql: ## Analyze a MySQL log
	mkdir -p $(STATS_DIR)

	@if sudo [ -e $(MYSQL_SLOW_LOG) ]; then \
		sudo pt-query-digest $(MYSQL_SLOW_LOG) | \
		tee $(STATS_DIR)/mysql.log; \
	fi

.PHONY: analyze
analyze: analyze-nginx analyze-sqlite analyze-mysql ## Analyze logs

.PHONY: help
.DEFAULT_GOAL := help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
