# AGENTS.md

Working agreement for AI agents (and humans) contributing to **Oversized** — a 2D top-down, melee-first Bullet Heaven / Survivors-like built in **Godot 4.7.x (GDScript-first, C# as escape hatch)**. One hero, one absurdly oversized sword that never stops swinging; endless enemy waves, a boss every 10 waves, and two independent progression tracks: run-scoped Sword Upgrades (reset every run) and a permanently-growing pool of auto-casting Universal Abilities (gated by persistent Mastery Rank). Target: PC / Steam, premium, single-player. "Oversized" is a placeholder title.

## Project documents

Read in this order — they are the source of truth for everything not written here:

| Doc | Role |
|---|---|
| `docs/architecture.md` | The "why" — concept, design pillars, core loop, systems, data model, risks, non-goals |
| `docs/implementation-guide.md` | The "how" — Godot patterns, folder structure, horde-performance approach, testing strategy |
| `docs/sprint-roadmap.md` | The "when" — phase order, per-sprint contents, Definitions of Done |

Current repo state: **docs only.** No Godot project exists yet; the first sprint is Sprint 0.1 (horde performance spike).

## Sprint workflow — every sprint, in this order

1. **Plan + scope.** Pull the sprint's task list from `docs/sprint-roadmap.md` and its Definition of Done. Write out the concrete scope and confirm it before writing any code. Anything not in scope goes to a later sprint — never into the current one.
2. **Implement + verify (test).** Build it, then prove it works. Verification follows `docs/implementation-guide.md` §14: a playable build every sprint (feel is judged by playing, not code review), plus the performance profiling checklist any time the horde system changes. A sprint is not done when the code compiles — it is done when its DoD passes.
3. **Commit + push.** Commit the verified work with a message referencing the sprint number (e.g. `Sprint 0.1: horde perf spike — 500 concurrent enemies at 60fps`). Push to the remote. Never commit unverified work.
4. **Update `worklog.md`.** Append a dated entry: what was scoped, what was built, what was verified (with actual test/profiling results), what was deferred, and any decisions that should flow back into the docs.

Then close the loop: review the sprint result together and agree the next sprint's scope before starting it.

**Note on `worklog.md`:** it does not exist yet — no sprints have been completed (the repo is docs-only so far). Create it when the first sprint (Sprint 0.1) completes, with that sprint as the first entry. Do not create it early or backfill it.

**Note on git:** this repo is not yet a git repository. Initializing git (and adding a remote, once one exists) is part of starting Sprint 0.1, so the first verified sprint has a repo to commit and push against.

## Hard rules (carried from the docs — do not violate)

- **Cosmetics carry zero stats.** `CosmeticItemDef` has no stat fields, enforced at the schema level. Power never sneaks into a skin. (`architecture.md` §3/§6, `implementation-guide.md` §11)
- **Content is data, not code.** All tunable content (Sword Upgrades, Universal Abilities, enemies, waves, bosses, cosmetics) lives as `.tres` Resource files loaded by `ContentLoader`. "Add content" means adding `.tres` files, not writing scripts. (`implementation-guide.md` §3)
- **Enemies never use physics bodies at scale.** Object pooling + manual position updates + a uniform-grid spatial hash for neighbor queries + `MultiMeshInstance2D` rendering decoupled from logic. Never `instantiate()`/`queue_free()` mid-combat. This is the project's #1 technical risk and its most important pattern. (`implementation-guide.md` §6)
- **All damage routes through one pipeline**, so crits, elemental effects, and on-hit hooks apply uniformly regardless of source (sword or auto-cast ability). (`architecture.md` §7)
- **The sword never has a cooldown.** Windup → Active → Recovery → Windup, forever. Attack-pace upgrades shorten windup/recovery; they don't add cooldowns. Universal Abilities are the opposite: always on individual cooldowns, never player-triggered. (`implementation-guide.md` §5.1, §7)
- **Saves carry a `schema_version` field from the very first file written.** (`implementation-guide.md` §10)
- **v1.0 non-goals hold:** no multiplayer, no console ports, no mod support, no narrative, no hand-crafted level layouts. (`architecture.md` §12)
- **Phases are scope-gated, not date-gated.** A phase ends when its Definition of Done is true, not when a calendar says so. Sprint 0.1 was a hard go/no-go checkpoint — resolved with a go (see `worklog.md`). (`sprint-roadmap.md` §1, §3)

## Verification expectations

- Performance checklist whenever the horde system changes: frame time at 0 / 100 / 300 / 500 concurrent enemies; physics collision-pair count near zero; MultiMesh draw-call count.
- Build the debug console early (Phase 1, not Phase 3): `spawn_wave <n>`, `grant_xp`, `grant_currency`, `god_mode`, `stress_test <n>`. (`implementation-guide.md` §13)
- Long-session smoke test (bot holding "move toward nearest enemy") to catch pool exhaustion, leaks, and crash-after-N-minutes bugs that short playtests miss.
