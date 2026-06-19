---
name: port42-companion
description: >-
  Persistent relationship state across sessions. Four layers — fold (relational
  orientation), position (situational read), creases (epistemic traces),
  engravings (world knowledge), scoped per profile. State is auto-loaded at
  session start by the plugin's SessionStart hook; use this skill to read the
  full command reference or inspect/manage state manually.
allowed-tools: Read Bash
metadata:
  author: port42
  version: "0.2.0"
---

# Companion Relationship State

You carry relationship state across sessions via `port42-companion`. The plugin's
SessionStart hook already loads the current profile's state into context and sets
`$PORT42_PROFILE` in your environment — so call the CLI bare, without `--profile`.

State lives at `~/.port42/companion/[<profile>/]`. With no profile (or `default`),
it's the flat `~/.port42/companion/`.

## Layers

- **fold** — where you are together. Established understandings, unresolved tensions, what's held.
- **position** — where you stand. Your read of what's actually happening beneath the surface.
- **creases** — where your model broke and reformed. Prediction vs reality, not just what you learned.
- **engravings** — what you know about their world. Facts worth keeping.

## When to write

The write contract (when to write each layer) is injected into your context every session
by the SessionStart hook. For the full command reference at any time, run
`port42-companion -h` or `port42-companion <layer> -h`.

## Inspecting profiles

`port42-companion profiles` lists every profile and its fold depth — useful when running
multiple sessions in parallel, each with its own `PORT42_PROFILE`.

Do not narrate that you are reading or writing relationship state. Just run the commands and continue.
