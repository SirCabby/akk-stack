#!/usr/bin/env bash
# PreToolUse (Bash) hook — force every peq CONTENT change through a dbmate migration.
#
# Blocks direct DB-mutating shell commands against content tables (ad-hoc
# `mysql -e "UPDATE rule_values ..."`, piping a .sql file into the container, heredocs).
# Allowed without a migration:
#   - read-only queries (SELECT/SHOW/DESCRIBE via `mysql -e`) and mysqldump backups
#   - anything run through dbmate
#   - inline DML (INSERT/UPDATE/DELETE/REPLACE) whose every target table is a
#     player/runtime table listed in eqemu-ops/db/player-tables.txt — GM/ops actions
#     (e.g. moving a stuck character) live there and are captured by `make db-backup`,
#     not migrations. Schema/destructive statements (ALTER/DROP/TRUNCATE/...) and
#     redirected SQL stay blocked even for player tables.
#
# Deny is signalled via the PreToolUse JSON contract (permissionDecision: "deny").
# See CLAUDE.md ("Database changes MUST go through dbmate migrations").

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Nothing to inspect -> allow.
[ -n "$cmd" ] || exit 0

# Sanctioned path: dbmate itself (and its `make migrate-*` wrappers) may touch the DB.
if printf '%s' "$cmd" | grep -Eq 'dbmate|make[[:space:]]+migrate-|migrate-(up|down|new|status)'; then
  exit 0
fi

deny() {
  jq -n --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# Is the interactive mysql/mariadb client invoked? Excludes:
#   - the mysql:// URL in dbmate's DATABASE_URL ("mysql:" -> no space/redirect after)
#   - mysqldump / mysqladmin ("mysql" -> followed by a letter, not space/redirect)
#   - the akk-stack-mariadb-1 container name ("mariadb" preceded/followed by '-')
if printf '%s' "$cmd" | grep -Eq '(^|[^a-zA-Z0-9_./-])(mysql|mariadb)([[:space:]]|<)'; then
  # Redirected input (piped .sql file or heredoc) hides the SQL from this hook -> deny.
  if printf '%s' "$cmd" | grep -Eq '<'; then
    deny 'Redirecting SQL into the mysql client hides the statements from this hook. Content changes go through dbmate migrations (`make migrate-new NAME=...`); player-table DML must be written inline (`mysql -e "..."`) so the target tables are visible. See CLAUDE.md.'
  fi

  # Schema / destructive / privilege statements always go through migrations,
  # even on player tables.
  if printf '%s' "$cmd" | grep -Eiq '\b(ALTER|DROP|TRUNCATE|CREATE|RENAME|GRANT|REVOKE|LOAD)\b'; then
    deny 'Schema, destructive, and privilege statements (ALTER/DROP/TRUNCATE/CREATE/RENAME/GRANT/REVOKE/LOAD) are blocked by policy — author a dbmate migration instead: `make migrate-new NAME=short_description`, fill in BOTH up and down SQL, then `make migrate-up`. See CLAUDE.md.'
  fi

  if printf '%s' "$cmd" | grep -Eiq '\b(INSERT|UPDATE|DELETE|REPLACE)\b'; then
    # DML carve-out: player/runtime tables (eqemu-ops/db/player-tables.txt) are ops
    # territory — GM actions like moving a stuck character — captured by `make
    # db-backup`, never by migrations. DML is allowed iff EVERY target table is in
    # that manifest; anything else is content and must be a migration. Fail closed.
    manifest="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}/eqemu-ops/db/player-tables.txt"
    if [ ! -r "$manifest" ]; then
      deny "Player-table manifest not readable ($manifest) — cannot verify DML targets, so direct writes are blocked. Author a dbmate migration instead. See CLAUDE.md."
    fi
    # Target tables of each DML statement ("ON DUPLICATE KEY UPDATE" stripped first
    # so its UPDATE keyword is not mistaken for a statement).
    targets=$(printf '%s' "$cmd" \
      | sed -E 's/on[[:space:]]+duplicate[[:space:]]+key[[:space:]]+update/ /gI' \
      | grep -oiE '(insert([[:space:]]+ignore)?[[:space:]]+into|replace[[:space:]]+into|update([[:space:]]+(low_priority|ignore))?|delete[[:space:]]+from)[[:space:]]+[`"]?[A-Za-z0-9_.]+' \
      | awk '{print $NF}' | tr -d '`"' | sed 's/^peq\.//' | tr '[:upper:]' '[:lower:]' | sort -u)
    if [ -z "$targets" ]; then
      deny 'DML keywords present but no target tables could be identified — blocked (fail closed). Write plain inline statements (`mysql -e "UPDATE <table> ..."`) for player tables, or author a dbmate migration for content. See CLAUDE.md.'
    fi
    allowed=$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$manifest" | grep -v '^$')
    for t in $targets; do
      if ! printf '%s\n' "$allowed" | grep -qxF "$t"; then
        deny "DML against \`$t\` is blocked: it is not a player/runtime table (eqemu-ops/db/player-tables.txt). Content changes must be dbmate migrations: \`make migrate-new NAME=short_description\`, fill in BOTH up and down SQL, then \`make migrate-up\`. See CLAUDE.md."
      fi
    done
    # All DML targets are player/runtime tables -> allowed (ops action, not content).
  fi
fi

exit 0
