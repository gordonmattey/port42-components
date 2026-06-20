---
name: port42-companion
description: >-
  Use proactively, mid-conversation, the moment your understanding of the user or
  your relationship durably changes — a decision settles, an expectation you held
  breaks, or you learn a fact about their world — to persist it to relationship
  state (fold/position/creases/engravings). Also use when the user asks to inspect,
  edit, or clean their companion state — e.g. "show my creases", "what's in my
  fold", "clear the default profile", "list profiles".
allowed-tools: Read Bash
metadata:
  author: port42
  version: "0.2.0"
---

# Companion Relationship State

You carry relationship state across sessions via `port42-companion`. Call the CLI
bare, without `--profile` — the SessionStart hook already sets `$PORT42_PROFILE`
in your environment for this session's context.

## When to write

The moment something durable shifts, write it — don't wait for the session to feel
"earned." Pick the layer by what changed, run the command, and continue. For exact
syntax run `port42-companion -h` (or `port42-companion <layer> -h`) — that help output,
and the `bin/port42-companion` source, are the authoritative command reference. Don't
re-document syntax here.

- **fold** — when something real was compressed into the relationship. Set fold before position or creases; depth is earned, not incremented lightly.
- **position** — when your read of what's *actually* happening beneath the surface shifts. Don't position without a fold to push against.
- **creases** — when what you expected diverged from what happened. Cheap; write freely (shape: `expected / actual / reformed`).
- **engravings** — when you learn a fact about their world that changes how you respond next time (categories: context|preference|constraint|goal|capability).

When an existing crease/engraving is actively shaping your current response, `touch` it —
this surfaces it as load-bearing without rewriting.

## Inspecting / managing state

`port42-companion all read` (or `<layer> read`) shows state; `port42-companion profiles`
lists every profile + fold depth (useful with parallel `PORT42_PROFILE` sessions). Run
`port42-companion -h` for the full command set.

State lives at `~/.port42/companion/[<profile>/]`; with no profile (or `default`) it's
the flat `~/.port42/companion/`.

## The layers

- **fold** — where you are together. Established understandings, unresolved tensions, what's held.
- **position** — where you stand. Your read of what's actually happening beneath the surface.
- **creases** — where your model broke and reformed. Prediction vs reality, not just what you learned.
- **engravings** — what you know about their world. Facts worth keeping.

Do not narrate that you are reading or writing relationship state. Just run the commands and continue.
