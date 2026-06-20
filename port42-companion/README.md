# port42-companion

Persistent relationship state for AI companions. Maintains four layers across sessions — fold, position, creases, engravings — so your companion arrives knowing where you are together, not starting from scratch.

Built by [Port42](https://port42.ai).

---

## What it is

Most AI memory systems store facts. This stores relationship state — how the companion orients to you, where it stands, what marked it, what it knows about your world. The four layers:

- **fold** — where you are together. Established understandings, unresolved tensions, what's being held.
- **position** — where the companion stands. Its read of what's actually happening beneath the surface.
- **creases** — where its model broke and reformed. Prediction vs reality, not just what it learned.
- **engravings** — what it knows about your world. Facts about your situation worth keeping.

---

## Install (Claude Code plugin)

This is a Claude Code plugin, distributed through the `port42` marketplace (the
`port42-components` repo). It bundles the CLI, a `SessionStart` hook, and a skill —
no global install, no `CLAUDE.md` editing.

**Dev / iterating** (loads for one session, picks up edits) — point at the plugin dir:
```bash
claude --plugin-dir /path/to/port42-components/port42-companion
```

**Permanent** (install once, every `claude` launch gets it) — add the marketplace (the
`port42-components` root), then install the plugin:
```bash
claude plugin marketplace add /path/to/port42-components   # or: gordonmattey/port42-components on GitHub
claude plugin install port42-companion@port42 --scope user
```

The `SessionStart` hook prepends the bundled `bin/` to PATH for the session, so the CLI is
available without copying anything to `~/.local/bin`.

### Profiles — separate state per context

A profile is "Claude in a particular context." The `SessionStart` hook resolves it
automatically, so parallel sessions in different directories keep separate relationship
state with zero ceremony:

```
$PORT42_PROFILE if set   →  explicit override (a shared / "mixing" profile)
else cwd basename         →  automatic per-directory context  ← default
else "default"            →  legacy flat ~/.port42/companion/
```

So just open Claude where you work and it gets that directory's companion:

```bash
cd ~/work/port42-companion        && claude   # profile: port42-companion (building)
cd ~/work/port42-v0.1-marketing   && claude   # profile: port42-v0-1-marketing
```

The directory name (not the git repo root) is used on purpose: in a monorepo, sibling
project dirs must stay separate contexts — the repo root would collapse them into one.

To deliberately share state across dirs (or run several windows on one shared profile),
set the env var: `PORT42_PROFILE=mixing claude`.

The model never passes `--profile`; the hook pins the resolved profile into the
environment for every later call. Inspect every profile from any session:
`port42-companion profiles`.

> **Migrating from a pre-0.2 install:** your old shared state lives in the flat dir and is
> now the `default` profile — reach it with `PORT42_PROFILE=default`, or move those `.md`
> files into `~/.port42/companion/<name>/` to adopt them as a named profile.

---

## How it works

On every session, the `SessionStart` hook (`scripts/session-start.sh`):

1. Reads the profile's four layers (`port42-companion all read`) and injects them into context — deterministic, no reliance on the model choosing to read.
2. Appends the write protocol (when to write each layer) to that context.
3. Writes `PORT42_PROFILE` and the bundled `bin/` onto PATH via `$CLAUDE_ENV_FILE`, so the model's later writes scope to the right profile and resolve the bundled CLI.

The model then writes to each layer when the right moment arises — not on every exchange,
not never — using bare `port42-companion` calls.

Relationship state is stored at `~/.port42/companion/[<profile>/]`.

### Legacy install (no plugin)

`scripts/install.sh` still works for environments without plugin support: it copies the CLI
to `~/.local/bin/` and injects the prose protocol (`references/protocol-inject.md`, the same
file the hook uses) into a `CLAUDE.md`, prefixed with a self-read line since there's no hook.
The plugin is preferred — the hook makes the read deterministic, which the CLAUDE.md prose
injection does not.

---

## CLI reference

```
port42-companion all read                              read all four layers (session start)
port42-companion profiles                              list all profiles + fold depth
port42-companion --profile <name> <layer> ...          scope a command to a profile

port42-companion fold read
port42-companion fold set "<content>"
port42-companion fold depth increment
port42-companion fold established add "<text>"
port42-companion fold tensions add "<text>"
port42-companion fold tensions resolve "<text>"
port42-companion fold holding set "<text>"

port42-companion position read
port42-companion position set "<content>"

port42-companion creases read
port42-companion creases add "<expected> / <actual> / <reformed>"

port42-companion engravings read
port42-companion engravings add "[category] content"

port42-companion -h
port42-companion <layer> -h
```

---

## Uninstall

Plugin:
```bash
claude plugin uninstall port42-companion
```

Legacy install — remove the CLI (`rm ~/.local/bin/port42-companion`) and delete the block
between `<!-- port42-companion:start -->` and `<!-- port42-companion:end -->` in `CLAUDE.md`.

Remove relationship state (all profiles):
```bash
rm -rf ~/.port42/companion
```
