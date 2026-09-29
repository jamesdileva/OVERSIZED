# OVERSIZED

A 2D top-down, melee-first Bullet Heaven / Survivors-like built in **Godot 4.7** (GDScript). One hero, one absurdly oversized sword that never stops swinging; endless enemy waves, a boss every 10 waves; run-scoped Sword Upgrades plus a permanently-growing pool of auto-casting Universal Abilities.

**Status:** Pre-production — Sprint 0.1 (horde performance spike).

## Docs

- [`docs/architecture.md`](docs/architecture.md) — concept, design pillars, systems, data model, risks
- [`docs/implementation-guide.md`](docs/implementation-guide.md) — Godot patterns, folder structure, horde-performance approach
- [`docs/sprint-roadmap.md`](docs/sprint-roadmap.md) — phase order, sprint contents, definitions of done
- [`AGENTS.md`](AGENTS.md) — how agents contribute: sprint workflow and hard rules
- [`worklog.md`](worklog.md) — one entry per completed sprint

## Running

Open the project in Godot 4.7.x, or:

```
godot --path .
```

Debug console toggles with **F1**. Commands: `stress_test <n>` (activate n enemies, full sim), `render_only <n>` (n enemies, AI off — render pipeline isolated), `clear`, `bench` (count-sweep benchmark, prints results and quits), `help`.

## Tests

Headless logic tests (pool, spatial hash, sim sanity):

```
godot --headless --path . --script res://tests/run_tests.gd
```

Benchmark (headless = logic-only cost, windowed = full render cost):

```
godot --headless --path . -- --bench
godot --path . -- --bench
```
