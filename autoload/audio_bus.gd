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
	# demo-tier SFX registry (implementation-guide §17): id -> [max voices, min retrigger ms]
	for id in ["hit_light", "hit_heavy", "kill", "xp_pickup", "player_hurt", "reaction_steam"]:
		register_sfx(StringName(id), 6 if id == StringName("hit_light") else 3, 40)
	for id in ["level_up", "wave_clear", "buy", "evolve", "boss_roar", "ui_select"]:
		register_sfx(StringName(id), 1, 0)
	for id in ["dash", "player_hurt", "reaction_boil", "boss_slam"]:
		register_sfx(StringName(id), 2, 80)


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


var _music_player: AudioStreamPlayer = null
var _current_track := ""
var _sfx_players := {}      # id -> AudioStreamPlayer
var _sfx_streams := {}      # id -> AudioStreamWAV (lazy-loaded, runtime-parsed)

## Looping music through the Music bus (Sprint 3.1 lane). Tracks are
## generated WAV loops; switching tracks stops the previous one.
## Parses a generated 16-bit PCM WAV at runtime and builds a forward-looping
## AudioStreamWAV — bypasses the import pipeline (QOA compression there broke
## playback instantiation, Sprint 3.1). Callers pass the asset path.
func play_music(track_id: String, path: String) -> void:
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = "Music"
		add_child(_music_player)
	if _current_track == track_id and _music_player.playing:
		return
	var stream := _load_wav_stream(path)
	if stream == null:
		push_warning("music track failed to load: %s" % path)
		return
	_current_track = track_id
	_music_player.stream = stream
	_music_player.play()


func _load_wav_stream(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var raw := f.get_buffer(f.get_length())
	f.close()
	if raw.size() < 44:
		return null
	var riff := raw.slice(0, 4).get_string_from_ascii()
	var wave := raw.slice(8, 12).get_string_from_ascii()
	if riff != "RIFF" or wave != "WAVE":
		return null
	var data := PackedByteArray()
	var channels := 1
	var pos := 12
	while pos + 8 <= raw.size():
		var tag := raw.slice(pos, pos + 4).get_string_from_ascii()
		var size := raw.decode_u32(pos + 4)
		if tag == "fmt ":
			channels = raw.decode_u16(pos + 12)
			pos += 8 + size
		elif tag == "data":
			data = raw.slice(pos + 8, mini(pos + 8 + size, raw.size()))
			break
		else:
			pos += 8 + size
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = channels > 1
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = data.size() / 2 / channels   # frames for 16-bit
	return stream


func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
	_current_track = ""


func register_sound(id: StringName, max_voices := 4, min_interval_ms := 40) -> void:
	_limits[id] = {"max": max_voices, "interval": min_interval_ms}


## Registers a demo-tier SFX: id maps to assets/audio/sfx/<id>.wav (runtime
## parsed). Limits: hit/kill sounds cap concurrency, others are one-at-a-time
## with retrigger intervals so the mix never muds (implementation-guide §17).
func register_sfx(id: StringName, max_voices := 3, min_interval_ms := 40) -> void:
	_limits[id] = {"max": max_voices, "interval": min_interval_ms}


func play_sfx(id: StringName, pitch_var := 0.08) -> void:
	if not can_play(id):
		return
	if not _sfx_streams.has(id):
		var stream := _load_wav_stream("res://assets/audio/sfx/%s.wav" % id)
		if stream == null:
			return
		_sfx_streams[id] = stream
	if not _sfx_players.has(id):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.stream = _sfx_streams[id]
		add_child(p)
		p.finished.connect(func() -> void: finished(id))
		_sfx_players[id] = p
	var player: AudioStreamPlayer = _sfx_players[id]
	player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	player.play()


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
