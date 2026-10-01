extends Node

## Global signal hub (implementation-guide.md §4) — combat, progression, and
## UI communicate through these instead of holding direct references.
## Autoloaded as EventBus. Kept minimal for Sprint 1.1; grows in 1.2+.

signal wave_started(number: int)
signal wave_cleared(number: int)
signal upgrade_selected(def)   # SwordUpgradeDef or UniversalAbilityDef — untyped on purpose
