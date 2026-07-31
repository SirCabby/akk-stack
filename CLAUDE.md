# akk-stack — project instructions

Self-hosted EQEmu server stack (Docker). The full emulator source is vendored in `code/`;
operational DB tooling lives in `eqemu-ops/`. The game database is the `peq` schema in the
`akk-stack-mariadb-1` container.

## Database changes MUST go through dbmate migrations

**Never modify the `peq` database directly.** No ad-hoc `mysql -e "UPDATE/INSERT/DELETE ..."`,
no piping `.sql` files into the container, no Spire-only edits left uncaptured. Every
schema / content / rule change — `rule_values`, items, npc_types, spells, spawns, etc. —
must be authored as a versioned **dbmate migration** so it is replayable onto a fresh
database and tracked in git. A live edit that isn't in a migration is lost on the next
rebuild and is treated as a mistake.

Workflow (run from the repo root, `~/workspace/GitHub/akk-stack`):

```bash
make migrate-new NAME=short_description   # scaffold eqemu-ops/db/migrations/<ts>_<name>.sql
# edit the file: fill in BOTH `-- migrate:up` and `-- migrate:down` (the reverse SQL)
make migrate-up                           # apply pending migrations
make migrate-status                       # verify applied / pending
make migrate-down                         # roll back the most recent migration
```

**Two channels.** `db/migrations/` is the CANONICAL history — every server (dev + the
future live server) replays it, so only proven, permanent changes belong there.
Tests/tuning trials go in the dev-only EXPERIMENTS channel (`db/experiments/`, separate
ledger): `make migrate-exp-new NAME=... / migrate-exp-up / migrate-exp-down /
migrate-exp-status`. Graduate a proven experiment with
`make migrate-promote FILE=db/experiments/<file>.sql`; discard with `migrate-exp-down` +
delete. When a change is exploratory or you're not sure it will stick, default to the
experiments channel. Full model: `eqemu-ops/docs/dev-to-live.md`.

Conventions (full list in `eqemu-ops/README.md`):
- **Always write the `down` section** so every change is reversible.
- For `rule_values` use `INSERT ... ON DUPLICATE KEY UPDATE` (PK is `(ruleset_id, rule_name)`;
  **ruleset 1 = `default` is the active set**). Use explicit column lists for content INSERTs.
- Custom content uses IDs `>= 1,000,000` so it never collides with PEQ content.
- **Content only.** Never migrate player/runtime tables (`account`, `character_*`) — those
  change during play and are captured by `make db-backup`, not migrations.
- Keep each rule/table under single migration ownership; cross-reference rather than
  re-setting a value another migration already owns.

**Read-only** inspection queries (`SELECT` / `SHOW` / `DESCRIBE` via `mysql -e`, and
`mysqldump` backups) are fine and do **not** need a migration.

After applying a migration, the running world/zone processes still hold the old rules in
memory — run `#reload rules` in-game (as GM) or restart the stack for changes to take effect.

> This policy is enforced by a PreToolUse hook (`.claude/hooks/enforce-dbmate.sh`) that
> blocks direct DB-mutating shell commands. If it ever blocks something legitimate, author
> the change as a migration rather than working around the hook.

## `make install` at a stack root is a DESTRUCTIVE REINSTALL — never run it

`install` is a target name shared by two very different Makefiles:

| where | what `make install` does |
|---|---|
| `eqemu-ops/client-pack/<mod>/` | deploys that client mod — safe, the usual intent |
| an akk-stack **root** (dev or live) | **full-stack reinstall** |

The root target chains to `docker exec eqemu-server make install`, which runs
`pull-eqemu-code → … → init-build → init-peq-database → init-loginserver`. On 2026-07-28 this
**wiped dev's player tables** (`account`, `character_data`, `character_currency`, `inventory`,
`character_bind` → 0) and `rm -rf build` destroyed the ninja build dir, replacing `bin/zone`
with a binary containing none of the custom server code. Content and dbmate migrations survived;
player data did not.

**The cwd is not stable between tool calls**, so a bare `make install` can silently resolve
against the root Makefile. Always scope it: **`make -C eqemu-ops/client-pack/<mod> install`**.

Rebuild the server with
`docker exec akk-stack-eqemu-server-1 bash -lc "cd /home/eqemu/code/build && ninja"` — never with
a `make init-*` target. (`make init-dev-build` is the one exception: it restores the ninja build
config and touches no data.)

> Enforced by `.claude/hooks/block-stack-reinstall.sh`, which denies root `make install`,
> `make init-*`, and volume-destroying `docker compose down -v` / `docker volume rm`, and asks
> before `make devsync` (a wholesale player-table overwrite). Do not work around it — if it
> blocks something legitimate, scope the command properly instead.
