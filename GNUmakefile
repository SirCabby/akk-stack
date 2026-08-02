# GNUmakefile — extends the stock akk-stack Makefile with DB-ops targets that live
# in the nested ./eqemu-ops repo. GNU Make reads GNUmakefile *before* Makefile, so
# these are added WITHOUT editing the upstream-tracked Makefile (no merge conflicts
# when you sync akk-stack upstream). Run from the akk-stack dir like any other target:
#
#   make db-backup | list-backups | db-restore FILE=backups/<name>.sql.gz
#   make devsync [DRY_RUN=1] [FORCE=1]   (pull live's player/account data into dev)
#   make migrate-new NAME=<desc> | migrate-up | migrate-down | migrate-status
#   make migrate-live-new NAME=<desc> | migrate-live-up   (live-only channel; up is gated to the live stack)
#   make db-stage-upstream PKG=<id> | db-diff-report | db-refresh-upstream | db-clean-staging

# ---------------------------------------------------------------------------------------
# Upstream Makefile include.
#
# A few of its informational targets need per-stack behavior (PEQ editor port, the ENABLE_*
# toggles, a server name containing an apostrophe). Simply redefining a target that
# `include Makefile` already defined works, but makes GNU make print
#     GNUmakefile:N: warning: overriding recipe for target 'info'
#     Makefile:N: warning: ignoring old recipe for target 'info'
# on EVERY invocation, including unrelated targets. So the upstream copy is included with
# those targets RENAMED to `upstream-<name>`: make never sees two recipes for one target,
# no warnings, and the originals stay runnable (`make upstream-info`) for comparison.
#
# The point is that Makefile itself stays byte-identical to upstream, so syncing akk-stack
# upstream never conflicts. Keep it that way — put stack-local changes HERE, not there.
# (The rename also drops the `##@` help text from the originals so `make help` lists each
# target once, ours.)
OVERRIDE_TARGETS := info up-info
UPSTREAM_MK      := .upstream.mk
$(shell sed $(foreach t,$(OVERRIDE_TARGETS),-e 's|^$(t):.*|upstream-$(t):|') Makefile > $(UPSTREAM_MK).tmp && mv -f $(UPSTREAM_MK).tmp $(UPSTREAM_MK))
include $(UPSTREAM_MK)

# Published port for the PEQ editor proxy (docker-compose.yml defaults to the same value).
# `?=` so a stack's .env wins — the two stacks on this box need different ports to coexist.
PEQ_EDITOR_PORT ?= 8081

OPS_DIR  ?= eqemu-ops
DELEGATE  = @$(MAKE) --no-print-directory -C $(OPS_DIR)

# Which stack is this checkout? Same signal eqemu-ops/Makefile uses to pick the DB
# container/network: the directory name. Targets that only make sense on one stack gate on
# it rather than being deleted from the other stack's copy — a guard gives a reason, a
# deletion gives "No rule to make target" and leaves the two checkouts permanently forked.
STACK_NAME      ?= $(notdir $(CURDIR))
LIVE_STACK_NAME ?= akk-stack-live

# devsync overwrites THIS stack's player tables from live, and the client pack is built and
# published from dev. Both are dev-side operations; on live they are at best pointless and
# at worst destructive (on live, devsync's default source is live itself).
refuse-on-live:
	@test "$(STACK_NAME)" != "$(LIVE_STACK_NAME)" || { \
	  printf '>> refusing: `make %s` is a DEV-stack target and must not run on the live stack.\n' "$(MAKECMDGOALS)"; \
	  printf '>>   this stack: %s\n' "$(STACK_NAME)"; \
	  printf '>>   run it from the dev checkout instead (~/workspace/GitHub/akk-stack).\n'; \
	  exit 1; }

.PHONY: refuse-on-live allaclone-refresh db-backup list-backups db-restore devsync migrate-new migrate-up migrate-down migrate-status \
        migrate-exp-new migrate-exp-up migrate-exp-down migrate-exp-status migrate-promote migrate-rebaseline \
        migrate-live-new migrate-live-up migrate-live-down migrate-live-status migrate-live-adopt \
        db-replay-restore db-replay-up db-replay-compare db-replay-clean \
        db-stage-upstream db-diff-report db-refresh-upstream db-clean-staging \
        db-stage-takp db-clean-takp takp-map takp-generate takp-verify \
        takp-rehearse takp-clean-rehearsal

