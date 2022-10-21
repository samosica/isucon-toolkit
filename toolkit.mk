# In some environments, $HOME is not /home/user
HOME := /home/$(USER)

include $(HOME)/env.sh

SERVICE_NAME := # fill here

REPO_DIR := # fill here

MYSQL_USER := root
MYSQL_PASSWORD := root

NGINX_ACCESS_LOG := /var/log/nginx/access.log
MYSQL_SLOW_LOG := /var/log/mysql/slow.log
SQLITE_TRACE_LOG := # fill here
STATS_DIR := # fill here

ENVVARS := \
	SERVICE_NAME \
	REPO_DIR \
	MYSQL_USER \
	MYSQL_PASSWORD \
	NGINX_ACCESS_LOG \
	MYSQL_SLOW_LOG \
	SQLITE_TRACE_LOG \
	STATS_DIR

definedcheck = $(if $(strip $($1)),,$(eval MISSING_ENVVARS += $1))

$(foreach envvar,$(ENVVARS),$(call definedcheck,$(envvar)))

ifneq ($(strip $(MISSING_ENVVARS)),)
$(error unset variables: $(MISSING_ENVVARS); see $(HOME)/env.sh)
endif

.PHONY: sync
sync: ## Sync files in this server with remote repository
	$(HOME)/sync.sh $(REPO_DIR) $(BRANCH)

.PHONY: sync-all
sync-all: ## Sync files in all servers with remote repository
	$(HOME)/sync-all.sh $(REPO_DIR) $(BRANCH)

.PHONY: log-rotate
log-rotate: ## Log rotate
	sudo rm -f $(NGINX_ACCESS_LOG) $(MYSQL_SLOW_LOG) $(SQLITE_TRACE_LOG)
	sudo nginx -s reopen
	sudo mysqladmin -u $(MYSQL_USER) -p$(MYSQL_PASSWORD) flush-logs

.PHONY: restart
restart: ## Restart the application
	sudo systemctl restart nginx
	sudo systemctl restart mysql
	sudo systemctl restart redis
	sudo systemctl daemon-reload
	sudo systemctl restart $(SERVICE_NAME)

.PHONY: before-bench
before-bench: log-rotate restart ## Prepare for a benchmark

.PHONY: bench
bench: before-bench ## Run a benchmark. You must specify BENCHMARK_SERVER
ifeq ($(strip $(BENCHMARK_SERVER)),)
	$(error set BENCHMARK_SERVER in $(HOME)/env.sh)
endif
	ssh $(BENCHMARK_SERVER) "cd bench; ./bench"

.PHONY: analyze-nginx
analyze-nginx: $(HOME)/alp/config.yml ## Analyze a Nginx log
	mkdir -p $(STATS_DIR)

	@if sudo [ -e $(NGINX_ACCESS_LOG) ]; then \
		sudo alp ltsv \
			--file $(NGINX_ACCESS_LOG) \
			--config $(HOME)/alp/config.yml | \
		tee $(STATS_DIR)/nginx.log; \
	fi

.PHONY: analyze-sqlite
analyze-sqlite: ## Analyze a SQLite log
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
