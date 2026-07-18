#!/usr/bin/env bash
# PreToolUse (Bash) hook — force every peq DB change through a dbmate migration.
#
# Blocks direct DB-mutating shell commands (ad-hoc `mysql -e "UPDATE ..."`, piping a
# .sql file into the container, heredocs). Read-only queries (SELECT/SHOW/DESCRIBE via
# `mysql -e`), mysqldump backups, and anything run through dbmate are allowed.
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

# Is the interactive mysql/mariadb client invoked? Excludes:
#   - the mysql:// URL in dbmate's DATABASE_URL ("mysql:" -> no space/redirect after)
#   - mysqldump / mysqladmin ("mysql" -> followed by a letter, not space/redirect)
#   - the akk-stack-mariadb-1 container name ("mariadb" preceded/followed by '-')
if printf '%s' "$cmd" | grep -Eq '(^|[^a-zA-Z0-9_./-])(mysql|mariadb)([[:space:]]|<)'; then
  # Write intent: a redirect (piped .sql file or heredoc = hidden intent), or DML/DDL keywords.
  if printf '%s' "$cmd" | grep -Eq '<' \
     || printf '%s' "$cmd" | grep -Eiq '\b(INSERT|UPDATE|DELETE|REPLACE|ALTER|DROP|TRUNCATE|CREATE|RENAME|GRANT|REVOKE|LOAD)\b'; then
    reason='Direct writes to the peq database are blocked by policy. Author the change as a dbmate migration instead: run `make migrate-new NAME=short_description`, fill in BOTH the up and down SQL in eqemu-ops/db/migrations/, then `make migrate-up`. Read-only queries (SELECT/SHOW/DESCRIBE via `mysql -e`) and `mysqldump` backups are allowed. See CLAUDE.md.'
    jq -n --arg r "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
    exit 0
  fi
fi

exit 0