allaclone-refresh: ##@db-ops Reindex quests + clear cached pages in the allaclone browser (runs itself after migrate-up)
	$(DELEGATE) allaclone-refresh
db-backup: ##@db-ops Full DB snapshot -> eqemu-ops/backups/*.sql.gz
	$(DELEGATE) db-backup
list-backups: ##@db-ops List saved DB backups
	$(DELEGATE) list-backups
db-restore: ##@db-ops Restore a dump (make db-restore FILE=backups/<name>.sql.gz)
	$(DELEGATE) db-restore FILE="$(FILE)"
devsync: refuse-on-live ##@db-ops Overwrite dev player/account tables with the live stack's (DRY_RUN=1 / FORCE=1)
	$(DELEGATE) db-sync-players DRY_RUN="$(DRY_RUN)" FORCE="$(FORCE)"
migrate-new: ##@db-ops New migration (make migrate-new NAME=short_desc)
	$(DELEGATE) migrate-new NAME="$(NAME)"
migrate-up: ##@db-ops Apply pending migrations
	$(DELEGATE) migrate-up
migrate-down: ##@db-ops Roll back the most recent migration
	$(DELEGATE) migrate-down
migrate-status: ##@db-ops Show applied / pending migrations
	$(DELEGATE) migrate-status

migrate-exp-new: ##@db-ops New EXPERIMENT migration (make migrate-exp-new NAME=short_desc)
	$(DELEGATE) migrate-exp-new NAME="$(NAME)"
migrate-exp-up: ##@db-ops Apply pending experiment migrations (dev only)
	$(DELEGATE) migrate-exp-up
migrate-exp-down: ##@db-ops Roll back the most recent experiment migration
	$(DELEGATE) migrate-exp-down
migrate-exp-status: ##@db-ops Show applied / pending experiment migrations
	$(DELEGATE) migrate-exp-status
migrate-promote: ##@db-ops Graduate an experiment to canonical (make migrate-promote FILE=db/experiments/<f>.sql)
	$(DELEGATE) migrate-promote FILE="$(FILE)"
migrate-rebaseline: ##@db-ops Rewrite the migrations ledger to match db/migrations (CONFIRM=rebaseline)
	$(DELEGATE) migrate-rebaseline CONFIRM="$(CONFIRM)" DB_NAME="$(DB_NAME)"

migrate-live-new: ##@db-ops New LIVE-ONLY migration (make migrate-live-new NAME=short_desc) — author on dev
	$(DELEGATE) migrate-live-new NAME="$(NAME)"
migrate-live-up: ##@db-ops Apply pending live-only migrations (LIVE STACK ONLY)
	$(DELEGATE) migrate-live-up
migrate-live-down: ##@db-ops Roll back the most recent live-only migration (LIVE STACK ONLY)
	$(DELEGATE) migrate-live-down
migrate-live-status: ##@db-ops Show applied / pending live-only migrations
	$(DELEGATE) migrate-live-status
migrate-live-adopt: ##@db-ops Move already-applied db/live versions into the schema_live ledger (LIVE STACK ONLY)
	$(DELEGATE) migrate-live-adopt

db-replay-restore: ##@db-ops Restore a backup into a scratch schema (SCHEMA= FILE=)
	$(DELEGATE) db-replay-restore SCHEMA="$(SCHEMA)" FILE="$(FILE)"
db-replay-up: ##@db-ops Replay a migrations dir into a scratch schema (SCHEMA= [DIR=])
	$(DELEGATE) db-replay-up SCHEMA="$(SCHEMA)" DIR="$(DIR)"
db-replay-compare: ##@db-ops Compare two schemas table by table (A= B= [TABLES=])
	$(DELEGATE) db-replay-compare A="$(A)" B="$(B)" TABLES="$(TABLES)"
