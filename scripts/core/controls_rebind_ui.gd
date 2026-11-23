extends Node
class_name ControlsRebindUI

const KeybindManagerScript = preload("res://scripts/core/keybind_manager.gd")

## Interaktywny panel zmiany skrótów klawiszowych w zakładce STEROWANIE / CONTROLS.
## Obsługuje nasłuchiwanie klawiszy w _input(), zamianę konfliktów oraz przywracanie domyślnych.

var panel_root: Control = null
var rebind_root: VBoxContainer = null
var rows_box: VBoxContainer = null
var hint_label: Label = null
var reset_btn: Button = null
var pause_action_label: Label = null
var pause_key_label: Label = null

var action_labels: Dictionary = {}
var action_buttons: Dictionary = {}
var listening_action: String = ""
var current_lang: String = "pl"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(controls_panel: Control, lang: String = "pl") -> void:
	if not is_instance_valid(controls_panel):
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel_root = controls_panel
	current_lang = lang

	var legacy_grid := controls_panel.get_node_or_null("Grid") as Control
	if legacy_grid:
		legacy_grid.visible = false

	var existing := controls_panel.get_node_or_null("RebindRoot") as VBoxContainer
	if existing:
		rebind_root = existing
		_cache_existing_nodes()
	else:
		_build_ui(controls_panel)

	if is_instance_valid(Events) and Events.has_signal("keybinds_changed"):
		if not Events.keybinds_changed.is_connected(_on_keybinds_changed):
			Events.keybinds_changed.connect(_on_keybinds_changed)

	refresh(current_lang)


func _build_ui(controls_panel: Control) -> void:
	rebind_root = VBoxContainer.new()
	rebind_root.name = "RebindRoot"
	rebind_root.layout_mode = 1
	rebind_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	rebind_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rebind_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rebind_root.add_theme_constant_override("separation", 4)
	controls_panel.add_child(rebind_root)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 128)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	rebind_root.add_child(scroll)

	rows_box = VBoxContainer.new()
	rows_box.name = "RowsBox"
	rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 3)
	scroll.add_child(rows_box)

	action_labels.clear()
	action_buttons.clear()

	var ordered_buttons: Array[Button] = []
	for action_name in KeybindManagerScript.REBINDABLE_ORDER:
		var row := HBoxContainer.new()
		row.name = "Row_" + action_name
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)
		rows_box.add_child(row)

		var lbl := Label.new()
		lbl.name = "ActionLabel"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(lbl)
		action_labels[action_name] = lbl

		var btn := Button.new()
		btn.name = "BindBtn_" + action_name
		btn.custom_minimum_size = Vector2(150, 20)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.add_theme_font_size_override("font_size", 10)
		_apply_bind_button_style(btn, false)
		btn.pressed.connect(_on_bind_button_pressed.bind(action_name))
		row.add_child(btn)
		action_buttons[action_name] = btn
		ordered_buttons.append(btn)

	# Wiersz tylko do odczytu dla Pauzy
	var pause_row := HBoxContainer.new()
	pause_row.name = "Row_pause"
	pause_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_row.add_theme_constant_override("separation", 8)
	rows_box.add_child(pause_row)

	pause_action_label = Label.new()
	pause_action_label.name = "ActionLabel"
	pause_action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_action_label.add_theme_font_size_override("font_size", 11)
	pause_row.add_child(pause_action_label)

	pause_key_label = Label.new()
	pause_key_label.name = "PauseKeyLabel"
	pause_key_label.custom_minimum_size = Vector2(150, 20)
	pause_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pause_key_label.add_theme_font_size_override("font_size", 10)
	pause_key_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 0.85))
	pause_key_label.text = "Esc / P"
	pause_row.add_child(pause_key_label)

	# Stopka z podpowiedzią i przyciskiem resetu
	var footer := HBoxContainer.new()
	footer.name = "FooterBox"
	footer.custom_minimum_size = Vector2(0, 22)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("separation", 8)
	rebind_root.add_child(footer)

	hint_label = Label.new()
	hint_label.name = "HintLabel"
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 9)
	hint_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90, 0.9))
	footer.add_child(hint_label)

	reset_btn = Button.new()
	reset_btn.name = "ResetBindsBtn"
	reset_btn.custom_minimum_size = Vector2(138, 20)
	reset_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reset_btn.add_theme_font_size_override("font_size", 9)
	_apply_bind_button_style(reset_btn, false)
	reset_btn.pressed.connect(_on_reset_pressed)
	footer.add_child(reset_btn)

	# Nawigacja focusem między przyciskami
	for i in range(ordered_buttons.size()):
		var cur_btn := ordered_buttons[i]
		if i > 0:
			cur_btn.focus_neighbor_top = ordered_buttons[i - 1].get_path()
		if i + 1 < ordered_buttons.size():
			cur_btn.focus_neighbor_bottom = ordered_buttons[i + 1].get_path()
		elif reset_btn:
			cur_btn.focus_neighbor_bottom = reset_btn.get_path()
	if not ordered_buttons.is_empty() and reset_btn:
		reset_btn.focus_neighbor_top = ordered_buttons[ordered_buttons.size() - 1].get_path()


