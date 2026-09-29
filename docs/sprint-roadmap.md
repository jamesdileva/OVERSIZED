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
| 2 — Systems Build-out | Every core system at MVP breadth (full content *types*, not full content *volume*) | |
| 3 — Content & Balance | Full v1.0 content budget, tuned, with juice/VFX/SFX and accessibility basics | |
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
- XP/leveling; 5-8 real Universal Abilities using the same shared choice-screen component; the first hand-authored boss at wave 10 with a telegraphed attack pattern (`implementation-guide.md` Section 8).

### Sprint 1.3 — Meta loop + run-loop polish
- Death → Run Summary → Runeshards/Glory awarded → minimal Meta Hub (even just "spend Runeshards to unlock 1-2 more abilities") → back to menu. Basic save/load. Restart flow polish.

**Vertical Slice Definition of Done**: one hero, sword with base swing plus at least 5 upgrades taken across a run, at least 5 Universal Abilities available, waves 1-10 fully playable, one unique boss at wave 10, a working death → summary → currency → hub → menu loop, playable with a gamepad (movement, dash, choice-screen navigation), no crashes across a 15-minute session.

## 5. Phase 2 — Systems Build-out

**Goal**: every core system exists at MVP breadth — this phase is about *types*, not yet full *volume* (that's Phase 3).

- **Sprint(s)**: additional enemy types and spawn-composition variety; bosses at waves 20 and 30; the full data-driven pipeline for adding new Sword Upgrades and Universal Abilities without new code (`implementation-guide.md` Section 3); cosmetics system with 2-3 sets; Runeshards/Glory economy tuning pass #1; save-system versioning (`implementation-guide.md` Section 10); settings menu skeleton.

**Definition of Done**: the full roster of *systems* is functional in-game even if numbers are unbalanced and art is placeholder — save/load works, the meta hub spends both currencies on something real, cosmetics equip and visibly change the character/sword.

## 6. Phase 3 — Content & Balance

**Goal**: hit the v1.0 content budget from `architecture.md` Section 6, tuned and polished.

- Fill out Sword Upgrades and Universal Abilities to the 24-30 / 25-35 targets; fill out enemy types toward the 15-20 target; hand-author remaining bosses (waves 40, 50, and beyond per the target in `architecture.md`); a dedicated balance pass (this is the phase where the debug console from `implementation-guide.md` Section 13 pays for itself repeatedly); VFX/SFX juice pass; accessibility basics — rebindable keys, colorblind-safe damage numbers and boss telegraphs, audio sliders.

**Definition of Done**: the full content budget is in-game and tuned (not just present), settings/accessibility basics are complete, the game is enjoyable across a full run rather than just its first few waves.

## 7. Phase 4 — Demo Prep & Steam

**Goal**: a polished, representative slice ready for public hands, plus everything Steam requires around it.

- **Tasks**: select and polish a representative slice (suggest waves 1 through ~20, including one or two bosses — enough to show the full loop, including at least one Sword-Upgrade-pool refresh and a Mastery Rank glimpse, without needing the full content budget live); Steam store page (capsule art, description, screenshots); trailer; bug bash pass; external playtests with feedback triaged. No fixed deadline — when the demo is ready, pick the Next Fest edition that fits and submit the build for Steam review 5-7 business days before its deadline (review turnaround isn't under our control, so the submission buffer stays even without a date).

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
| Content production (art/animation for 24-30 upgrades + 25-35 abilities) underestimated | Phase 2-3 grows larger than expected | Reuse a small, tintable/scalable VFX "kit" across most abilities rather than bespoke art per ability; reserve bespoke art budget for sword skins specifically |
| Availability dips / burnout (two-person team) | A phase sits idle for a while | Inherent cost of no-deadline development — scope-gating absorbs it; phases wait for their DoD, not a date |
| Steam review turnaround for the demo build | Delays whichever fest/page launch we pick | Submit 5-7 business days ahead of whatever deadline applies |

## 11. Definition of Done — Quick Reference

- **Vertical Slice**: Section 4's DoD.
- **Systems Build-out**: Section 5's DoD.
- **Content & Balance**: Section 6's DoD.
- **Demo-ready**: Section 7's DoD.