db-replay-clean: ##@db-ops Drop a scratch schema (SCHEMA=)
	$(DELEGATE) db-replay-clean SCHEMA="$(SCHEMA)"

db-stage-upstream: ##@db-ops Stage a PEQ dump + diff report (make db-stage-upstream PKG=<id>)
	$(DELEGATE) db-stage-upstream PKG="$(PKG)" SCHEMA="$(SCHEMA)" BASE="$(BASE)"
db-diff-report: ##@db-ops Diff live peq vs a staged schema (SCHEMA=/BASE= optional)
	$(DELEGATE) db-diff-report SCHEMA="$(SCHEMA)" BASE="$(BASE)"
db-refresh-upstream: ##@db-ops Swap content from staging + replay migrations (DRY_RUN=1/FORCE=1)
	$(DELEGATE) db-refresh-upstream SCHEMA="$(SCHEMA)" DRY_RUN="$(DRY_RUN)" FORCE="$(FORCE)" REFRESH_SYSTEM="$(REFRESH_SYSTEM)"
db-clean-staging: ##@db-ops Drop staging schema(s) (SCHEMA=peq_upstream default)
	$(DELEGATE) db-clean-staging SCHEMA="$(SCHEMA)"

db-stage-takp: ##@db-ops Load a TAKP alkabor dump into staging schema takp (FILE=<.tar.gz|.sql>)
	$(DELEGATE) db-stage-takp FILE="$(FILE)" SCHEMA="$(SCHEMA)"
db-clean-takp: ##@db-ops Drop the TAKP staging schema
	$(DELEGATE) db-clean-takp SCHEMA="$(SCHEMA)"

takp-map: ##@db-ops Build the TAKP import zone routing + npc match map (+ reports)
	$(DELEGATE) takp-map
takp-generate: ##@db-ops Emit the TAKP spawn-import dbmate migrations + reports
	$(DELEGATE) takp-generate
takp-verify: ##@db-ops TAKP import verification suite (SCHEMA=peq_rehearsal / MODE=baseline optional)
	$(DELEGATE) takp-verify SCHEMA="$(SCHEMA)" MODE="$(MODE)"
takp-rehearse: ##@db-ops Backup + restore into peq_rehearsal + apply pending migrations + verify
	$(DELEGATE) takp-rehearse FILE="$(FILE)"
takp-clean-rehearsal: ##@db-ops Drop the peq_rehearsal schema
	$(DELEGATE) takp-clean-rehearsal

#----------------------
# Stack-local overrides of upstream informational targets (see OVERRIDE_TARGETS above).
# The upstream originals remain as `make upstream-info` / `make upstream-up-info`.
#----------------------
.PHONY: server-status info up-info

# Containers being up says nothing about which binaries Spire's launcher actually spawned --
# those are gated by web-admin.launcher.run* in server/eqemu_config.json, which is gitignored
# and drifts per host. A false runLoginserver there means nobody can log in or create an
# account while `make up` still looks perfectly healthy. Surface it instead of hiding it.
server-status: ##@info Report which eqemu server processes are actually running
	@echo "> Server Processes"
	@echo "----------------------------------"
	@for proc in world loginserver ucs; do \
		if $(DOCKER) exec -T eqemu-server bash -c "pgrep -f 'bin/$$proc' >/dev/null 2>&1"; then \
			echo "> $$proc  OK"; \
		else \
			echo "> $$proc  NOT RUNNING -- check web-admin.launcher.run* in server/eqemu_config.json"; \
		fi; \
	done
	@echo "> zones running: $$($(DOCKER) exec -T eqemu-server bash -c "pgrep -fc 'bin/zone'" 2>/dev/null || echo 0)"
	@echo "----------------------------------"