func _cache_existing_nodes() -> void:
	if not rebind_root:
		return
	rows_box = rebind_root.get_node_or_null("Scroll/RowsBox") as VBoxContainer
	hint_label = rebind_root.get_node_or_null("FooterBox/HintLabel") as Label
	reset_btn = rebind_root.get_node_or_null("FooterBox/ResetBindsBtn") as Button
	pause_action_label = rebind_root.get_node_or_null("Scroll/RowsBox/Row_pause/ActionLabel") as Label
	pause_key_label = rebind_root.get_node_or_null("Scroll/RowsBox/Row_pause/PauseKeyLabel") as Label
	action_labels.clear()
	action_buttons.clear()
	for action_name in KeybindManagerScript.REBINDABLE_ORDER:
		var row := rebind_root.get_node_or_null("Scroll/RowsBox/Row_" + action_name)
		if row:
			action_labels[action_name] = row.get_node_or_null("ActionLabel") as Label
			action_buttons[action_name] = row.get_node_or_null("BindBtn_" + action_name) as Button


func is_listening() -> bool:
	return not listening_action.is_empty()


func cancel_listening() -> void:
	if listening_action.is_empty():
		return
	listening_action = ""
	refresh()


func get_first_focusable() -> Control:
	if not KeybindManagerScript.REBINDABLE_ORDER.is_empty():
		var first_action: String = KeybindManagerScript.REBINDABLE_ORDER[0]
		var btn := action_buttons.get(first_action) as Button
		if btn:
			return btn
	return reset_btn


func refresh(lang: String = "") -> void:
	if not lang.is_empty():
		current_lang = lang

	var km: KeybindManagerScript = Events.keybind_manager if is_instance_valid(Events) else null

	for action_name in KeybindManagerScript.REBINDABLE_ORDER:
		var lbl := action_labels.get(action_name) as Label
		if lbl:
			if km:
				lbl.text = km.get_action_display_name(action_name, current_lang)
			else:
				var labels: Dictionary = KeybindManagerScript.ACTION_LABELS.get(action_name, {})
				lbl.text = String(labels.get(current_lang, action_name))

		var btn := action_buttons.get(action_name) as Button
		if btn:
			var is_cur_listening: bool = (listening_action == action_name)
			_apply_bind_button_style(btn, is_cur_listening)
			if is_cur_listening:
				btn.text = "[ Press key... ]" if current_lang == "en" else "[ Naciśnij klawisz... ]"
			else:
				btn.text = km.get_action_key_label(action_name, current_lang) if km else "—"

	if pause_action_label:
		pause_action_label.text = "Pause:" if current_lang == "en" else "Pauza:"

	if reset_btn:
		reset_btn.text = "Reset Defaults" if current_lang == "en" else "Przywróć domyślne"

	if hint_label:
		if not listening_action.is_empty():
			hint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45, 1.0))
			hint_label.text = "Press new key (Esc to cancel)..." if current_lang == "en" else "Naciśnij nowy klawisz (Esc aby anulować)..."
		else:
			hint_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90, 0.9))
			hint_label.text = "Click an action to rebind its key." if current_lang == "en" else "Kliknij akcję, aby zmienić klawisz."


func _on_bind_button_pressed(action_name: String) -> void:
	if listening_action == action_name:
		listening_action = ""
	else:
		listening_action = action_name
	refresh()


func _on_reset_pressed() -> void:
	listening_action = ""
	if is_instance_valid(Events) and is_instance_valid(Events.keybind_manager):
		Events.keybind_manager.reset_to_defaults()
	refresh()


func _on_keybinds_changed() -> void:
	refresh()


func _input(event: InputEvent) -> void:
	if listening_action.is_empty():
		return
	if panel_root and ((panel_root.is_inside_tree() and not panel_root.is_visible_in_tree()) or (not panel_root.is_inside_tree() and not panel_root.visible)):
		return
	if event is InputEventKey:
		var kev := event as InputEventKey
		if not kev.pressed or kev.echo:
			return
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()
		var code: Key = kev.physical_keycode if kev.physical_keycode != KEY_NONE else kev.keycode
		if kev.keycode == KEY_ESCAPE or code == KEY_ESCAPE:
			listening_action = ""
			refresh()
			return
		if code == KEY_NONE or code == KEY_UNKNOWN:
			return
		var target_action := listening_action
		listening_action = ""
		if is_instance_valid(Events) and is_instance_valid(Events.keybind_manager):
			Events.keybind_manager.rebind_action(target_action, code)
		refresh()


func _apply_bind_button_style(btn: Button, active_listening: bool) -> void:
	var sb_normal := StyleBoxFlat.new()
	var sb_hover := StyleBoxFlat.new()
	if active_listening:
		sb_normal.bg_color = Color(0.32, 0.25, 0.06, 0.95)
		sb_normal.border_color = Color(1.0, 0.88, 0.35, 1.0)
		sb_normal.set_border_width_all(2)
		sb_hover.bg_color = sb_normal.bg_color
		sb_hover.border_color = sb_normal.border_color
		sb_hover.set_border_width_all(2)
		btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55, 1.0))
	else:
		sb_normal.bg_color = Color(0.10, 0.11, 0.18, 0.88)
		sb_normal.border_color = Color(0.45, 0.52, 0.68, 0.75)
		sb_normal.set_border_width_all(1)
		sb_hover.bg_color = Color(0.16, 0.18, 0.28, 0.95)
		sb_hover.border_color = Color(1.0, 0.85, 0.38, 0.95)
		sb_hover.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.42, 1.0))

	sb_normal.set_corner_radius_all(3)
	sb_hover.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("focus", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
