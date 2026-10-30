extends Node

## Audio bus layout + the voice-limiting SFX skeleton (implementation-guide
## §17, Sprint 2.2 art/audio lane). No audio assets exist yet — this is the
## foundation the 2.4+ SFX pass calls into: buses exist from boot, and
## can_play()/finished() enforce per-sound voice limits and retrigger
## intervals so the constant hit/kill sounds never mud the mix.

const BUS_LAYOUT := {"Master": 0.0, "Music": -6.0, "SFX": -3.0, "UI": -6.0}
var settings_path := "user://audio_settings.json"

var volumes := {"Master": 1.0, "Music": 0.5, "SFX": 0.7, "UI": 0.5}   # linear 0-1 (Music/SFX/UI default to their mix levels)
var fullscreen := false

var _voices := {}        # id -> active voice count
var _last_played := {}   # id -> ticks_msec of last allowed start
var _limits := {}        # id -> {max, interval}


func _ready() -> void:
	for bus_name in BUS_LAYOUT:
		if AudioServer.get_bus_index(bus_name) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	load_settings()
	for bus_name in volumes:
		_apply_volume(bus_name, volumes[bus_name])
	set_fullscreen(fullscreen)


## Linear 0..1 volume per bus, applied to the AudioServer bus and persisted
## (user://audio_settings.json, schema_version from the first write — the §10
## rule applies to settings files too).
func set_volume(bus_name: String, linear: float) -> void:
	if not volumes.has(bus_name):
		return
	volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_volume(bus_name, volumes[bus_name])
	save_settings()


func _apply_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)


func save_settings() -> void:
	var data := {"schema_version": 1, "volumes": volumes, "fullscreen": fullscreen}
	var f := FileAccess.open(settings_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_settings() -> void:
	volumes = {"Master": 1.0, "Music": 1.0, "SFX": 1.0, "UI": 1.0}
	fullscreen = false
	if not FileAccess.file_exists(settings_path):
		return
	var f := FileAccess.open(settings_path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var raw_volumes = parsed.get("volumes", {})
	if typeof(raw_volumes) == TYPE_DICTIONARY:
		for bus_name in raw_volumes:
			if volumes.has(bus_name):
				volumes[bus_name] = clampf(float(raw_volumes[bus_name]), 0.0, 1.0)
	fullscreen = bool(parsed.get("fullscreen", false))


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