info: ##@info Print install info
	@echo "----------------------------------"
	@echo "> Server Info"
	@echo "----------------------------------"
	@# Read the name in the RECIPE, not via $$(shell) at parse time: upstream's form ran a
	@# docker exec on every make invocation and interpolated the result into a SINGLE-quoted
	@# echo, so a name containing an apostrophe ("Cabby's Live Server") broke the shell with
	@# `unexpected EOF while looking for matching '`. jq -r also replaces its tr -d '\"' hack.
	@$(DOCKER) exec -T eqemu-server bash -c "cat ~/server/eqemu_config.json | jq -r '.server.world.longname'" 2>/dev/null | sed 's/^/> /' || echo "> (server container not running)"
	@echo "----------------------------------"
	@echo "> Passwords"
	@echo "----------------------------------"
	@cat .env | grep PASSWORD
	@echo "----------------------------------"
	@echo "> IP"
	@echo "----------------------------------"
	@cat .env | grep IP
	@echo "----------------------------------"
ifeq ("$(ENABLE_FTP_QUESTS)", "true")
	@echo "> Quests FTP  | ${IP_ADDRESS}:21 | quests / ${FTP_QUESTS_PASSWORD}"
	@echo "----------------------------------"
endif
	@echo "> Web Interfaces"
	@echo "----------------------------------"
ifeq ("$(ENABLE_PEQ_EDITOR)", "true")
	@echo "> PEQ Editor (proxy)  | http://${IP_ADDRESS}:$(PEQ_EDITOR_PORT) | ${PEQ_EDITOR_PROXY_USERNAME} / ${PEQ_EDITOR_PROXY_PASSWORD}"
	@echo "> PEQ Editor (app)    | http://${IP_ADDRESS}:$(PEQ_EDITOR_PORT) | admin / ${PEQ_EDITOR_PASSWORD}"
endif
ifeq ("$(ENABLE_PHPMYADMIN)", "true")
	@echo "> PhpMyAdmin          | http://${IP_ADDRESS}:8082 | admin / ${PHPMYADMIN_PASSWORD}"
endif
	@echo "> EQEmu Admin (spire) | http://${IP_ADDRESS}:3000 | admin / $(shell $(DOCKER) exec -T eqemu-server bash -c "cat ~/server/eqemu_config.json | jq '.[\"web-admin\"].application.admin.password'")"
ifeq ("$(SPIRE_DEV)", "true")
	@echo "----------------------------------"
	@echo "> Spire Backend Development  | http://${IP_ADDRESS}:3010 | "
	@echo "> Spire Frontend Development | http://${IP_ADDRESS}:8080 | "
endif
	@echo "----------------------------------"

# `make up` calls `make up-info` as a sub-make, which re-parses this file and so gets THIS
# recipe. Appending server-status here is why `up` itself needs no override — leaving that
# target pristine keeps the one recipe that actually starts the stack upstream-owned.
up-info: ##@info Shows web interfaces during make up
	@echo "----------------------------------"
	@echo "> Web Interfaces"
	@echo "----------------------------------"
ifeq ("$(ENABLE_PEQ_EDITOR)", "true")
	@echo "> PEQ Editor          | http://${IP_ADDRESS}:$(PEQ_EDITOR_PORT)"
endif
ifeq ("$(ENABLE_PHPMYADMIN)", "true")
	@echo "> PhpMyAdmin          | http://${IP_ADDRESS}:8082"
endif
	@echo "> EQEmu Admin (spire) | http://${IP_ADDRESS}:3000"
ifeq ("$(SPIRE_DEV)", "true")
	@echo "----------------------------------"
	@echo "> Spire Backend Development  | http://${IP_ADDRESS}:3010"
	@echo "> Spire Frontend Development | http://${IP_ADDRESS}:8080"
endif
	@echo "----------------------------------"
	@echo "Use 'make info' to see passwords"
	@echo "----------------------------------"
	@$(MAKE) --no-print-directory server-status

.PHONY: client-build client-package package
client-build: refuse-on-live ##@client-ops Rebuild the RoF2 client overlay (eqemu-ops/client-pack/build)
	$(DELEGATE) client-build
client-package: refuse-on-live ##@client-ops Rebuild + package the RoF2 client overlay (client-pack/dist/cabby-pack.zip)
	$(DELEGATE) client-package
package: client-package ##@client-ops Alias for client-package
