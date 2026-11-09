# Playtest Checklist

Living list for batch playtests — one section per sprint's additions, newest last. Tick items as verified; note anything odd inline (specific symptoms beat vague feelings — "slam didn't fire" diagnosed three bugs once). Console lives on **F1** in-run, and in the hub (`hero_level <n>` simulates a Hero Level).

**Suggested checkpoints:** a short focused session after **Sprint 2.3** (difficulty + bosses pacing), the full batch after **Sprint 2.4** (synergy is the most interaction-heavy system and needs real play before economy tuning in 2.5).

---

## Batch 1 — after Sprint 2.3 (difficulty & pacing focus)

### From the hotfix — confirm the fixes (regression)
- [ ] Ground Slam fires on its own every ~5s (ring + knockback)
- [ ] Lightning Strike bolts a random enemy periodically
- [ ] Spirit Blade launches a homing blade that connects
- [ ] Orbiting Blades **follow you** and visibly damage things in reach
- [ ] Arena boundary is visible when you walk to an edge

### Sprint 2.1 — tags & statuses
- [ ] Fire Infusion (sword upgrade): hits apply Burn — enemies tint **orange** and lose HP over time
- [ ] Frost Infusion: hits apply Chill — enemies tint **cyan** and move ~35% slower
- [ ] Pyre Attunement passive: Fire-tagged hits hit harder (try with Fire Infusion)
- [ ] Burn/Chill wear off after ~3s away from your blade
- [ ] Performance: no slowdown with Burn spread across a big wave

### Sprint 2.2 — Hero Level, AP, loadouts
- [ ] Hub → Loadout: equip/unequip works, AP bar updates, refused equips explain why
- [ ] Level 1 start: you own 2 actives but can only afford one — the opening pick offers your choice
- [ ] Equipped passives are ticking from the first frame of a run (Vitality HP bar, Swift Boots speed)
- [ ] Level-up cards only offer abilities you equipped
- [ ] Presets: Save to a slot, swap kit, Load the slot back
- [ ] Console `hero_level 10` → 5 owned, all equippable; `hero_level 20` → 10 owned, one stranded by AP (Lightning Strike at default costs)
- [ ] Death → Summary → Hub: Hero Level bar grew; restart the app — progress persisted

### Sprint 2.3 — enemy variety & bosses (this sprint)
- [ ] Wave 2+: Swarmer mix (smaller, faster, orange) feels different from baseline chasers
- [ ] Wave 4+: Brute (big, slow, dark, hits hard) — dies slow, hurts more
- [ ] Wave 5+: Spitter (pink) — keeps its distance and shoots (magenta projectiles — dodge them)
- [ ] Wave 6+: Popper (yellow) — runs at you, flashes white, explodes (dodge the blast)
- [ ] Wave 8/10/12+: Sprinter, Bruiser, Longshot join the mix; mixes differ per wave range
- [ ] Wave 10: Warden boss unchanged from before (regression)
- [ ] Wave 20 / 30 bosses: new telegraphed fights, harder than the Warden
- [ ] Enemy bob animation runs on all types
- [ ] Performance with mixed hordes + statuses at deep waves

---

## Batch 2 — after Sprint 2.4 (synergy completeness)

### Sprint 2.4 — synergy layer
- [ ] **Steam Burst**: with Fire + Frost Infusions equipped, hitting a burning enemy with frost makes it detonate (fire-colored ring)
- [ ] **Shatter**: hit a chilled (cyan) enemy with a heavy sword hit — double damage number
- [ ] **Blood Boil**: kill an enemy that's both Burning and Bleeding — it explodes in fire
- [ ] **Resonance (Pyre)**: equip 3+ Fire-tagged abilities — your kills spread Burn to nearby enemies
- [ ] **Reroll**: choice screens have a "Reroll (2 left)" button — new cards appear, uses drain
- [ ] **Banish**: "Banish" under a card removes it from the rest of the run (1 per run)
- [ ] **Rarity tiers**: cards show [common] / [uncommon] / [rare]
- [ ] **Synergy bias**: with fire gear equipped, fire cards appear offered more often (soft — over several waves)
- [ ] **Evolution**: Orbiting Blades at rank 5 + Fire Infusion owned → "evolved into Solar Halo!" banner, bigger burning ring
- [ ] Performance still holds with reactions chaining in big waves

### Regression sweep (each batch)
- [ ] Full loop: menu → run → death → summary → hub → menu
- [ ] Dash, sword feel, damage numbers, shake, hit-stop all still feel right
- [ ] 15-minute-ish session without crashes or slowdown creep
- [ ] Save survives an app restart

---

## Batch 3 — after Sprint 2.5 (cosmetics, economy, settings)

### Sprint 2.5 — cosmetics, economy, settings
- [ ] **Cosmetics shop**: Hub → Cosmetics — 7 items listed with Glory costs; buying one deducts Glory
- [ ] **Equip**: an owned cosmetic shows Equip → EQUIPPED state; unequip works
- [ ] **Visuals in run**: Ember set equipped → hero glows warm, blade turns orange, ember trail follows you; Glacier set turns everything cyan
- [ ] **Glory economy**: a couple of runs earn enough Glory for the first cosmetic (~30); deeper runs earn noticeably more
- [ ] **Settings** (menu + hub): Master/Music/SFX/UI sliders change volumes immediately; Fullscreen toggle works; settings survive an app restart
- [ ] **Persistence hardening**: profile survives an app restart with cosmetics owned/equipped intact
- [ ] Zero-stats rule: cosmetics change NOTHING about damage/HP/speed (a fresh run with the Void set plays identically to a bare run)

---

## Patch 2.5.1 — playtest triage fixes (re-verify these)

- [ ] **Dash reliability**: dash now fires even right after choice screens (input queued during pauses); slightly-early presses buffer for 0.25s — spam away
- [ ] **Orbiting Blades no longer resets** after evolving into Solar Halo (base ability can't be re-picked; offers exclude it)
- [ ] **No choice-screen soft lock**: banish/reroll down to an empty pool resumes the run instead of freezing
- [ ] **Loadout screen**: real AP bar (green → red at budget), refused equips show a clear reason line
- [ ] **hero_level console works in-run too** (F1 in a run: `hero_level 20` — applies next run)
- [ ] **Opening pick offers ALL equipped actives** — your whole kit choice, not a random 3
- [ ] **Blood Infusion** (new upgrade): sword hits apply Bleed → **Blood Boil** now reachable (kill a Burning+Bleeding enemy)
- [ ] **Cinder Bolt** (new ability): fire homing bolt — with Pyre Attunement + Solar Halo, Fire resonance is reachable (3 fire-tagged equipped)
- [ ] **Resonance (Pyre)**: with Cinder Bolt + Solar Halo + Pyre Attunement equipped, kills spread Burn
- [ ] **Shatter**: with Frost Infusion, chilled enemies take doubled slash damage (look for the big number)
- [ ] **Bosses stay in the arena** during charges (wave 20/30 rush no longer exits the boundary)
- [ ] **Visibility**: lightning bolts bigger, Spitter projectiles bigger, Popper blasts last longer, HUD shows your online abilities + ranks
- [ ] Hero placeholder is now white — equipped cosmetic tints read clearly
