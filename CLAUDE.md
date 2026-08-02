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

**Three channels.** `db/migrations/` is the CANONICAL history — every server (dev + live)
replays it, so only proven, permanent changes belong there.

Tests/tuning trials go in the dev-only EXPERIMENTS channel (`db/experiments/`, separate
ledger): `make migrate-exp-new NAME=... / migrate-exp-up / migrate-exp-down /
migrate-exp-status`. Graduate a proven experiment with
`make migrate-promote FILE=db/experiments/<file>.sql`; discard with `migrate-exp-down` +
delete. When a change is exploratory or you're not sure it will stick, default to the
experiments channel.

Schema that is only meaningful on the **live host** (the peq-editor's `peq_admin` table,
cleanup of artifacts left by live-only services) goes in the live-only LIVE channel
(`db/live/`, ledger `schema_live`): `make migrate-live-new NAME=... / migrate-live-up /
migrate-live-down / migrate-live-status`. It is the mirror image of experiments —
experiments never reach live, live-channel files never reach dev — and `make migrate-up`
on either server touches neither.

> **Author live-channel files on DEV.** `migrate-live-up` / `-down` / `-adopt` are gated
> by the `require-live` target and refuse to run unless the parent stack dir is
> `akk-stack-live`. Authoring belongs on dev because live's git origin is dev's
> checked-out working tree, so a commit made on live cannot be pushed and strands as an
> untracked file. Flow: write on dev → commit + push → `git pull` on live →
> `make migrate-live-up` there.

**Never put a credential in any migration** — they are committed and replay everywhere.
Ship the upstream default and set the real per-host secret out-of-band; host-specific
*settings* belong in `.env`. Full model: `eqemu-ops/docs/dev-to-live.md`.

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
`mysqldump` backups) are fine and do **not** need a migration. Note the hook also blocks
read-only calls that use shell **redirection** (`> file`, `diff <(...)`) — aggregate in SQL
instead of piping output to files.

**Player/runtime data is ops territory, not migrations.** Inline DML (`INSERT` / `UPDATE` /
`DELETE` / `REPLACE` via `mysql -e`) is allowed WITHOUT a migration when **every** target
table is listed in `eqemu-ops/db/player-tables.txt` (`account`, `character_*`, guilds,
corpses, ...). That covers GM/ops actions like moving a stuck character or fixing a
corrupt buff row — state that is captured by `make db-backup` and must never replay onto
another server. Write plain unquoted table names so the hook can verify targets. Schema
changes (`ALTER`/`CREATE`/`DROP`/`TRUNCATE`) still require a migration even on player
tables, and piping `.sql` files into the container stays blocked.

After applying a migration, the running world/zone processes still hold the old rules in
memory — run `#reload rules` in-game (as GM) or restart the stack for changes to take effect.

> This policy is enforced by a PreToolUse hook (`.claude/hooks/enforce-dbmate.sh`) that
> blocks direct DB-mutating shell commands. If it ever blocks something legitimate, author
> the change as a migration rather than working around the hook.

## Every change ships to LIVE — never leave the two stacks diverged

Two stacks run on this box: **dev** (`~/workspace/GitHub/akk-stack`, LAN `.3`) and **live**
(`~/workspace/GitHub/akk-stack-live`, LAN `.7`, **real players**). Once a change is applied
and verified on dev, propagate it to live **in the same session**, before reporting the work
done. This is standing authorization for the `git commit` + `git push` the propagation
requires — don't stop to ask for those.

Live's `origin` for all four repos is dev's checked-out working tree, so **uncommitted work
cannot reach live**. Commit each nested repo the change touched (`git add` explicitly — a new
migration file is untracked and `commit -a` will silently skip it):

```bash
# on DEV — only the repos the change actually touched
git -C eqemu-ops   add db/migrations/<file>.sql && git -C eqemu-ops   commit -m "..." && git -C eqemu-ops   push
git -C server/quests add <files>              && git -C server/quests commit -m "..." && git -C server/quests push
git -C code        add <files>                && git -C code        commit -m "..." && git -C code        push
git add <files>                               && git commit -m "..."                 && git push   # stack scaffold

# then on LIVE
cd ~/workspace/GitHub/akk-stack-live
git pull && git -C eqemu-ops pull && git -C server/quests pull && git -C code pull
make migrate-up && make migrate-status        # expect: 0 pending
```

**Never ships to live:** anything in `db/experiments/` (never run `migrate-exp-*` in the live
checkout), and dev's `.env` / `eqemu_config.json` / `login.json` — live has its own passwords
and keys. `db/live/` is the mirror image: authored on dev, applied only on live.

**Then make it take effect — check who is online FIRST:**

```bash
docker exec akk-stack-live-eqemu-server-1 bash -lc \
  '{ printf "who\n"; sleep 3; printf "quit\n"; } | telnet 127.0.0.1 9000'
```

| change | activation | who it disconnects |
|---|---|---|
| rules, loot, doors, merchants, content flags, quests | in-game `#reload <type>` as GM | nobody |
| spawns / other zone-boot content | console `zoneshutdown <zone>`, or `make restart` | that zone / everyone |
| spells, items (shared memory), server code | rebuild + `make restart` | everyone |

The world console has **no** granular reload — only `reloadworld` / `reloadzonequests`. So the
`#reload <type>` step belongs to the user in-game: state explicitly which command to run. If
players are online and the change needs `make restart`, **ask first** and `broadcast` a warning.

Server code rebuilds inside live's own container — never copy dev's binaries:
`docker exec akk-stack-live-eqemu-server-1 bash -c 'cd /home/eqemu/code && cmake --build build'`

Full runbook (IPs, router forwards, backups, onboarding): `eqemu-ops/docs/live-local-runbook.md`.

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
