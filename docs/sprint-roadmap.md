# Oversized — Sprint Roadmap

Companion to `architecture.md` (the systems) and `implementation-guide.md` (the patterns). This document is the sequencing: what to build in what order, and what "done" means for each phase.

---

## 1. How to Use This Roadmap

Two principles govern it:

1. **Phases are scope-gated, not date-gated.** Each phase is defined by "what's true when it's done." There are no calendar commitments — the team is two people at whatever pace life allows, and a phase takes as long as it takes. Scope-gating also absorbs pauses naturally: a phase waits for its Definition of Done, not for a date.
2. **Sprint contents are fixed by dependencies, not schedule.** You can't balance content that doesn't exist, and you can't demo a game that crashes — so what gets built next is always whatever unblocks the most.

## 2. Phase Overview

| Phase | Scope goal | Status |
|---|---|---|
| 0 — Pre-Production | De-risk horde performance; prove the core swing feels good | Done — go (~2,200 @ 60fps); feel prototype playable |
| 1 — Vertical Slice | One complete 10-wave run, one boss, both pick-screens, minimal meta loop | |
| 2 — Systems Build-out | Synergy tag foundation, Hero Level/AP loadouts, enemy variety + bosses 20/30, resonance/reactions, cosmetics/economy/settings — five sprints on placeholder art |
| 3 — Content & Balance | Fill the **Early Access tier** of the staged content budget (`architecture.md` §6), tuned, final art, accessibility basics — three sprints |
| 4 — Demo Prep | Polished representative slice, Steam page, trailer, bug bash | |
| 5 — EA / 1.0 Launch Prep | Remaining content, marketing basics, launch checklist | |
| 6 — Post-Launch | Content-update cadence (sketch — Section 9) | |

## 3. Phase 0 — Pre-Production (Risk-First Prototyping)

**Goal**: prove the two scariest unknowns before a single hour goes into content — can the engine actually render/simulate the enemy density this game needs, and does swinging a huge sword feel good at all.

### Sprint 0.1 — Horde performance spike
- **Tasks**: engine/project setup per `implementation-guide.md` Section 1-2; build the object-pooling + manual-position + spatial-hash pattern from Section 6 in isolation (no gameplay, just dots moving toward a point); add the `stress_test <n>` debug command early and use it to find the real concurrent-enemy ceiling on target hardware; render via `MultiMeshInstance2D` from the start, not bolted on after.
- **Definition of Done**: a hard number for "how many concurrent enemies at 60fps," measured, not guessed. If the number is uncomfortably low, this is the sprint to solve it — not a problem to discover in Phase 3.
- **Outcome (2026-09-28): GO.** ~2,200 concurrent enemies at 60fps measured in pure GDScript (design target: 300-500) — see `worklog.md` for the full benchmark and findings.

### Sprint 0.2 — Core feel prototype
- **Tasks**: player movement, the sword swing state machine (`implementation-guide.md` Section 5.1), one enemy type, basic damage numbers, screen-shake/hit-stop juice on the swing; gamepad bindings for every input action added from here on (left stick movement, dash button) so the prototype is gamepad-playable immediately. No meta-systems, no progression screens yet.
- **Definition of Done**: "is swinging a big sword at a crowd of guys fun for five straight minutes with zero other systems in place?" If the answer's no, everything downstream is at risk regardless of how good the systems built on top of it are — worth being honest here before investing further.
- **Outcome (2026-09-28): done.** Playable feel prototype — auto-swing sword with hash-based arc hits, damage numbers/shake/hit-stop, gamepad verified by hand. Both of us rate the core feel good; all tuning knobs are exposed fields for fast iteration. See `worklog.md`.

## 4. Phase 1 — Vertical Slice

**Goal**: one complete run is playable start to finish, even with placeholder art and a small content set.

