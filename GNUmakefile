# GNUmakefile — extends the stock akk-stack Makefile with DB-ops targets that live
# in the nested ./eqemu-ops repo. GNU Make reads GNUmakefile *before* Makefile, so
# these are added WITHOUT editing the upstream-tracked Makefile (no merge conflicts
# when you sync akk-stack upstream). Run from the akk-stack dir like any other target:
#
#   make db-backup | list-backups | db-restore FILE=backups/<name>.sql.gz
#   make migrate-new NAME=<desc> | migrate-up | migrate-down | migrate-status
include Makefile

OPS_DIR  ?= eqemu-ops
DELEGATE  = @$(MAKE) --no-print-directory -C $(OPS_DIR)

.PHONY: db-backup list-backups db-restore migrate-new migrate-up migrate-down migrate-status

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
