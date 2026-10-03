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

### Sprint 2.4 — synergy layer (to fill in when it lands)
- [ ] Reactions fire (Steam Burst / Shatter / Blood Boil)
- [ ] Resonance tier-1 bonus appears with 3+ shared tags
- [ ] Reroll/banish buttons work on choice screens
- [ ] Synergy bias: the game offers cards matching your tags more often
- [ ] One evolution path works end to end
- [ ] Archetypes feel different (Pyre vs Frostbite vs Juggernaut builds)

### Regression sweep (each batch)
- [ ] Full loop: menu → run → death → summary → hub → menu
- [ ] Dash, sword feel, damage numbers, shake, hit-stop all still feel right
- [ ] 15-minute-ish session without crashes or slowdown creep
- [ ] Save survives an app restart
