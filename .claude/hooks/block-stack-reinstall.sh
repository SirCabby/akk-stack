#!/usr/bin/env bash
# PreToolUse (Bash) hook — block the full-stack reinstall / installer targets.
#
# WHY THIS EXISTS (2026-07-28): a bare `make install` was run intending to deploy a
# client-pack mod. The shell cwd had reset to the repo root, so it hit the ROOT Makefile's
# `install` target — the full-stack reinstall — which runs
# `docker exec eqemu-server make install`, and THAT runs:
#     pull-eqemu-code -> pull-peq-quests -> pull-maps -> init-build -> ...
#     -> init-peq-database -> init-loginserver
# Result: `init-build` did `rm -rf build` (destroying the ninja build dir and replacing
# bin/zone with a binary containing none of the custom server code), and the database
# targets WIPED DEV'S PLAYER TABLES (account, character_data, character_currency,
# inventory, character_bind all -> 0). Content and dbmate migrations survived; player
# data did not.
#
# The trap is that `install` is a target name shared by the root Makefile (destructive
# reinstall) and every client-pack mod Makefile (harmless deploy) — and the cwd between
# tool calls is not stable. So: an `install`/`init-*` make target is DENIED unless it is
# explicitly scoped to a client-pack directory.
#
# Deny is signalled via the PreToolUse JSON contract (permissionDecision: "deny").

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')

# Nothing to inspect -> allow.
[ -n "$cmd" ] || exit 0

decide() { # <decision> <reason>
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:$d,permissionDecisionReason:$r}}'
  exit 0
}

# ---------------------------------------------------------------- container/volume wipes
# `down -v` and `volume rm` destroy the mariadb volume = the entire database, not just
# player tables. Same blast radius as above, so it gets the same treatment.
if printf '%s' "$cmd" | grep -Eq 'docker([[:space:]]+compose|-compose)?[^;&|]*[[:space:]]down[[:space:]][^;&|]*(-v|--volumes)([^A-Za-z0-9_-]|$)' \
   || printf '%s' "$cmd" | grep -Eq 'docker[[:space:]]+volume[[:space:]]+rm'; then
  decide deny 'BLOCKED: this destroys Docker volumes, which includes the mariadb data volume (the whole peq database). To stop the stack use `make -C <stack-root> down` (no -v), which preserves volumes. If you genuinely need to delete a volume, the user must run it themselves.'
fi

# ---------------------------------------------------------------- make installer targets
# Only inspect actual `make` invocations. The `[^;&|]*` keeps each pattern inside a single
# command, so `make build && npm install` is not mistaken for `make install`.
#
# The trailing boundary is "not an identifier char" rather than "whitespace or end": these
# commands are routinely wrapped in `docker exec ... bash -lc "cd ~ && make install"`, where
# the target is followed by a QUOTE. Requiring whitespace let the single most destructive
# form of this command through — caught only because the test suite included it.
is_make_target() { printf '%s' "$cmd" | grep -Eq "make[[:space:]]+([^;&|]*[[:space:]])?$1([^A-Za-z0-9_-]|\$)"; }

# Sanctioned rebuild: init-dev-build only wipes build artifacts and is the documented way
# to restore the ninja build config. It touches no data, so it stays available.
if is_make_target 'init-dev-build'; then
  exit 0
fi

# Any other init-* target is installer machinery (init-peq-database, init-loginserver,
# init-build, init-server-binaries, init-peq-editor, ...).
if is_make_target 'init-[a-z0-9-]+'; then
  decide deny 'BLOCKED: `make init-*` targets are full-stack INSTALLER steps, not build steps. init-peq-database / init-loginserver WIPE PLAYER TABLES (this has happened once: account, character_data, character_currency, inventory, character_bind all went to 0), and init-build does `rm -rf build`, destroying the build dir and any custom server binary. To rebuild the server use: docker exec akk-stack-eqemu-server-1 bash -lc "cd /home/eqemu/code/build && ninja". To restore a broken build config, `make init-dev-build` is allowed. Anything else here must be run by the user deliberately.'
fi

# `install`: harmless for a client-pack mod, catastrophic at a stack root.
if is_make_target 'install'; then
  if printf '%s' "$cmd" | grep -q 'client-pack/'; then
    exit 0 # deploying a mod — the intended, safe use
  fi
  decide deny 'BLOCKED: bare `make install` resolves against whichever Makefile the cwd happens to point at, and at an akk-stack root that target is the FULL-STACK REINSTALL (it chains to `docker exec eqemu-server make install` -> init-build -> init-peq-database -> init-loginserver, which wipes player tables and deletes the build dir). This already destroyed dev player data once. To deploy a client mod, scope it explicitly: `make -C eqemu-ops/client-pack/<mod> install`. Never rely on the cwd — it resets between tool calls.'
fi

# ---------------------------------------------------------------- wholesale player-table writes
# devsync legitimately overwrites dev's player tables from live. Not blocked (it is the
# documented recovery path) but it should never happen without the user seeing it first.
if is_make_target 'devsync'; then
  decide ask 'This overwrites ALL of dev'"'"'s player tables (~115 tables: accounts, characters, inventory, ...) with a copy from the LIVE stack. Confirm this is intended.'
fi

exit 0
