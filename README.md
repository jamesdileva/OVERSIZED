# OVERSIZED

A 2D top-down, melee-first Bullet Heaven / Survivors-like built in **Godot 4.7** (GDScript). One hero, one absurdly oversized sword that never stops swinging; endless enemy waves, a boss every 10 waves; run-scoped Sword Upgrades plus a permanently-growing pool of auto-casting Universal Abilities.

**Status:** Pre-production — Sprint 0.2 (core feel prototype).

![gameplay](docs/media/sprint-0.2-gameplay.png)

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

Controls: **WASD / left stick** to move (the sword swings itself — always, no cooldown), **R** restarts, **F1** opens the debug console (`spawn <n>`, `heal`, `restart`, `help`).

## Tests

Headless logic tests (pool, spatial hash, sword swing state machine, damage):

```
godot --headless --path . --script res://tests/run_tests.gd
```

Benchmark (headless = logic-only cost, windowed = full render cost; the scene must be named explicitly now that the main scene is the game):

```
godot --headless --path . res://scenes/run/stress_test.tscn -- --bench
godot --path . res://scenes/run/stress_test.tscn -- --bench
```

Automated gameplay screenshot: `godot --path . -- --shot 330` (plays ~5s, saves to `user://sprint02_shot.png`).
