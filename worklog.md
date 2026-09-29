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

**Next**: Sprint 1.2 — leveling + Universal Ability picks + the first boss (XP pickups, level-up offers through the same choice screen, 5–8 abilities with cooldown timers, wave-10 boss with telegraphed patterns).


