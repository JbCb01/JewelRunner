extends Node
class_name KeybindManager

## Zarządza domyślnymi i spersonalizowanymi skrótami klawiszowymi (InputMap)
## oraz zapisuje je lokalnie w user://keybinds.json.

const DEFAULT_BINDINGS: Dictionary = {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"dash": [KEY_SHIFT],
	"crouch_slide": [KEY_S, KEY_DOWN],
	"trick": [KEY_CTRL],
}

const REBINDABLE_ORDER: Array[String] = [
	"move_left",
	"move_right",
	"move_up",
	"jump",
	"dash",
	"crouch_slide",
	"trick",
]

const ACTION_LABELS: Dictionary = {
	"move_left": {"pl": "Ruch w lewo:", "en": "Move Left:"},
	"move_right": {"pl": "Ruch w prawo:", "en": "Move Right:"},
	"move_up": {"pl": "Wspinaczka (w górę):", "en": "Wall Climb (Up):"},
	"jump": {"pl": "Skok / Podwójny skok:", "en": "Jump / Double Jump:"},
	"dash": {"pl": "Zryw (Dash):", "en": "Dash:"},
	"crouch_slide": {"pl": "Kucanie / Wślizg:", "en": "Crouch / Slide:"},
	"trick": {"pl": "Trick (w locie):", "en": "Mid-air Trick:"},
}

var keybinds_save_path: String = "user://keybinds.json"


func ensure_default_actions() -> void:
	for action_name in DEFAULT_BINDINGS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			_apply_action_keycodes(action_name, DEFAULT_BINDINGS[action_name])


func load_keybinds() -> void:
	ensure_default_actions()
	if not FileAccess.file_exists(keybinds_save_path):
		return
	var text := FileAccess.get_file_as_string(keybinds_save_path)
	if text.strip_edges().is_empty():
		return
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return
	var data := json.data as Dictionary
	for action_name_var in data.keys():
		var action_name := String(action_name_var)
		if not DEFAULT_BINDINGS.has(action_name):
			continue
		var codes: Array[Key] = _parse_keycode_entry(data[action_name_var])
		if codes.is_empty():
			continue
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		_apply_action_keycodes(action_name, codes)

	if data.has("crouch_slide") and not data.has("move_down"):
		var crouch_codes: Array[Key] = _get_action_keycodes("crouch_slide")
		if not crouch_codes.is_empty():
			_apply_action_keycodes("move_down", crouch_codes)


func save_keybinds() -> void:
	var payload: Dictionary = {}
	for action_name in REBINDABLE_ORDER:
		var codes: Array[Key] = _get_action_keycodes(action_name)
		var raw_codes: Array[int] = []
		for code in codes:
			raw_codes.append(int(code))
		payload[action_name] = raw_codes

	var move_down_codes: Array[Key] = _get_action_keycodes("move_down")
	if not move_down_codes.is_empty():
		var raw_down: Array[int] = []
		for code in move_down_codes:
			raw_down.append(int(code))
		payload["move_down"] = raw_down

	var file := FileAccess.open(keybinds_save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))


func rebind_action(action_name: String, new_keycode: Key) -> bool:
	if not (action_name in REBINDABLE_ORDER):
		return false
	if new_keycode == KEY_NONE or new_keycode == KEY_UNKNOWN or new_keycode == KEY_ESCAPE:
		return false

	ensure_default_actions()
	var old_primary: Key = get_primary_keycode(action_name)

	# Rozwiązywanie konfliktów z innymi akcjami
	for other_action in REBINDABLE_ORDER:
		if other_action == action_name:
			continue
		var other_codes: Array[Key] = _get_action_keycodes(other_action)
		if other_codes.is_empty():
			continue
		if other_codes[0] == new_keycode:
			if old_primary != KEY_NONE and old_primary != new_keycode:
				_apply_action_keycodes(other_action, [old_primary])
				if other_action == "crouch_slide":
					_apply_action_keycodes("move_down", [old_primary])
		elif new_keycode in other_codes:
			var filtered: Array[Key] = []
			for c in other_codes:
				if c != new_keycode:
					filtered.append(c)
			if not filtered.is_empty():
				_apply_action_keycodes(other_action, filtered)
				if other_action == "crouch_slide":
					_apply_action_keycodes("move_down", filtered)

	_apply_action_keycodes(action_name, [new_keycode])
	if action_name == "crouch_slide":
		_apply_action_keycodes("move_down", [new_keycode])

	save_keybinds()
	_emit_keybinds_changed()
	return true


