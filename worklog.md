# Worklog

One entry per completed sprint, appended in order. Format per `AGENTS.md`: scope, what was built, what was verified (with results), deferred items, and decisions that flow back into the docs.

---

## Sprint 0.1 — Horde performance spike (2026-09-28)

**Scope** (from `sprint-roadmap.md`, Phase 0 — Sprint 0.1): engine/project setup per `implementation-guide.md` §1–2; build the object-pooling + manual-position + spatial-hash pattern in isolation (no gameplay — dots seeking a point); add the `stress_test <n>` debug command; render via `MultiMeshInstance2D` from the start. **DoD**: a hard, measured number for concurrent enemies at 60fps — this sprint is a go/no-go checkpoint.

**Built**

- `project.godot` — Godot **4.7.2** (winget install, version verified), Forward+ renderer, input map: WASD + left-stick movement, dash action reserved (keyboard + gamepad button).
- `scripts/horde/spatial_hash.gd` — uniform-grid spatial hash over the flat position array; cells stored as reference Arrays so hot loops iterate without copying; cell arrays reused across frames.
- `scripts/horde/horde_sim.gd` — pooled flat-array enemy sim: active slots `[0, active_count)`, swap-remove despawn, seek + bounded separation via 3×3-cell hash queries, arena clamp. No physics bodies, no per-enemy nodes. Capacity 10,000.
- `scripts/horde/horde_renderer.gd` — single `MultiMeshInstance2D`, transforms pushed from the sim arrays each frame, generated dot texture; fully decoupled from sim logic.
- `scenes/run/stress_test.tscn/.gd` — spike scene: WASD/stick moves the target, HUD (fps / frame ms / active count), debug-console commands, benchmark harness with per-count screenshots.
- `autoload/debug_console.gd` — F1 console; commands: `stress_test <n>`, `render_only <n>`, `clear`, `bench`, `help`.
- `tests/run_tests.gd` — headless logic test suite (19 tests).
- `docs/media/sprint-0.1-bench-*.png` — benchmark evidence screenshots (500 / 2000 enemies).

**Verified**

- Headless test suite: **19/19 pass** — pool invariants (spawn/despawn/capacity/swap-remove integrity vs mirrored model), spatial-hash query correctness vs brute force, no stale entries across repeated rebuilds, sim convergence (avg distance 605 → 33 px over 300 steps) and state consistency through mid-run despawns.
- Benchmark (one sim step per rendered frame, vsync off, count sweep 100→8000):

| Count | Windowed avg (RX 6400, Vulkan) | Headless avg |
|---|---|---|
| 100 | 0.88 ms (1141 fps) | 6.90 ms* |
| 300 | 1.86 ms (538 fps) | 6.90 ms* |
| 500 | 4.09 ms (244 fps) | 6.90 ms* |
| 1000 | 6.49 ms (154 fps) | 7.01 ms* |
| 2000 | 14.38 ms (70 fps) | 14.67 ms |
| 4000 | 36.10 ms (28 fps) | 37.72 ms |
| 8000 | 88.73 ms (11 fps) | 98.24 ms |

\* headless numbers floored by Godot's headless idle-sleep (6.9 ms/frame), so low-count costs are even lower than shown.

