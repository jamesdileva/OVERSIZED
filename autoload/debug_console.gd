extends CanvasLayer

## Minimal debug console (implementation-guide §13). F1 or ` toggles it.
## Commands dispatch to a handler registered via register_handler: a command
## named "foo" with args ["n"] calls handler.console_foo(n: String).
## Built-ins: help, clear-log, quit.

var is_open := false

var _handler: Object = null
var _commands: Dictionary = {}
var _panel: PanelContainer
var _log: RichTextLabel
var _input: LineEdit


func _ready() -> void:
	layer = 100
	_build_ui()
	visible = false


func register_handler(handler: Object, commands: Dictionary) -> void:
	_handler = handler
	_commands = commands
	_log_line("console ready — F1 toggles, `help` lists commands")


func _build_ui() -> void:
	_panel = PanelContainer.new()
	var vb := VBoxContainer.new()
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(0, 150)
	_input = LineEdit.new()
	_input.placeholder_text = "command…"
	_input.text_submitted.connect(_on_submit)
	vb.add_child(_log)
	vb.add_child(_input)
	_panel.add_child(vb)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_QUOTELEFT:
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and is_open:
			toggle()
			get_viewport().set_input_as_handled()


func toggle() -> void:
	is_open = not is_open
	visible = is_open
	if is_open:
		_input.grab_focus()
		_input.clear()


func _on_submit(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_log_line("> " + text)
	_input.clear()
	_execute(text)


func _execute(text: String) -> void:
	var parts: PackedStringArray = text.strip_edges().split(" ", false)
	var cmd: String = parts[0]
	var args := []
	for k in range(1, parts.size()):
		args.append(parts[k])
	match cmd:
		"help":
			var lines := []
			for name in _commands:
				var def: Dictionary = _commands[name]
				var usage: Array = def.get("args", [])
				lines.append("%s %s — %s" % [name, " ".join(usage), def.get("desc", "")])
			lines.append("clear-log — clear console output")
			lines.append("quit — exit the game")
			_log_line("\n".join(lines))
		"clear-log":
			_log.clear()
		"quit":
			get_tree().quit()
		_:
			if _handler != null and _handler.has_method("console_" + cmd):
				var def: Dictionary = _commands.get(cmd, {})
				var expected: Array = def.get("args", [])
				if args.size() != expected.size():
					_log_line("usage: %s %s" % [cmd, " ".join(expected)])
					return
				var out = _handler.callv("console_" + cmd, args)
				if out != null and str(out) != "":
					_log_line(str(out))
			else:
				_log_line("unknown command: %s (try `help`)" % cmd)


func _log_line(line: String) -> void:
	_log.append_text(line + "\n")