### Sprint 1.1 — Wave loop + Sword Upgrade picks
- Wave Director reading `WaveDef` resources; wave-clear condition (timer-based, per `architecture.md` Section 4); the shared choice-screen UI component (`implementation-guide.md` Section 9); 5-8 real Sword Upgrades — including at least one combo-counter archetype upgrade (`architecture.md` Section 5.1) — implemented as `.tres` data files; the no-cooldown dash (`implementation-guide.md` Section 1).

### Sprint 1.2 — Leveling + Universal Ability picks + first boss
- XP/leveling (in-run Character Level); 5-8 real Universal Abilities and passives authored to the `UniversalAbilityDef` schema (`kind`, `ap_cost`, `unlock_level`, `tags` — `architecture.md` §8), offered through the same shared choice-screen component; the first hand-authored boss at wave 10 with a telegraphed attack pattern (`implementation-guide.md` Section 8).

### Sprint 1.3 — Meta loop + run-loop polish
- Death → Run Summary → **Hero XP + Glory** awarded → minimal Meta Hub (the loadout screen can be a stub — the full AP loadout screen lands in Sprint 2.2) → back to menu. Basic save/load. Restart flow polish.

**Vertical Slice Definition of Done**: one hero, sword with base swing plus at least 5 upgrades taken across a run, at least 5 Universal Abilities available, waves 1-10 fully playable, one unique boss at wave 10, a working death → summary → currency → hub → menu loop, playable with a gamepad (movement, dash, choice-screen navigation), no crashes across a 15-minute session.

## 5. Phase 2 — Systems Build-out

**Goal**: every system from `architecture.md` §5.2/§5.4 works end-to-end on placeholder content, with the loadout → run → Hero XP → hub loop fully closed.

**Prerequisites carried in from Phase 1**: base resolution decided (`implementation-guide.md` §16.3), and a stub loadout screen from Sprint 1.3.

**Phase 2 done when**: every core system is functional on placeholder content — tags and reactions fire in real runs, the AP loadout crunch is real, save/load works, and the loop closes without touching the debug console.

**Playtest checkpoints** (`PLAYTEST.md` holds the running list): a short focused session after Sprint 2.3 (difficulty + boss pacing with the accumulated 2.1/2.2 batch), and the full batch after Sprint 2.4 — synergy is the most interaction-heavy system in Phase 2 and needs real play before 2.5 tunes the economy against it.

### Sprint 2.1 — Tag & effect foundation
- **Build**: `Tags` enum + bitmask helpers; hit-event pipeline carrying `tag_mask`; two-category damage math (`increased` / `more`, `architecture.md` §5.4); status arrays in the horde layer (`status_mask` + timers) with **three** statuses first (Burn, Chill, Bleed); `tags` added to all existing Sword Upgrade and Ability definitions.
- **Art/audio lane**: finalize the tag→color map; start the asset tracker; set Godot import presets; sourcing decisions made for tilesets, UI, and music.
- **Done when**: a Fire sword upgrade visibly applies Burn to a horde without dropping below the Sprint 0.1 performance target.

### Sprint 2.2 — Hero Level, AP, and loadouts
- **Build**: `ProgressionCurve` resource; Hero XP awarded at run end; roster unlocks by level (actives and passives, with AP-only levels between unlocks); passives online from run start; AP budget and the loadout screen (AP bar, equip/unequip, hard slot cap, free respec, 3 saved presets); opening-ability pick at run start; **level-up offers now draw from the equipped loadout**; save schema updated (`hero_xp`, `hero_level`, `loadouts`).
- **Art/audio lane**: loadout screen UI placeholders; audio bus layout and the `AudioBus` voice-limiting skeleton.
- **Done when**: you can play at a simulated Hero Level 10 (5 abilities, all equippable) and Level 20 (10 abilities, ~8 equippable) via the debug console, and the AP crunch is visibly real at Level 20.