func reset_to_defaults() -> void:
	for action_name in DEFAULT_BINDINGS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		_apply_action_keycodes(action_name, DEFAULT_BINDINGS[action_name])

	if FileAccess.file_exists(keybinds_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(keybinds_save_path))

	_emit_keybinds_changed()


func get_action_display_name(action_name: String, lang: String = "pl") -> String:
	var labels: Dictionary = ACTION_LABELS.get(action_name, {})
	if labels.is_empty():
		return action_name
	return String(labels.get(lang, labels.get("pl", action_name)))


func get_primary_keycode(action_name: String) -> Key:
	var codes: Array[Key] = _get_action_keycodes(action_name)
	if codes.is_empty():
		return KEY_NONE
	return codes[0]


func get_primary_key_label(action_name: String, lang: String = "pl") -> String:
	var code: Key = get_primary_keycode(action_name)
	return format_keycode(code, lang)


func get_action_key_label(action_name: String, lang: String = "pl") -> String:
	var codes: Array[Key] = _get_action_keycodes(action_name)
	if codes.is_empty():
		return "—"
	var parts: Array[String] = []
	for code in codes:
		var lbl := format_keycode(code, lang)
		if not (lbl in parts):
			parts.append(lbl)
	return " / ".join(parts)


static func format_keycode(code: Key, lang: String = "pl") -> String:
	match code:
		KEY_NONE, KEY_UNKNOWN:
			return "—"
		KEY_SPACE:
			return "Space" if lang == "en" else "Spacja"
		KEY_CTRL:
			return "Ctrl"
		KEY_SHIFT:
			return "Shift"
		KEY_ALT:
			return "Alt"
		KEY_META:
			return "Meta"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_ENTER, KEY_KP_ENTER:
			return "Enter"
		KEY_TAB:
			return "Tab"
		KEY_BACKSPACE:
			return "Backspace"
		KEY_CAPSLOCK:
			return "CapsLock"
		KEY_ESCAPE:
			return "Esc"
		_:
			var key_str := OS.get_keycode_string(code)
			return key_str if not key_str.is_empty() else str(int(code))


func _get_action_keycodes(action_name: String) -> Array[Key]:
	var result: Array[Key] = []
	if not InputMap.has_action(action_name):
		return result
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey:
			var kev := ev as InputEventKey
			var code: Key = kev.physical_keycode if kev.physical_keycode != KEY_NONE else kev.keycode
			if code != KEY_NONE and not (code in result):
				result.append(code)
	return result


func _apply_action_keycodes(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for code_var in keycodes:
		var code: Key = int(code_var) as Key
		if code == KEY_NONE:
			continue
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		InputMap.action_add_event(action_name, ev)


func _parse_keycode_entry(entry: Variant) -> Array[Key]:
	var parsed: Array[Key] = []
	if entry is Array:
		for item in entry:
			var code: Key = int(item) as Key
			if code != KEY_NONE and code != KEY_UNKNOWN and code != KEY_ESCAPE:
				parsed.append(code)
	elif entry is int or entry is float:
		var code: Key = int(entry) as Key
		if code != KEY_NONE and code != KEY_UNKNOWN and code != KEY_ESCAPE:
			parsed.append(code)
	return parsed


func _emit_keybinds_changed() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node) and parent_node.has_signal("keybinds_changed"):
		parent_node.emit_signal("keybinds_changed")
	elif is_instance_valid(Events) and Events.has_signal("keybinds_changed"):
		Events.keybinds_changed.emit()
