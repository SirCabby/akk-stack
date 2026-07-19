# GNUmakefile — extends the stock akk-stack Makefile with DB-ops targets that live
# in the nested ./eqemu-ops repo. GNU Make reads GNUmakefile *before* Makefile, so
# these are added WITHOUT editing the upstream-tracked Makefile (no merge conflicts
# when you sync akk-stack upstream). Run from the akk-stack dir like any other target:
#
#   make db-backup | list-backups | db-restore FILE=backups/<name>.sql.gz
#   make migrate-new NAME=<desc> | migrate-up | migrate-down | migrate-status
#   make db-stage-upstream PKG=<id> | db-diff-report | db-refresh-upstream | db-clean-staging
include Makefile

OPS_DIR  ?= eqemu-ops
DELEGATE  = @$(MAKE) --no-print-directory -C $(OPS_DIR)

.PHONY: db-backup list-backups db-restore migrate-new migrate-up migrate-down migrate-status \
        db-stage-upstream db-diff-report db-refresh-upstream db-clean-staging \
        db-stage-takp db-clean-takp

db-backup: ##@db-ops Full DB snapshot -> eqemu-ops/backups/*.sql.gz
	$(DELEGATE) db-backup
list-backups: ##@db-ops List saved DB backups
	$(DELEGATE) list-backups
db-restore: ##@db-ops Restore a dump (make db-restore FILE=backups/<name>.sql.gz)
	$(DELEGATE) db-restore FILE="$(FILE)"
migrate-new: ##@db-ops New migration (make migrate-new NAME=short_desc)
	$(DELEGATE) migrate-new NAME="$(NAME)"
migrate-up: ##@db-ops Apply pending migrations
	$(DELEGATE) migrate-up
migrate-down: ##@db-ops Roll back the most recent migration
	$(DELEGATE) migrate-down
migrate-status: ##@db-ops Show applied / pending migrations
	$(DELEGATE) migrate-status

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