### Sprint 2.3 — Enemy variety & bosses
- **Build**: expand to 8-10 enemy types with behavior tags (chaser, swarmer, ranged, tank, exploder); spawn-composition curves per wave range; bosses for waves 20 and 30 with telegraphed patterns; `champion_modifier_slots` wired in (unused until later); enemy animation via MultiMesh custom data (`implementation-guide.md` §16.3).
- **Art/audio lane**: **time yourself on the first three enemies** and rescale the art budget (`implementation-guide.md` §16.1); boss telegraph color follows the hostile-hue rule; boss warning/telegraph SFX.
- **Done when**: waves 1-30 are playable with distinct enemy mixes and three bosses, still at target frame rate.

### Sprint 2.4 — Synergy layer
- **Build**: reactions (start with Steam Burst, Shatter, Blood Boil); resonance tier-1 (3+ shared tags); rarity; reroll and banish; synergy-biased offer weighting (`architecture.md` §5.4); evolution framework (data structure plus **one** working example); proc guardrails (depth limit, internal cooldowns, proc coefficient).
- **Art/audio lane**: reaction VFX from the kit (`implementation-guide.md` §16.4); reaction SFX with voice limits.
- **Done when**: at least **3 archetypes** (`architecture.md` §5.4) are assemblable from a level-20 AP budget and *feel* different from each other in a real run.

### Sprint 2.5 — Cosmetics, economy, settings
- **Build**: cosmetics equip slots (hero skin, sword skin, trail, victory pose) using the no-stat-fields `CosmeticItemDef`; Glory awards; 2-3 placeholder sword skins; settings menu skeleton (volume sliders wired to buses); first economy tuning pass (Hero XP and Glory per run); persistence hardening.
- **Art/audio lane**: first sourced/pack assets imported and tracked; sword-skin sprites (procedural swing means one sprite each).
- **Done when**: the full loop — pick loadout → run → earn Hero XP and Glory → level up / buy a cosmetic → equip → run again — works without touching the debug console.

## 6. Phase 3 — Content & Balance

**Goal**: the **Early Access tier** of the staged content budget (`architecture.md` §6) in-game, tuned, and using final or locked art, with accessibility basics complete. This is the phase most exposed to the content-production estimate — read the cut list before starting it.

### Sprint 3.1 — Content fill, part A
- **Build**: abilities and Sword Upgrades to ~50% of the EA target; enemies to ~12; boss for wave 40; every new piece authored to the **coverage rule** (`architecture.md` §5.4); synergy matrix and validation script run at sprint end; resonance tier-2; first 1-2 evolutions.
- **Art/audio lane**: final art for hero, sword, and the ~6 most-seen enemies; icons for new content; the first music tracks (menu/hub, run).
- **Done when**: at least 4 archetypes are viable and the validation script passes clean.

### Sprint 3.2 — Content fill, part B
- **Build**: remainder of the EA content budget; remaining bosses; champion-modifier scaling live for waves beyond the hand-authored roster; evolutions to the EA target (3); remaining cosmetic sets for EA.
- **Art/audio lane**: final art for remaining enemies and bosses; VFX polish for evolutions; boss music; the SFX pass completes to demo-tier count.
- **Done when**: all EA-tier content is in the game; at least 6 archetypes pass the "buildable under a level-20 AP budget" check.

### Sprint 3.3 — Balance, accessibility, art lock
- **Build**: dedicated balance pass using the debug console and a scripted bot for aggregate win/wave-reached data; tune the `ProgressionCurve` (Hero XP pace, AP budget, roster unlocks) against the targets in `architecture.md` §5.2; accessibility basics (key rebinding, colorblind-safe telegraphs — the hostile-hue rule plus shape/pattern cues, audio sliders); performance profiling pass at the enemy-count ladder from `implementation-guide.md` §14.
- **Art/audio lane**: **art lock** — every asset moves to Locked in the tracker; final audio mix pass (voice limits, ducking, loudness balance).
- **Done when**: the game is enjoyable across a full run, not just its opening waves, and the tracker shows nothing below Final.

### Ordered cut list (if a phase slips, cut in this order and stop when back on track)

