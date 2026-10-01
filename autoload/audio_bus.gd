extends Node

## Audio bus layout + the voice-limiting SFX skeleton (implementation-guide
## §17, Sprint 2.2 art/audio lane). No audio assets exist yet — this is the
## foundation the 2.4+ SFX pass calls into: buses exist from boot, and
## can_play()/finished() enforce per-sound voice limits and retrigger
## intervals so the constant hit/kill sounds never mud the mix.

const BUS_LAYOUT := {"Music": -6.0, "SFX": -3.0, "UI": -6.0}

var _voices := {}        # id -> active voice count
var _last_played := {}   # id -> ticks_msec of last allowed start
var _limits := {}        # id -> {max, interval}


func _ready() -> void:
	for bus_name in BUS_LAYOUT:
		if AudioServer.get_bus_index(bus_name) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_volume_db(i, BUS_LAYOUT[bus_name])
			AudioServer.set_bus_send(i, "Master")


func register_sound(id: StringName, max_voices := 4, min_interval_ms := 40) -> void:
	_limits[id] = {"max": max_voices, "interval": min_interval_ms}


## True when this sound may start now (under its voice cap and outside its
## retrigger interval). The caller spawns/owns its player and MUST call
## finished(id) when the sound ends, or the voice budget never recovers.
func can_play(id: StringName) -> bool:
	var lim: Dictionary = _limits.get(id, {"max": 4, "interval": 40})
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(id, -1000000000)) < int(lim["interval"]):
		return false
	if int(_voices.get(id, 0)) >= int(lim["max"]):
		return false
	_last_played[id] = now
	_voices[id] = int(_voices.get(id, 0)) + 1
	return true


func finished(id: StringName) -> void:
	_voices[id] = maxi(int(_voices.get(id, 1)) - 1, 0)
