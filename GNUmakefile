# GNUmakefile — extends the stock akk-stack Makefile with DB-ops targets that live
# in the nested ./eqemu-ops repo. GNU Make reads GNUmakefile *before* Makefile, so
# these are added WITHOUT editing the upstream-tracked Makefile (no merge conflicts
# when you sync akk-stack upstream). Run from the akk-stack dir like any other target:
#
#   make db-backup | list-backups | db-restore FILE=backups/<name>.sql.gz
#   make devsync [DRY_RUN=1] [FORCE=1]   (pull live's player/account data into dev)
#   make migrate-new NAME=<desc> | migrate-up | migrate-down | migrate-status
#   make db-stage-upstream PKG=<id> | db-diff-report | db-refresh-upstream | db-clean-staging
include Makefile

OPS_DIR  ?= eqemu-ops
DELEGATE  = @$(MAKE) --no-print-directory -C $(OPS_DIR)

.PHONY: allaclone-refresh db-backup list-backups db-restore devsync migrate-new migrate-up migrate-down migrate-status \
        migrate-exp-new migrate-exp-up migrate-exp-down migrate-exp-status migrate-promote migrate-rebaseline \
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
devsync: ##@db-ops Overwrite dev player/account tables with the live stack's (DRY_RUN=1 / FORCE=1)
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

.PHONY: client-build client-package package
client-build: ##@client-ops Rebuild the RoF2 client overlay (eqemu-ops/client-pack/build)
	$(DELEGATE) client-build
client-package: ##@client-ops Rebuild + package the RoF2 client overlay (client-pack/dist/cabby-pack.zip)
	$(DELEGATE) client-package
package: client-package ##@client-ops Alias for client-package