**Result / DoD**: ~**2,200 concurrent enemies at 60fps** (2,000 confirmed at 70 fps / max 18.9 ms; 4,000 at 28 fps; interpolated 60 fps ceiling ≈ 2,200–2,400), in pure GDScript, versus the 300–500 design target from `implementation-guide.md` §6. **Go decision** — no engine escape hatch (C#/GDExtension) needed for the v1.0 content budget; the collision-pair count is structurally zero (no physics bodies exist) and the MultiMesh layer is a single draw call per archetype.

**Findings worth keeping**

- The benchmark caught a real bug the unit tests missed: spatial-hash cells accumulated stale indices across frames (keys were only recorded on cell *creation*, so from the third rebuild onward cleared-once cells were never cleared again) — separation iterations ballooned to ~15,000–28,000 per enemy and the "ceiling" looked like ~300 enemies. Fixed by recording any cell that is empty at insert time; regression test `repeated rebuilds do not accumulate entries` added. Lesson: in a numbers-heavy genre, perf harnesses are correctness tests too.
- Godot's physics catch-up (up to 8 steps/frame) spirals once a `_physics_process` step exceeds ~2× the frame budget — a bench that lets physics catch up measures the spiral, not the game. The bench therefore drives exactly one sim step per rendered frame (equivalent to steady-state 60fps). Worth remembering when real gameplay moves into `_physics_process`: keep per-step cost under budget or clamp `physics/common/max_physics_steps_per_frame`.

**Decisions & deviations**

- **Controller support added mid-sprint** (requested): gamepad bindings live in the input map from day one (left stick movement, face-button dash reserved) and docs updated — `implementation-guide.md` §1 states basic gamepad support is in scope; `sprint-roadmap.md` gains gamepad tasks in Sprint 0.2 and a "gamepad-playable" clause in the Vertical Slice DoD. Full remapping remains a v1.0 non-goal.
- `stress_test <n>` activates enemies **with** sim AI (the roadmap's "no AI" definition would not have exercised the spatial hash, which is the risk being de-risked); added `render_only <n>` for the pipeline-isolation case the roadmap described.
- Vsync disabled as the project default during the spike so frame-time measurements are honest; revisit when juice/pacing work starts.
- Bench auto-runs on any headless launch (a headless run is always automated here) or via `--bench`; headless plus a per-frame physics catch-up spiral made a flag-only trigger unreliable.

**Deferred**

- Neighbor-iteration micro-optimizations (symmetric pair trick, inline dict access) — not needed at current numbers; documented as headroom for later.
- C# / GDExtension escape hatch — not needed; re-evaluate only if target hardware floor (Steam Deck-class) fails at higher enemy counts.
- Splash/loading screen, project icon, license file.

**Next**: Sprint 0.2 — core feel prototype (player movement, sword swing state machine, one enemy type, damage numbers, hit-stop/screen-shake; gamepad-playable from the start). DoD: "is swinging a big sword at a crowd of guys fun for five straight minutes with zero other systems?"

---

## Sprint 0.2 — Core feel prototype (2026-09-28)

**Scope** (from `sprint-roadmap.md`, Phase 0 — Sprint 0.2): player movement, the sword swing state machine (`implementation-guide.md` §5.1), one enemy type, basic damage numbers, screen-shake/hit-stop juice on the swing; gamepad-playable from the start. No meta, no progression screens. **DoD**: the five-minute fun question — answerable only by playing.

**Built**

- `scripts/combat/sword_swing.gd` — pure-logic swing state machine: Windup → Active → Recovery → Windup forever, alternating sweep direction, no cooldown gate. Sub-frame remainders are carried across transitions so the cycle rate is exactly 1/(windup+active+recovery) over time (a frame-quantization drift of ~6% was caught by the cycle-rate test and fixed).
- `scenes/run/player/sword.gd` — hash-based hit detection per `implementation-guide.md` §5.2's scaling approach: `circle_candidates` around the hero (radius > cell size supported), exact reach + sweep-window tests, one hit per enemy per swing (per-slot flags), auto-aim at the nearest enemy at swing start. Placeholder blade + arc-smear custom drawing.
- `scripts/horde/horde_sim.gd` — extended with `healths`/`hit_flash` arrays, `damage()` (flash + knockback along hit direction + `enemy_killed` signal before the swap-remove), flash decay in the step loop.
- `scripts/horde/spatial_hash.gd` — `circle_candidates(center, radius)`: superset query that expands cell rings for radii larger than cell_size (the sword reaches 155px over 48px cells).
- `scenes/run/player/player.gd` — accel/friction 8-direction movement, HP, contact damage with i-frames, death → auto-restart. Manual position updates: the whole scene still contains zero physics bodies.
- `scenes/run/run.gd` + `run.tscn` (now the main scene) — spawner keeping a visible crowd near the camera view edge, HUD (HP bar / fps / enemies / kills), R restart, console commands `spawn`/`heal`/`restart`, `--shot <frames>` automated screenshot mode.
- Juice: pooled damage numbers (rise/fade, bigger on kill), trauma² camera shake, 45ms hit-stop on kill (time-scale dip with an ignore-time-scale restore timer).
- `scripts/horde/horde_renderer.gd` — per-instance color so hit-flash tints enemies toward white.

**Verified**

- Tests: **27/27 pass** — pool, hash (incl. circle-candidates superset vs brute force at radius > cell), swing machine (never idles across 3,600 ticks; cycle rate 154.0 vs 153.8 expected; hit-window leads/trails the blade edge correctly), damage/death (flash, knockback, kill signal, swap integrity).
- Boot-check of the main scene headless: zero script errors (added to AGENTS.md verification expectations after this sprint's parse-error escape — see findings).
- Performance checklist re-run after sim changes (required by `implementation-guide.md` §14): windowed 500 → 3.30 ms, 1000 → 7.51 ms, 2000 → 15.30 ms — the ~2,200 @ 60fps ceiling holds; per-instance flash colors cost nothing measurable.
- Automated gameplay run (`--shot 330`): 32 kills in 5.5s with the crowd replenishing; screenshot in `docs/media/sprint-0.2-gameplay.png` shows sword mid-sweep with smear, damage numbers fading, an enemy mid hit-flash. Hand-verified by both of us in interactive play: movement feel + gamepad (left stick) confirmed working.

**Findings worth keeping**

- **`PackedBoolArray` does not exist in Godot 4.7.2's GDScript** — even a bare type annotation fails to parse (verified in isolation). Use `PackedByteArray` for per-slot bool flags. The isolated repro also confirmed the parse failure was engine-side, not project-side.
- **A parse error in one script can half-load a scene**: the first `--shot` run launched, player + gamepad worked (their classes compiled), but the sword/spawner/HUD never came up and nothing auto-quit — it looked "fine" until compared against intent. Hence the new AGENTS.md rule: boot-check the main scene headless and read the output every sprint.
- **Missing render layer class of bug**: the enemies were fully simulated and killable before `HordeRenderer` was added to the run scene — kills and damage numbers worked while nothing enemy-shaped was visible. Perf and logic tests can't catch a missing `add_child`; the automated screenshot can. Keep `--shot` in the verification routine.
- The stationary bot dies in ~7s to a close-spawning crowd — contact damage/i-frames/knockback all work; balance is a Phase 3 concern.

**Decisions & deviations**

- Spawn ring tightened to 380–560px (near the camera view edge) with a floor of 18 enemies — the first screenshot showed zero enemies in frame at 500–900px; the genre needs the crowd visible.
- Bench invocation now names the scene explicitly (`res://scenes/run/stress_test.tscn`) since the main scene is the game; README updated.
- The sword auto-aims its arc at the nearest enemy per swing — a feel call (the hero's only input is movement; a blindly swinging sword would whiff constantly).

**Deferred**

- Dash/dodge (input action reserved, no behavior) — candidate for Sprint 0.3 if the feel needs it, else Phase 1.
- Enemy variety, real art, audio, XP/leveling — Phase 1+ per roadmap.

**Verdict on the DoD question** — needs more hands-on time, but first impressions (both of us): swinging the oversized sword into a crowd with shake/hit-stop/numbers reads great. Tuning knobs (windup/active/recovery, reach, damage, knockback) are all plain fields on `SwordSwing`/`Sword`/`HordeSim` for fast iteration.

**Next**: playtest Sprint 0.2 for feel, tune the knobs; then Sprint 1.1 — wave loop + Sword Upgrade picks (WaveDef-driven Wave Director, timer-based wave clear, the shared choice-screen component, 5–8 real Sword Upgrades as `.tres` files).

---

## Sprint 1.1 — Wave loop + Sword Upgrade picks (2026-09-28)

**Scope** (from `sprint-roadmap.md`, Phase 1 — Sprint 1.1, approved before build): Wave Director reading `WaveDef` resources; timer-based wave clear; the shared choice-screen component; 8 real Sword Upgrades incl. both combo-archetype proofs; the no-cooldown dash. Out of scope: XP/abilities + boss (1.2), currencies/meta/save (1.3), new enemy types, real art.

**Built**

- Content foundation (`implementation-guide.md` §3): `SwordUpgradeDef` + `WaveDef` Resource schemas; `ContentLoader` autoload scanning `resources/sword_upgrades/` and `resources/waves/`; `EventBus` autoload (wave/upgrade signals). Eight upgrades + five waves exist purely as `.tres` files.
- `scripts/combat/upgrade_effects.gd` — effect_id → handler registry (reach, arc, cadence, damage, knockback, leech, spin cadence, combo threshold) + the rarity-weighted, stack-aware offer roller. New effect *mechanisms* add a branch; new *content* adds only `.tres` (the fully no-code pipeline is Phase 2 by design).
- `scenes/run/wave_director/wave_director.gd` — timer-based clear while enemies keep spawning (architecture §4); survivors despawn Brotato-style at clear (no payout until 1.3); waves 1–5 authored, endless scaling by curve past wave 5 (denser/tougher/faster, capped).
- `scenes/ui/choice_screen/choice_screen.gd` — the shared pick component: 3 cards, run paused, mouse + gamepad navigation (first card auto-focused, `ui_*` navigates), shows owned stack counts. Data-agnostic on purpose — ability picks (1.2) reuse it unchanged.
- Combo archetype live: `ComboCounter` (pure logic — consecutive landed hits, whiff swing resets) + **Spin Finisher** (every 4th swing sweeps 360°) + **Combo Burst** (15 consecutive hits → AoE shockwave around the hero, `BurstRing` visual, extra shake/hit-stop).
- **Dash** (player.gd): no cooldown — the only gate is the dash itself finishing (~0.13s, ~150px), brief i-frames, direction from current input or last movement. Zero changes to the sword: decoupled systems mean dashing can't interrupt the swing, exactly as designed.
- HUD: wave number + timer, kills, combo counter (visible once a combo upgrade is owned). Console gained `wave <n>` for testing late waves.

**Verified**

- Tests: **40/40 pass**, including a new first-class guard: every critical script is `load()`ed and `can_instantiate()`-checked, because a parse error aborts any test touching its class *silently* — this sprint's first run "passed" while `wave_director.gd` was broken; the guard makes that a visible FAIL.
- Boot-check of the main scene headless: zero script errors.
- Bench re-run after spawner changes: 2000 → 16.58 ms (≈60 fps) headless — the ~2,200 @ 60fps ceiling holds.
- Automated screenshots (`docs/media/`): the paused choice screen over a dimmed run (three distinct cards, first focused) and wave-1 gameplay with the timer HUD. Both captures surfaced real bugs on first try: the shot timer originally froze with the paused tree (moved to an ignore-time-scale timer), and shortening `WaveDef.duration` didn't move the already-copied `time_left` (shorten the clock, not just the def).

**Findings worth keeping**

- **The test suite had a silent-skip hole**: a script with a parse error aborts any test function that touches its class, and the remaining checks simply never run — the suite still printed PASSED. Caught only because the import output was read (per the AGENTS.md boot-check rule added in 0.2). The script-compile guard test now converts this class of bug into a normal FAIL.
- **Float drift in timers**: 30 ticks of `1/30s` don't sum to exactly 1.0s in float64 — the wave timer crosses zero one tick late. Irrelevant at 60fps, but tests that assert exact crossings must allow the +1 tick.
- Wave-clear despawn was pre-approved as Brotato-style with no payout; when Runeshards arrive in 1.3, revisiting "clear bonus for surviving enemies" is a cheap dopamine win worth considering.

**Decisions & deviations**

- The three pre-approved scope defaults held: despawn-on-clear without payout, 3-card offers, waves 1–5 authored + curve scaling.
- Upgrade `Swift Strikes` stacks multiplicatively with a 0.05s floor; `Spin Finisher` stacks shorten the cadence (4 → 3 → 2); `Combo Burst` stacks lower the threshold (15 → 12 → 9, floor 6).
- The automated screenshot mode now shortens wave 1 so the choice screen can be captured; the countdown runs on a process-always, ignore-time-scale timer.

**Deferred**

- XP/leveling + Universal Ability picks + the wave-10 boss (Sprint 1.2); Runeshards/Glory + meta hub + save (1.3); new enemy types (Phase 2); real art.
- Choice-screen polish (card icons, rarity colors) — deferred until ability picks share the component.

**Next**: Sprint 1.3 — meta loop + run-loop polish: death → Run Summary (Hero XP + Glory) → minimal hub with a stub loadout screen → menu, basic save/load with `schema_version`, restart flow. That closes the full Vertical Slice Definition of Done loop.

---

## Sprint 1.2 — Leveling + Universal Ability picks + wave-10 boss (2026-09-29)

**Scope** (from `sprint-roadmap.md`, Phase 1 — Sprint 1.2, approved before build; first sprint under the deep-dive-merged docs): XP/leveling; 8 abilities on the new `UniversalAbilityDef` schema (`kind`/`ap_cost`/`unlock_level`/`tags`/`max_rank`); wave-10 boss with telegraphed patterns. Pre-approved defaults: passives come via level-up cards until loadouts land (2.2), XP is physical pickups, boss waves clear on boss death with an enrage soft-timer, overlapping choices queue.

**Built**

- `UniversalAbilityDef` schema + 8 abilities as `.tres`: actives **Orbiting Blades** (persistent hazard, no cooldown), **Ground Slam**, **Spirit Blade** (homing projectile), **Lightning Strike**; passives **Vitality**, **Swift Boots**, **Lodestone**, **Scholar's Wit**. Tags ride as data (behavior in 2.1/2.4); `ap_cost`/`unlock_level` inert until Hero Level (2.2).
- `AbilityCaster` (pure-ish node): cooldown ticking, from-scratch passive recompute (reset bases → reapply — no delta bookkeeping), persistent orbit node management, AoE + boss-damage callbacks; visuals delegated to the run via `effect_visual` so tests run headless.
- XP: `XpGems` pooled pickups (magnet radius, ring-slot reuse) fed by `sim.enemy_killed`; `RunLevels` pure XP curve (`5 + 6n + n²` per level); level-ups open 3 ability cards through the shared choice screen; overlapping level-ups queue behind an open choice.
- Choice screen generalized: `open(title, offers, owned)` + the offer roller duck-types `max_stacks`/`max_rank`, so both def types share one component.
- Wave-10 boss: `BossDef` resource (with reserved `champion_modifier_slots`), `BossBrain` pure phases (66%/33%) + enrage soft timer, `Boss` node with alternating telegraphed charge/slam in the hostile hue, boss-only wave-clear, magenta boss HP bar; waves 6–10 authored (wave 10 references the boss); sword sweeps + ability AoEs damage the boss via a callback (it's deliberately outside the pooled sim).
- HUD: XP bar + level, boss bar; console gained `give_xp`.

**Verified**

- Tests: **51/51 pass** — content (8 upgrades + 8 abilities + waves 1–10 + wave-10 boss reference), RunLevels monotonicity/round-trip, BossBrain phase boundaries (66.7% still phase 1, enrage at timer, per-phase speed), AbilityCaster (Vitality 120→140 HP, Swift Boots 324 speed, ground-slam fire damages in range, cooldown reset, max-rank refusal), duck-typed roller excludes maxed abilities.
- Boot-check headless: zero script errors. Bench: 2000 → 16.6 ms (≈60 fps) — ceiling holds.
- Screenshots (`docs/media/`): the **LEVEL 2 — CHOOSE AN ABILITY** screen with boss bar visible, and the boss fight (Warden engaged, sword connecting, HP bar dented).

**Findings worth keeping**

- **Typed signals reject sibling types at runtime**: `EventBus.upgrade_selected(def: SwordUpgradeDef)` errored the moment a UniversalAbilityDef was emitted. Cross-def signals are now untyped by design — typed signals are for single-type contracts.
- `.tres` loads return **Resource instances**, not GDScripts — `can_instantiate()` doesn't exist on them; content tests assert fields instead.
- The old `EventBus`/duck-typing work confirms the 1.1 harness guard pays off: this sprint's parse errors surfaced in the import log immediately, and no test silently skipped.
- Interim passive model (cards) is one flag away from the 2.2 model: `AbilityCaster._refresh_passives` recomputes from the taken map, so "equipped-only" becomes a filter on that map, nothing else.

**Decisions & deviations**

- All four pre-approved defaults held (interim passive cards, XP pickups, boss-death-only clear + enrage speedup, choice queueing).
- UniversalAbilityDef gained `rarity_weight` — the duck-typed roller needs it, and 2.4's synergy bias multiplies it.
- The automated shot mode gained `--boss` (jumps to wave 10); captures showed the level-up screen arrives before the wave-1 clear in normal mode, so ability-screen evidence comes from boss-mode runs.

**Deferred**

- Run Summary → hub → save (Sprint 1.3 closes the vertical-slice meta loop with Hero XP + Glory).
- Loadout/AP gating + passives-on-from-start (2.2); tag behavior (2.1); new enemy types (2.3).
- Boss telegraph variety (one charge + one slam now); champion modifiers (2.3+).

**Next**: Sprint 1.3 — meta loop + run-loop polish: death → Run Summary (Hero XP + Glory) → minimal hub with a stub loadout screen → menu, basic save/load with `schema_version`, restart flow. That closes the full Vertical Slice Definition of Done loop.
## Sprint 1.3 — Meta loop + run-loop polish (2026-09-29) — VERTICAL SLICE COMPLETE

**Scope** (from `sprint-roadmap.md`, Phase 1 — Sprint 1.3, approved before build): GameManager state machine; main menu; Run Summary with rewards; Meta Hub with loadout stub; `MetaProgression` save system with `schema_version`; death-flow rework; the long-session bot smoke test. All five pre-approved defaults held (GameManager now, Hero Level as number+curve, one JSON save with corrupt-fallback, R stays instant-restart, time-accelerated bot).

**Built**

- `autoload/game_manager.gd` — the formal Menu → Run → Summary → Hub state machine (architecture §7), scene transitions, automation skips (launch flags jump straight into the run), bot elapsed-time bookkeeping (survives run reloads), and `--ui_shot` capture mode for the UI scenes.
- `autoload/meta_progression.gd` — one JSON save in `user://` carrying **`schema_version` from the very first write** (the §10 hard rule, finally exercised); `load_save` resets to defaults before parsing, so corrupt or newer-versioned files yield a fresh profile instead of half-state or a crash; `record_run` applies Hero XP (~waves×8 + kills×0.3 + bosses×25) and Glory (~waves×2 + kills/10 + bosses×10), tracked best-wave/totals, saves.
- `scenes/ui/` — main menu (title, Start Run, Quit), Run Summary (stat block + rewards + Continue), Meta Hub (Hero Level progress bar, Glory/stats, Start Run, **loadout stub** naming Sprint 2.2, Back to Menu). All gamepad-first: first button focused, `ui_*` navigation.
- Death flow: death → "YOU DIED" → Summary → Hub → Menu. R mid-run remains an instant dev-restart.
- **Bot smoke test** (`--bot <minutes>`): invulnerable nearest-enemy-seeking bot at 8× time acceleration, auto-picking every choice screen, auto-restarting on (now impossible) death, logging fps/memory every 60 sim-seconds.

**Verified**

- Tests: **61/61 pass** — meta save round-trip, `schema_version` present in the first write, corrupt-JSON fallback to fresh, newer-schema fallback, scene existence per state, plus all prior suites.
- Boot-check headless: zero script errors (now boots the menu).
- Bench: 8000 → 90.7 ms — ceiling holds.
- **Bot smoke test: 900 sim-seconds (15 min), wave 10 reached, 1,346 kills, zero script errors, memory flat 30.9 → 31.1 MB, fps pinned at the headless cap.** Full progression exercised: wave clears, auto-picked upgrades, auto-picked level-ups with passives online, the wave-10 boss.
- UI screenshots (`docs/media/`): menu, hub (level progress + stats + stub), summary (stat block + rewards).

**Findings worth keeping**

- **The kamikaze-bot lesson**: a naive "move toward nearest enemy" bot dies on contact every few seconds, so a 15-minute session never leaves wave 1 — it exercises death/reload but none of the progression systems. The bot is now invulnerable so the session covers choices, abilities, passives, and the boss. A smoke test must exercise the systems you're worried about, not just run for a long time.
- **The bot's first auto-picked passive caught a real 1.2 bug within minutes**: `AbilityCaster` writes `xp_magnet_radius`/`xp_mult` onto the run scene, which never declared those members — the 1.2 tests used a fake dictionary for the run context, and no human had picked Lodestone yet. Two fixes: the missing vars, and a durable lesson — test doubles should be the same type as the real thing (or the code should take plain params) so member typos can't hide.
- Bot/automation runs deliberately skip `record_run` so test sessions never pollute the real meta save.

**Decisions & deviations**

- All five pre-approved defaults held; no scope additions crept in.
- Hub Glory display shows the balance only — spending arrives with cosmetics (2.5).

**Vertical Slice DoD — every element now true**: one hero; base swing + ≥5 upgrades across a run; ≥5 Universal Abilities available; waves 1–10 playable; unique wave-10 boss; death → summary → currency → hub → menu loop; gamepad-playable throughout; 15-minute session with no crashes (bot-verified). The slice is functionally complete on placeholder art.

**Next**: Phase 2 per the roadmap — Sprint 2.1 (tag & effect foundation: `Tags` bitmask on hit events, two-category damage math, three statuses in the horde layer) is the "never cut" foundation everything else builds on. Before that: both of us play the slice end-to-end and log feel/pace issues to carry into 2.x tuning.

---

## Hotfix — playtest findings (2026-09-29, post-slice playtest)

Both of us played the full loop (user reached wave 12/13 and reported; bot verified). Findings + fixes, committed as `fix: actives never fired; orbit blades didn't follow or tick`:

- **All four actives were dead on arrival** — my 1.2 code wrote `tick()` but never the `_physics_process` that calls it, so cooldowns never counted down and nothing ever cast (Ground Slam, Lightning Strike, Spirit Blade: "not sure they worked" — correct, they didn't).
- **Orbiting Blades were stationary at world origin** — `AbilityCaster` extended plain `Node`, cutting its Node2D children off the player's transform chain. Now Node2D; blades follow the hero.
- **The arena boundary existed (player clamps) but nothing drew it** — a border is now drawn; proper art in Phase 3.
- Confirmed working in the same playtest: lifesteal, Combo Burst, Reach Up, Swift Strikes, dash, XP/level-ups, summary/hub loop, gamepad.

Verification: 61/61 tests (new invariant: caster is Node2D); 3-sim-minute bot went **wave 6 / 342 kills** (pre-fix pace was ~1 kill per life); screenshot `docs/media/hotfix-abilities-firing.png` shows the orbit ring on the hero and Ground Slam's rank-1 damage (18s) landing on the boss.

**Lesson for 2.x:** nothing in the 1.2 suite could catch a missing engine callback — the compile guard checks scripts parse, not that they're driven. When a system is "pure logic + a caller," the caller deserves its own assertion. Also: the playtest's negative reports ("didn't seem to work") were precise enough to diagnose all three symptoms from one cause — worth encouraging that specificity in future playtests.

---

## Sprint 2.1 — Tag & effect foundation (2026-10-01)

**Scope** (from `sprint-roadmap.md`, Phase 2 — Sprint 2.1, approved before build): `Tags` enum + bitmask helpers; hit-event pipeline carrying `tag_mask`; two-category damage math; status arrays in the horde layer with three statuses (Burn, Chill, Bleed); tags on all existing Sword Upgrade and Ability definitions. Art lane: tag→color map, asset-tracker stub, import presets, sourcing decisions. Pre-approved defaults held: statuses apply at damage-time from source tags, exactly three statuses, Chill via movement multiplier, one run-scoped damage-mod pool.

**Built**

- `scripts/combat/tags.gd` — 24-tag enum, `mask`/`has`, `ALL_MASK` for validation, and the tag→color language as constants (Fire orange, Frost cyan, Shock yellow, Poison green, Blood crimson; hostile red-magenta stays reserved for enemies).
- `HordeSim`: `hit_event(pos, amount, tag_mask)` signal; `damage()` now routes through `modified()` — `base × (1 + Σ increased[tag]) × Π more`, "more" capped at 4 — then applies statuses from source tags and emits the event; **Burn** (6 dps), **Chill** (35% seek slow), **Bleed** (9 dps) live as `status_mask` + timer PackedArrays ticked inside `step` (zero nodes). DoT applies health directly with kills processed after the loop, highest index first — calling `damage()` mid-iteration would swap-remove slots under the loop.
- Wiring: the sword's hits carry `SLASH` + infusion tags (boss parity via `sim.modified`); every ability passes its def's tags; the combo burst is `SLASH|BURST`; **Pyre Attunement** feeds `increased{}` through the caster's from-scratch passive recompute.
- Renderer: enemies tint per status from the tag colors (flash still wins on top).
- Content: **Fire Infusion** and **Frost Infusion** upgrades use a single `infuse` handler that ORs the def's tags into the sword's hit mask — the next element is a `.tres` file with zero code. Tags populated on all 10 upgrades and 9 abilities.

**Verified**

- Tests: **71/71 pass** — mask round-trip; status apply/decay; Burn DoT kills; chilled enemies measurably slower; increased/more math with the cap; content coverage (every def's tags fit the enum; Fire/Frost/Blood each have ≥1 producer); Fire Infusion application.
- Boot clean; bot 3 sim-min: wave 6 / 348 kills / no errors.
- **Perf (the DoD number): 2000 enemies, 14.42 ms/step clean vs 14.29 ms/step all-burning-and-chilled** — statuses are free; the 2000 @ 60fps target holds with the foundation live.
- Screenshot `docs/media/sprint-2.1-burning-horde.png`: Fire-Infused sword visibly tints the horde orange mid-fight with the boss.

**Findings worth keeping**

- **Test-math review pays before engine runs**: both first-run failures were my test arithmetic (Burn deals 18 over 3s — an enemy at 29 HP survives it; the chill assertion was inverted — slower means *farther* from the target). Recomputing expected outcomes by hand first would have saved a cycle.
- **Callback signatures are contracts across files**: adding `tag_mask` to the boss-damage callback broke the test's lambda silently (runtime arity error aborts the test function — the 1.1 harness-guard lesson again). When a callback signature changes, grep every implementer.
- DoT deliberately bypasses `modified()` (flat base) and doesn't emit hit_events — reaction interactions with DoT are a 2.4 tuning decision, not an accident.

**Decisions & deviations**

- Statuses apply at damage-time from source tags — the deep-dive's EventBus reaction filter lands in 2.4; the signal is in place.
- Burn/Bleed damage and Chill slow are sim constants; the tuning pass (2.4/3.3) will move them to data if they need per-status authoring.
- Fire/Frost Infusions are `max_stacks = 1` — repeat picks are dead offers until rank scaling is designed for infusions.

**Deferred**

- Reactions, resonance, rerolls/banish, synergy-biased offers, evolutions (Sprint 2.4).
- Shock/Poison statuses (with their content, 2.3+); stronger status VFX (VFX kit, 2.4 lane); import presets + asset tracker stub (art lane, first pixel-art sprint).

**Next**: Sprint 2.2 — Hero Level, AP, and loadouts: `ProgressionCurve` resource, Hero XP at run end driving roster unlocks, the loadout screen (AP bar, slot cap, free respec, presets), opening-ability pick, level-up offers drawing from the equipped loadout, save schema additions.

---

## Sprint 2.2 — Hero Level, AP, and loadouts (2026-10-01)

**Scope** (from `sprint-roadmap.md`, Phase 2 — Sprint 2.2, approved before build): `ProgressionCurve` resource; roster unlocks by level; passives online from run start; AP budget + loadout screen (AP bar, slot cap, free respec, 3 presets); opening-ability pick; level-up offers from the equipped loadout; save schema v2. Art lane: loadout screen placeholders + the `AudioBus` voice-limiting skeleton.

**Built**

- `ProgressionCurve` resource (`resources/progression/progression_curve.tres`): `xp_required[]` (100 + 80/level, matching 1.3's pacing), `ap_budget[]` (5 at L1 → 14 at L10 → 24 at L20 → 36 at L50, per the deep-dive table), `slot_cap` 12, and `roster_unlocks{level: ids}` (2 actives at L1, then a mixed cadence to 11 abilities by L22). The whole progression feel is one data file.
- `MetaProgression` v2 (schema 2): `loadouts` + `last_loadout_index` persisted; schema-1 saves load with defaults; `owned_abilities()` derives from the curve; **`equip()` enforces the rules** (not-double-equipped, slot cap, AP budget) and returns reason strings; free instant respec; `save_slot_as`/`select_slot` presets; `set_hero_level()` for simulation; cost lookup injectable for tests.
- Run flow: equipped loadout drives everything — **passives are online from run start at rank 1** (recompute handles Plating/Regeneration now too), the **opening-ability pick** (1 card, 2 from Hero Level 20+) pauses the run before wave 1, and **level-up cards draw from the equipped loadout only** (empty pool skips the pause).
- Loadout screen: AP bar, owned/equipped columns with click-to-toggle, error line for refused equips, 3 preset rows, Back to Hub. Reached from the hub (a sub-screen, so the documented state machine stays 4 states). Hub's Loadout button is real now.
- Two new passives: **Plating** (6% damage reduction/rank) and **Regeneration** (2 HP/s/rank) — player got `armor`/`regen_ps`. Ground Slam and Lightning Strike now cost **5 AP** (build-defining tier) so the L20 crunch bites: 10 owned cost 26 AP against a 24 budget.
- `AudioBus` autoload skeleton: Music/SFX/UI buses created at boot, `register_sound`/`can_play`/`finished` voice-limit + retrigger-interval API for the 2.4 SFX pass.
- Debug: hub console gained `hero_level <n>` (the DoD's simulator) and `give_glory`; automation gained `--hero_level <n>` and `--to loadout` screenshot targets.

**Verified**

- Tests: **79/79 pass** — curve key rows (5/14/24 AP at L1/10/20), roster counts (5 owned at L10, 10 at L20, 11 at L22), **L10 default kit costs exactly 14/14 (all equippable)**, **L20 greedy fills 9 of 10 (crunch)**, equip refusal reasons, preset round-trip, audio voice/interval limits, plus all prior suites. Boot clean; bot 3 sim-min: wave 6 / 412 kills with the loadout-driven run.
- DoD evidence: `docs/media/sprint-2.2-loadout-l10.png` and `-l20.png` — the L20 screen shows **AP 21/24 with Lightning Strike stranded in Owned**, presets visible.

**Findings worth keeping**

- **JSON.stringify sorts dictionary keys alphabetically** — the 1.3-era `"schema_version": 1` substring check silently went stale when the version bumped to 2 (the key moved to the middle of the file). Tests that assert serialized text should assert the semantic value (parse it) or stay version-agnostic.
- **Planned .tres edits need the same rigor as code**: I changed Ground Slam/Lightning to 5 AP in my head and in tests, but not in the files — two test cycles lost. Costs are data; data changes get grepped like code now (`ap_cost`, `unlock_level` synced with the curve).
- **The default loadout is a snapshot, not a subscription**: it fills greedily once (cheapest-first), so newly unlocked abilities appear in the loadout screen's Owned column rather than silently joining your kit — deliberate, since a curated kit shouldn't mutate behind the player's back. `set_hero_level` (debug) resets it so simulations reflect the new roster.
- L1 with 5 AP owns 8 AP of actives — the player's very first choice is which active to bring. That's a feature (the own-vs-equip gap starts immediately), but worth watching in the 2.4 playtest that L1 doesn't feel restrictive.

**Deferred**

- Rename loadouts / delete preset slots (only save+select shipped) — UI polish, not blocking.
- unlock_level display in the loadout UI (levels where a locked ability would appear); trophy abilities (per deep-dive, later).
- Reactive SFX through AudioBus (2.4); reactions/resonance/evolutions (2.4).

**Next**: Sprint 2.3 — enemy variety & bosses: 8-10 enemy types with behavior tags, spawn-composition curves per wave range, bosses at waves 20/30 with telegraphed patterns, `champion_modifier_slots` wired, enemy animation via MultiMesh custom data — plus the art-lane timing exercise (first three enemies) that rescales the whole art budget.





---

---

## Sprint 2.3 — Enemy variety & bosses (2026-10-01)

**Scope** (from `sprint-roadmap.md`, Phase 2 — Sprint 2.3, approved before build): 8 enemy types across five behaviors; spawn composition per wave range; bosses at waves 20/30; `champion_modifier_slots` wired; enemy animation via MultiMesh custom data. Also: `PLAYTEST.md` created (the running batch-playtest list the user requested) with checkpoint guidance — short session after 2.3, full batch after 2.4.

**Built**

- `EnemyDef` resource: stats, behavior (chaser/swarmer/tank/ranged/exploder), tint, scale, xp_value, and **composition data on the def itself** (`min_wave` + `spawn_weight`) — a type joins the weighted spawn pool when the wave reaches its min_wave. Decision: composition lives on defs rather than per-WaveDef dictionaries; WaveDef.composition override reserved.
- **8 enemy types as .tres**: Chaser (baseline), Swarmer/Sprinter (fast, fragile), Brute/Bruiser (tanks), Spitter/Longshot (ranged), Popper (exploder).
- `HordeGroup` facade: one `HordeSim` per archetype (one MultiMesh archetype each, §6.4), weighted composition spawning, per-sim swing flags, shared damage-mod pool, `step_all`. Sword/caster/hazards refactored onto the group.
- New behaviors in the sim: **ranged** (holds attack_range, fires on interval → `shot` signal → `HostileProjectiles` pool in the hostile hue) and **exploder** (arms inside trigger range, white-hot windup, detonates → `exploded` signal, self-consumes with **no kill credit** — no XP for suicides).
- Bosses: **The Tide Tyrant** (wave 20) and **Dreadwake, Champion of the Deep** (wave 30) — Dreadwake wears **2 champion slots** as the live champion-modifier proof (+40% HP, +16% speed, faster enrage). Waves 11-30 authored with per-wave composition/difficulty scaling.
- Enemy animation via MultiMesh custom data: per-slot phase written once at setup, a canvas shader bobs instances from TIME — the pipeline sprite-frame selection will reuse (`implementation-guide.md` §16.3 lane).
- Automation: `--start_wave <n>` jumps the run to any wave (DoD verification); `--hero_level <n>` simulation flag.

**Verified**

- Tests: **90/90 pass** — enemy defs/behaviors, composition gating (only wave-1 types at wave 1; ≥5 types by wave 12), ranged hold-and-fire, exploder detonate/self-consume/no-credit, champion HP math, plus all prior suites.
- Bot deep-wave run: `--bot 6 --hero_level 20 --start_wave 24` → **waves 24-30, 926 kills, fps 145, memory flat** — waves 1-30 playable at target frame rate (DoD).
- Screenshots: the wave-8 mix (Brute/Bruiser/Spitter/Popper/Sprinter visibly distinct around the sword) and the wave-30 champion fight; level-up shots show loadout-driven offers with "owned ×1" markers.

**Findings worth keeping**

- **Signal arity errors print as `ERROR`, not `SCRIPT ERROR`** — a 2-arg closure connected to a 1-arg signal silently killed every kill-credit increment (bot: 0 kills in 6 minutes) while all SCRIPT ERROR greps came back clean. Verification greps must match `ERROR` broadly.
- **The `ctx["sim"]` → `ctx["group"]` rename broke `UpgradeEffects.apply` exactly like the 1.2 playtest predicted** — context-dictionary keys are part of the contract; renaming a key without grepping implementers breaks at runtime, at wave clear, every time.
- **Autoload `_ready` may not call `change_scene_to_file` directly** — the initial scene is still being added; the busy-parent guard fires. `goto.call_deferred(...)` fixes it.
- Exploder self-destructs grant no XP by design; revisit if they feel unrewarding to fight.

**Deferred**

- Boss pattern variety beyond charge+slam (a third pattern per boss would help 3.x); champion slot effects beyond HP/speed (elemental auras etc. per architecture §9).
- Spawn composition as per-WaveDef overrides (current def-level min_wave/weight covers the roadmap's "curves per wave range").
- Art-lane timing exercise (first three enemies) — lands with the first real pixel-art sprint; the asset tracker CSV stub with it.

---

## Sprint 2.4 — Synergy layer (2026-10-01)

**Scope** (from `sprint-roadmap.md`, Phase 2 — Sprint 2.4, approved before build): reactions (Steam Burst, Shatter, Blood Boil); resonance tier-1; reroll and banish; synergy-biased offer weighting; evolution framework + one working example; proc guardrails. **Playtest checkpoint follows this sprint** — the user plays waves 1-30 against `PLAYTEST.md` before 2.5.

**Built**

- **Reactions in the pipeline** (`HordeSim.damage`): `hit_event` now carries the target's **pre-hit status mask**; reactions read it — **Steam Burst** (Frost hit on Burning → fire AoE at the target), **Shatter** (heavy Slash hit on Chilled → double damage), **Blood Boil** (death while Burning+Bleeding → fire detonation). Reaction damage re-enters `circle_damage` at **proc_depth + 1**; reactions only chain while depth < 2 and chained depth scales by **PROC_COEFFICIENT 0.5** — the deep-dive guardrails, live.
- **Resonance tier-1** (caster recompute): 3+ equipped abilities sharing Fire/Frost/Blood grant **+15% increased** of that element; **Pyre Resonance** (Fire) additionally spreads Burn to nearby enemies on every kill (0-damage tag application through the pipeline — safe, no mid-loop despawns).
- **Offers**: synergy bias — a def matching N of the player's active tags weighs 1 + 0.25×N capped at ×2 (`offer_weight`, bias mask = equipped loadout tags + sword infusions); **banished defs excluded**; rarity tiers (`[common]/[uncommon]/[rare]`) displayed on cards.
- **Choice screen**: Reroll button + per-card Banish buttons driven by the per-run allotment (2 rerolls / 1 banish), shared across wave/level/opening choices; the run owns the state and re-rolls on demand.
- **Evolution framework**: `EvolutionDef` resources in `resources/evolutions/`; `_check_evolutions()` fires after upgrade takes and level picks when an equipped ability sits at max rank with its required upgrade taken — the entry swaps to the result def, rank carries, banner + ring announce. First example: **Orbiting Blades (rank 5) + Fire Infusion → Solar Halo** (potency-1.6 burning orbit).

**Verified**

- Tests: **102/102 pass** — reaction triggers (Steam/Shatter/Blood Boil), the depth-2 guardrail, Shatter's doubled damage and its light-hit threshold, resonance math (25% amplifier + 15% resonance = +40% on Fire), offer bias statistics (×1.25 per matched tag, ×2 cap), banish exclusion, evolution swap with rank carry and orbit reconfiguration, plus all prior suites.
- Boot clean; bot 3 sim-min with synergy live: wave 6 / 408 kills / no errors.
- `PLAYTEST.md` Batch 2 filled with concrete per-feature checks — the playtest handoff is ready.

**Findings worth keeping**

- **A file Write can be lost silently** — the choice screen's 2.4 rewrite reported success but the disk kept the old version, discovered only because tests failed against features I "knew" existed. After any surprising failure, `grep`/`md5sum` the disk file before re-deriving logic from memory.
- **Line-numbered sed patches on a shifting file chew the wrong lines** — the bias test lost its tags-assignment line to an off-by-N sed and failed for a phantom reason. Read the region, then edit by content, not by number.
- Signal-arity changes ripple: `enemy_killed` gained a status parameter and every closure touching it needed updating — the compile guard caught the parse-level ones, the runtime ones surfaced as test failures with clear labels.
- Test statistics need headroom: a 1.25× weight over 400 draws gives ~56/44 splits — asserting a 2:1 outcome on that edge is flaky by construction. Assert the deterministic weight math directly, and use the capped ×2 edge for distribution checks.

**Decisions & deviations**

- Reactions detect off the **pre-hit** status mask (a Frost hit on an already-Burning enemy bursts; the Frost hit's own Chill doesn't gate it).
- Shatter requires a direct hit (proc_depth 0) and base damage ≥ 10 ("heavy") — light pokes don't shatter.
- Pyre's burn-spread applies Burn through 0-damage pipeline hits — no special-case status code outside the pipeline.
- SFX for reactions deferred (AudioBus API ready, no assets yet — the later audio pass fills it).

**Deferred**

- Contagion/Overload reactions (need Poison/Shock statuses — content 2.3+); resonance tier-2; more evolutions (3 for EA per the budget).
- OnHit/OnKill internal-cooldown helper (deep-dive guardrail) — our on-kill sources are naturally rate-limited by kill cadence; revisit when abilities add on-hit triggers.
- Loadout rename/delete UI; `unlock_level` display in loadout (2.2 deferred, still open).

**Next**: **PLAYTEST CHECKPOINT** — the user plays waves 1-30 against `PLAYTEST.md` (Batch 1 + Batch 2). After triage: Sprint 2.5 — cosmetics, economy, settings (Glory spending, 2-3 placeholder sword skins, settings menu skeleton, first economy tuning pass, persistence hardening), closing Phase 2.
