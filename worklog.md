# Worklog

One entry per completed sprint, appended in order. Format per `AGENTS.md`: scope, what was built, what was verified (with results), deferred items, and decisions that flow back into the docs.

---

## Sprint 0.1 — Horde performance spike (2026-09-28)

**Scope** (from `sprint-roadmap.md` §5.1): engine/project setup per `implementation-guide.md` §1–2; build the object-pooling + manual-position + spatial-hash pattern in isolation (no gameplay — dots seeking a point); add the `stress_test <n>` debug command; render via `MultiMeshInstance2D` from the start. **DoD**: a hard, measured number for concurrent enemies at 60fps — this sprint is a go/no-go checkpoint.

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
