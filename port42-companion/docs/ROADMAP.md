# port42-companion — ship gate

Status: **Thread 1 shipped (2026-06-19) as a Claude Code plugin** — profiles,
deterministic read (SessionStart hook), and marketplace distribution are all built and
described in the README. This file tracks only the open question that decides whether the
layer is worth shipping as a product.

## Thread 2 — the ship gate: does it actually help?

We have validation that state *carries forward*. We have **no** measurement that it makes
sessions *better*. This is the gate before shipping it as a product.

**The trap:** a single-run quality eval undersells the feature. Its thesis is *continuity
across sessions* (don't re-litigate settled questions, carry constraints forward), not
one-shot answer quality. Eval it one-shot and you measure its weakest axis. (Canonical
example from the engine: the crypto-purity thread, whose value was "didn't re-derive
settled beliefs, didn't re-surface the resolved question a 4th time.")

Two complementary evals:

1. **Blind paired ablation** (per-session grounding): freeze a starting context, run the
   same task twice from that identical snapshot, the only varied input being
   relationship-state injected vs not. Judge the two outputs blind. Clean causal read;
   expect it to look modest.

2. **Re-litigation rate** (the actual thesis): count how often a session re-opens a
   question/constraint already resolved in a prior session. Layer-on should push this
   toward zero; layer-off lets resolved items resurface. This is the metric that justifies
   the component.

**Cheap first read:** any consumer with a feedback signal (the engine's eval loop tracks
signal/noise + net-new per run) can correlate that signal with whether the layer was
active. Confounded, but same-day.

Until Thread 2 shows a real effect, treat shipping as unproven.

## Open lever — write reliability

The read half is deterministic (SessionStart hook); the **write** half is still
model-discretionary, so a session can carry forward less than it should. A `Stop`-hook
write-nudge is the next hardening lever — deferred until Thread 2 shows the layer is worth
hardening, and arguably best built first as *instrumentation*, so the re-litigation eval
above isn't confounded by "the layer was on but never wrote anything."

### Resolved (2026-06-20): the real cause was a profile-routing bug, not write discretion

Most of the analysis below (lost driver, framing/salience, fragmentation,
instrumentation) was chasing the wrong thing. The dominant reason named per-directory
profiles were empty while `default` filled up was a **one-word bug**: the SessionStart
hook wrote `PORT42_PROFILE=$PROFILE` to `$CLAUDE_ENV_FILE` **without `export`**. The
sourced value stayed a non-exported shell variable, so the `port42-companion` CLI (a
child process) never saw it and every write fell back to the flat `default` store.
PATH survived only because it keeps its pre-existing exported attribute.

So per-directory profiles never actually worked through the plugin: the hook's *read*
looked correct (it sets the profile inline on its own `all read`), but the model's
*writes* always misrouted to `default`. That is the true explanation of
"worked-before-not-now" and of `default` being a cross-context dumping ground.

Fixed in **0.2.1** (`export` both PATH and PORT42_PROFILE). Validated end-to-end: a
fresh window in `site-rescues` showed `PORT42_PROFILE` exported to child processes, and
a bare `port42-companion creases add` routed to `site-rescues/`, not `default`. Note
`CLAUDE_ENV_FILE` is empty in the *tool* shell by design — Claude Code hands it to the
hook and sources its exported vars downstream, so the signal to check is "is
PORT42_PROFILE exported", not "is CLAUDE_ENV_FILE set". `0.2.2` adds
`port42-companion whoami` (prints resolved profile + source + state dir) so this check
is one command.

Still genuinely open (not caused by the bug, and not fixed by it):
- **Fragmentation.** Per-dir scoping means knowledge does not compound across contexts,
  and shared preferences (e.g. "never use em dashes") siloed in one profile never reach
  the others. Decide whether some state belongs in a shared profile every session reads.
- **Stranded `default`.** The historically misrouted writes (site-rescue, Port42
  positioning, the em-dash preference) sit in `default` mixed with the engine's
  consulting state. Decide what to migrate to its proper profile.
- **Framing/skill improvements** shipped (imperative protocol, proactive-write skill).
  Still reasonable, but they were not the blocker; treat their value as unproven until
  routing-fixed sessions accrue write-rate data.

The Stop-hook / instrumentation material below is retained as design notes, but is now
lower priority: with routing fixed, just let restarted (0.2.1+) windows run and read the
named profiles in a few days.

### Decision (2026-06-19): instrument writes, don't nudge yet

Considered building the Stop-hook write-nudge now. **Held off — instrument first,
revisit with data.** Reasoning:

- A *blocking* nudge now inverts the gate above. The tempting reframe — that
  reliable writes are a *prerequisite* for Thread 2's re-litigation metric, not
  something gated behind it — is real, but it argues for **data**, not yet for a
  behavior-changing nudge.
- Dominant risk of a blocking nudge is **manufactured state**: a model told
  "record what crossed the threshold" tends to invent a fold/crease to satisfy
  the prompt, polluting every future deterministic read. We'd pay that cost
  before knowing writes are even flaky.

**Instead:** a *passive* Stop hook that detects the failure mode (substantive
session + zero writes since SessionStart) and only **logs** it — never blocks,
never prompts, can't pollute state. Run it across the live profiles to get the
write-rate data the roadmap says we lack. The blocking nudge is then a ~5-line
change (swap the log line for `{"decision":"block","reason":...}`) once the data
confirms writes are genuinely sparse.

Design notes for the eventual nudge, captured so they're not re-derived:
- **No "session end" event exists** — `Stop` fires at the end of *every* turn.
  Fire-rarely is the whole problem. Guards: bail on `stop_hook_active` (loop
  guard) + a per-`session_id` `.done` marker (at most once per session).
- **Trigger = substantive AND silent.** SessionStart stamps a `.start` marker
  (mtime); Stop fires only if transcript turns exceed a threshold AND no layer
  file's mtime is newer than `.start`.
- **Fail open everywhere** — a companion bug must never block the user from ending.
- **Share profile resolution** — extract the resolver from `session-start.sh`
  into `scripts/resolve-profile.sh`, source it from both, so they can't drift.
- **Nudge text must license "nothing"** as the common, correct outcome and forbid
  invention — mirror the `protocol-inject.md` voice.

Revisit when we have ~a week of write-rate data across the live profiles.

### Diagnosis (2026-06-19): "worked before, not now" — two gaps, not one

Observed live: the flat `default` profile is **depth 2** with rich fold/creases/
engravings (written by the nexus-consulting engine, pre-profile era), while every
per-directory profile booted under the plugin is **depth 0, empty**. So writes
demonstrably worked before and aren't now. Cause is **two compounding failures**,
which we'd been treating as one:

1. **Lost the driver.** The engine ran `claude -p` in a loop and its prompts
   *explicitly* drove writes every run — writing was never discretionary. The
   plugin removed that driver and bet the interactive model would write on its
   own. That bet is losing. The rich `default` state was never evidence the
   *mechanism* works ambiently; it was evidence a *deliberate consumer* works.
2. **Fragmentation dilutes.** Pre-profile, every session fed one store, so writes
   concentrated and compounded (→ depth 2). Per-directory profiles scatter writes
   across 7+ stores; even at an identical write-rate nothing compounds, because
   depth needs many sessions in the *same* dir. Per-dir scoping (sold as pure
   upside) has this hidden cost. Open question: should some contexts share a
   profile, and should `default` be a real shared "me + Gordon everywhere"
   profile rather than a stale catch-all?

This reframes the nudge: it is not "harden a flaky probabilistic feature," it is
**reintroduce the driver the engine used to be** — a lightweight automatic stand-in
for the deliberate write-loop.

A related read-side hazard surfaced the same day: a freshly-booted session that
resolved to `default` loaded the stale 29KB engine state and narrated it as
*current* ("Operator scope came online today…"). Not a hallucination — the state
was real on disk — but stale state with recent-looking dates impersonates live
context. Two follow-ups: (a) retire/segregate the stale `default`; (b) the layer
has **no freshness/expiry signal** — old state reads as current.

### Lever A — framing/tone of the write protocol (cheap, do first)

The *original* protocol (the CLAUDE.md-injected `protocol.md`, now retired) that
drove the rich state was **imperative and verb-first** ("run…", "read before
responding", "just run the commands"). The current injected `protocol-inject.md`
is **permissive and posture-first**: its umbrella line is "Write back to it *as the
session earns it*" — a vague self-judgment that hands the model a permanent out.
Three differences worth porting back:
1. **Kill "as the session earns it"** → imperative tied to concrete triggers.
2. **Re-center on the verb** (a "When to write" frame), keep posture scoped to the
   read preamble only.
3. **Restore an action on-ramp.** Making the read deterministic (hook) removed the
   model's own first CLI call each session — it now never touches the tool until it
   spontaneously decides to write, with no established precedent. Give it a concrete
   early move (e.g. `touch` the crease shaping this turn).
Ranking: real but third behind the two structural gaps; cheap enough to do anyway,
and the cleanest test of "how much is salience vs structure." (Done 2026-06-19:
skill description → proactive-write trigger; `protocol-inject.md` → imperative pass
— "as the session earns it" killed, verb-first, `touch` promoted as the on-ramp.)

### Lever B — skill vs hook (which mechanism fires the write)

Skills are the *designed* "model autonomously decides to invoke a capability"
mechanism, but they route on **task-shaped triggers** (usually user intent). The
companion-write trigger is **introspective and continuous** ("did my model of this
person just change?") — a standing reflex, not a task. A skill helps the model pick
the right tool *once it has recognized a moment*; it does **not** make the model
*recognize the moment*. Recognition is the failing step.

So the principle (confirmed by the hooks guide): **a prompt makes a write *likely*;
a hook makes it *happen*.** Hooks give deterministic firing; the model still supplies
the judgment. Crucially, "deterministic" governs only *whether the evaluation runs*,
never *what it concludes* — "did something cross the threshold?" is always LLM
judgment. The hook is the alarm clock that guarantees the judge shows up; left to
itself the main model, busy with the user's task, hits snooze.

### Lever C — the hook ladder (grounded in code.claude.com/docs/en/hooks)

Current hook events include `UserPromptSubmit`, `Stop`, `PreCompact`/`PostCompact`,
`SessionStart`, `SessionEnd`, plus `PreToolUse`/`PostToolUse`. Two capabilities
change the design space vs the original Stop-nudge sketch:
- **Prompt-based hooks** (`type:"prompt"`): a single-turn LLM evaluation *inside*
  the hook — deterministic check, model judgment, off the main loop's turn budget.
- **Agent-based hooks** (`type:"agent"`, experimental, **tool access**): the hook
  can review the turn and **write the state itself** — the deterministic-*write*
  mechanism we kept saying didn't exist.
- Constraint: plain *command* hooks "cannot trigger tool calls"; their
  `additionalContext` is injected as a plain system reminder. So a bash Stop hook
  can only *nudge*; actually *writing* deterministically needs the agent hook.

Ladder (rung 1 done):

| Rung | Mechanism | Fires? | Writes? |
|---|---|---|---|
| 1 ✅ | Skill proactive description | discretionary | model |
| 2 | `UserPromptSubmit` re-injects imperative protocol every turn | deterministic salience | model (discretionary) |
| 3 | Prompt-based `Stop`/`PreCompact`: "anything unwritten?" → nudge | deterministic check, LLM judgment | model |
| 4 | Agent-based `Stop`/`PreCompact` with tool access | deterministic | **hook writes directly** |

**`PreCompact` is the cadence insight:** it fires right before compaction — exactly
when accumulated understanding is about to be summarized away — so it's a natural
"checkpoint before loss," avoiding the every-turn-nag problem of `Stop`. (SessionStart
already re-fires on `compact` to re-inject after.) The real endgame is **rung 4 at
PreCompact**; rung 2 is the cheapest salience lever. None of this changes the
instrument-first decision — it sharpens what we build once the data justifies it.
