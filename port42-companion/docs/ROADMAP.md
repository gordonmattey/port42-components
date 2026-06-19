# port42-companion — roadmap + ship gate

Status: **Thread 1 built (2026-06-19), Thread 2 open**. This is a standalone
component meant to ship for anyone to use. The AI Engine
(`workspace/engine`) is its first real consumer and proving ground, not its
owner. Thread 1 (profiles + deterministic delivery) is now a Claude Code plugin
— see "Thread 1 — done" below. Thread 2 (does it actually help?) remains the
gate that decides whether this is worth shipping at all.

## Thread 1 — done (Claude Code plugin)

Packaged as a plugin: `.claude-plugin/plugin.json`, `hooks/hooks.json`
(SessionStart), `scripts/session-start.sh`, `bin/port42-companion`, and
`skills/port42-companion/`. Decisions made:

- **Profiles inferred from the directory, env var overrides.** The hook resolves
  the profile from `$PORT42_PROFILE` if set, else the **cwd basename**, else
  `default` (flat dir). A profile is "Claude in a particular context," and the
  directory is the context signal — so launching Claude in a project dir gives
  that project its own state with no ceremony. Deliberately *not* the git repo
  root: the monorepo (`port42-growth` holding companion + marketing + tzepher…)
  must keep siblings separate; the repo root would collapse them. Env var
  override remains for sharing/mixing state across dirs or running N windows on
  one profile. The model never threads `--profile` — the hook pins the resolved
  profile into the session env. `port42-companion profiles` inspects them all.
  (The CLI's own precedence is flag > env > flat default; cwd inference lives in
  the hook, where cwd is authoritative, keeping the CLI backward-compatible for
  manual use.)
- **Read is deterministic (SessionStart hook), not CLAUDE.md prose.** The hook
  runs `all read`, injects state + the write protocol into context, and writes
  `PORT42_PROFILE` + the bundled `bin/` onto PATH via `$CLAUDE_ENV_FILE` so the
  model's later bare calls scope correctly and resolve the bundled CLI. No
  `~/.local/bin` copy, no ambient config inheritance.
- **Write half is still model-discretionary** (the open weakness from the review):
  the write protocol rides in the injected context every session so it's
  always-on rather than a discretionary skill, but the model still chooses *when*
  to write. If writes don't fire, the deterministic read has less to inject over
  time. A PostToolUse/Stop write nudge is the next lever if this proves flaky —
  deferred until Thread 2 shows the layer is worth hardening.

Legacy `scripts/install.sh` (CLI copy + CLAUDE.md injection) retained for
plugin-less environments.

## Where it is today

- CLI: `bin/port42-companion` (bash), installs to `~/.local/bin/`.
- State: `~/.port42/companion/` — **a single flat profile** (fold.md,
  position.md, creases.md, engravings.md).
- Delivery: `scripts/install.sh` injects the protocol into a Claude config
  dir's `CLAUDE.md` (`--config-dir ~/.claude-nexus` for a second instance).
- A `SKILL.md` packaging exists (v0.1.0).

How the engine consumes it: the engine launches `claude -p` and inherits
`CLAUDE_CONFIG_DIR=~/.claude-nexus`, so the companion session reads
`~/.claude-nexus/CLAUDE.md` and runs `port42-companion all read` + writes the
layers. The engine source never references the component. This works but is
**implicit and env-dependent**: a clean-env launch (launchd, Docker, Cloud Run)
silently drops the whole layer with no error.

## Thread 1 — original design notes (superseded by "done" above)

These are the design notes that fed the build; kept for rationale. The
recommended options below (env-scoped profiles, SessionStart hook, MCP ruled
out) are what shipped.

**Per-companion profiles (component feature gap).** `STATE_DIR` is hardcoded to
`~/.port42/companion`, so every consumer shares one relationship state. Real
consumers need separate profiles: the engine alone has Architect / Compiler /
Operator, each of which should carry its own fold/creases/engravings. Add a
`--profile <name>` flag that scopes `STATE_DIR` to
`~/.port42/companion/<profile>/` (default profile = today's flat dir, so
existing installs don't break).

**Deterministic delivery for headless consumers.** CLAUDE.md injection relies
on the model choosing to follow a prose instruction, and on the right config
dir being inherited. For a programmatic consumer like the engine, the read-at-
start step should be deterministic. Options considered:
- **SessionStart hook** (recommended): Claude Code runs a command every session
  before the model acts, injecting output into context. The consumer
  materializes the hook (the engine already materializes a per-session
  settings.json for permissions, so same machinery), with the profile baked in.
  No reliance on the model, no ambient config.
- **Skill** (`SKILL.md` exists): weak fit for the *read-at-start* half — a skill
  is a discretionary capability the model invokes, and it's still discovered via
  the config dir, so it doesn't escape the inheritance problem. Fine as an
  optional packaging, not the mechanism for a standing posture.
- **MCP**: ruled out (Gordon dislikes MCP servers).

**Structured / filtered output.** The hook should call a wrapper, not the raw
CLI, so injected state can be ranked by weight, depth-capped, and stale creases
dropped before hitting context. Matters as state grows. This is a natural place
for a `--format` / `--filter` option on the CLI itself.

Eventual shape for a programmatic consumer:
`SessionStart hook → wrapper → port42-companion --profile <name> read → filtered inject`,
plus a light write-directive the consumer owns (not an ambient CLAUDE.md line).

## Thread 2 — the ship gate: does it actually help?

We have validation that state *carries forward*. We have **no** measurement that
it makes sessions *better*. This is the gate before shipping it as a product.

**The trap:** a single-run quality eval undersells the feature. Its thesis is
*continuity across sessions* (don't re-litigate settled questions, carry
constraints forward), not one-shot answer quality. Eval it one-shot and you
measure its weakest axis. (Canonical example from the engine: the crypto-purity
thread, whose value was "didn't re-derive settled beliefs, didn't re-surface the
resolved question a 4th time.")

Two complementary evals:

1. **Blind paired ablation** (per-session grounding): freeze a starting context,
   run the same task twice from that identical snapshot, the only varied input
   being relationship-state injected vs not. Judge the two outputs blind. Clean
   causal read; expect it to look modest.

2. **Re-litigation rate** (the actual thesis): count how often a session re-opens
   a question/constraint already resolved in a prior session. Layer-on should
   push this toward zero; layer-off lets resolved items resurface. This is the
   metric that justifies the component.

**Cheap first read:** any consumer with a feedback signal (the engine's eval loop
tracks signal/noise + net-new per run) can correlate that signal with whether the
layer was active. Confounded, but same-day.

Until Thread 2 shows a real effect, treat shipping as unproven.