1. Evolutions beyond the first 3 (defer to updates)
2. Cosmetic sets from 6 to 3 at EA launch
3. Music tracks: ship with 3, add later
4. Trophy (boss-unlock) abilities
5. Champion-modifier scaling (cap the game's wave range instead)
6. Hero Level cap from 30 to 25 at EA launch
7. Resonance tier-2 (keep tier-1)

**Never cut**: the tag foundation (2.1), the loadout/AP system (2.2), the horde-performance target, and swing/hit feel. Everything else builds on those four.

## 7. Phase 4 — Demo Prep & Steam

**Goal**: a polished, representative slice ready for public hands, plus everything Steam requires around it.

- **Tasks**: select and polish a representative slice (suggest waves 1 through ~20, including one or two bosses — enough to show the full loop, including at least one Sword-Upgrade-pool refresh and a Hero Level/loadout glimpse, without needing the full content budget live); Steam store page (capsule art, description, screenshots); trailer; bug bash pass; external playtests with feedback triaged. No fixed deadline — when the demo is ready, pick the Next Fest edition that fits and submit the build for Steam review 5-7 business days before its deadline (review turnaround isn't under our control, so the submission buffer stays even without a date).

**Demo-ready Definition of Done**: the representative slice is free of known crash/softlock bugs, runs at target performance on minimum-spec hardware, the Steam page is live with capsule art and a trailer, and at least a few external playtesters have played it with their feedback reviewed.

## 8. Phase 5 — Early Access / 1.0 Launch Prep

**Goal**: get from "demo people liked" to "shippable product."

- Incorporate demo/playtest feedback; decide Early Access vs. direct 1.0 (Early Access is the norm for this genre — it builds wishlists and reviews before the number that matters most, and several of the precedent titles in `architecture.md` used exactly this path); finish any remaining content budget items; pricing — genre precedent (Brotato, Vampire Survivors, Megabonk) clusters around $4.99-$6.99 for a premium one-time purchase, which is a reasonable anchor rather than a rule; basic marketing checklist (press list, key distribution, launch-day community presence); final launch-day checklist (build validation across target hardware, store page final review, day-one patch readiness).

## 9. Phase 6 — Post-Launch (sketch)

Beyond this roadmap's primary horizon, but worth naming so Phase 5 doesn't treat launch as a finish line: a content-update cadence (new bosses, new Sword Upgrades/Universal Abilities, seasonal cosmetic sets) is standard for the genre and is realistically what turns an initial launch into a long-tail seller — Vampire Survivors' continued DLC cadence and Brotato's post-launch character additions are the reference points here.

## 10. Risk Register

| Risk | Impact | Mitigation |
|---|---|---|
| ~~Horde-performance spike takes longer than one sprint~~ | ~~Delays everything downstream~~ | **Resolved** — Sprint 0.1 measured ~2,200 enemies at 60fps (go). Re-run the performance checklist whenever the horde system changes (`implementation-guide.md` Section 14). |
| Dual progression systems compete for the same "power budget" | Runs feel trivial (overtuned) or unfair (undertuned) | Sword Upgrades weighted toward utility/consistency, Universal Abilities toward power spikes; dedicated balance sprint in Phase 3 rather than opportunistic tuning |
| Content production (art/animation for the roster) underestimated | Phase 2-3 grow larger than expected | Sourcing split decided — self-made pixel art + licensed/CC0 packs, no commissions (`implementation-guide.md` §16); time the first three enemies in Sprint 2.3 and rescale; passives are the cheap roster lever; ordered cut list in Section 6 |
| Availability dips / burnout (two-person team) | A phase sits idle for a while | Inherent cost of no-deadline development — scope-gating absorbs it; phases wait for their DoD, not a date |
| Steam review turnaround for the demo build | Delays whichever fest/page launch we pick | Submit 5-7 business days ahead of whatever deadline applies |

## 11. Definition of Done — Quick Reference

- **Vertical Slice**: Section 4's DoD.
- **Systems Build-out**: Section 5's phase DoD (plus per-sprint done-whens).
- **Content & Balance**: Section 6's phase DoD — the EA tier of the staged budget (`architecture.md` §6).
- **Demo-ready**: Section 7's DoD.
