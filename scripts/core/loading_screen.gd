extends CanvasLayer

signal transition_completed

const LEVEL_LOADING_TEXTURES: Dictionary = {
	1: {
		"top": "res://assets/ui/Loading/Loading_MossyCircuit_top.png",
		"mid": "res://assets/ui/Loading/Loading_MossyCircuit_mid.png",
		"bot": "res://assets/ui/Loading/Loading_MossyCircuit_bot.png"
	},
	2: {
		"top": "res://assets/ui/Loading/Loading_IceflowRidge_top.png",
		"mid": "res://assets/ui/Loading/Loading_IceflowRidge_mid.png",
		"bot": "res://assets/ui/Loading/Loading_IceflowRidge_bot.png"
	},
	3: {
		"top": "res://assets/ui/Loading/Loading_BlazingTrench_top.png",
		"mid": "res://assets/ui/Loading/Loading_BlazingTrench_mid.png",
		"bot": "res://assets/ui/Loading/Loading_BlazingTrench_bot.png"
	},
	4: {
		"top": "res://assets/ui/Loading/Loading_CyberMatrix_top.png",
		"mid": "res://assets/ui/Loading/Loading_CyberMatrix_mid.png",
		"bot": "res://assets/ui/Loading/Loading_CyberMatrix_bot.png"
	}
}

var is_transitioning: bool = false
var has_shown_for_scene: bool = false

var root_control: Control
var bot_panel: TextureRect
var mid_panel: TextureRect
var top_panel: TextureRect

var _tex_cache: Dictionary = {}

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_ui()

func _setup_ui() -> void:
	root_control = Control.new()
	root_control.name = "LoadingControl"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.size = Vector2(640, 360)
	root_control.visible = false
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	# 1. Dolny panel (Bottom panel) - warstwa dolna
	bot_panel = TextureRect.new()
	bot_panel.name = "BotPanel"
	bot_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bot_panel.stretch_mode = TextureRect.STRETCH_SCALE
	bot_panel.size = Vector2(640, 360)
	bot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(bot_panel)

	# 2. Środkowy panel (Middle panel) - warstwa środkowa z nazwą poziomu i LOADING...
	mid_panel = TextureRect.new()
	mid_panel.name = "MidPanel"
	mid_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mid_panel.stretch_mode = TextureRect.STRETCH_SCALE
	mid_panel.size = Vector2(640, 360)
	mid_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(mid_panel)

	# 3. Górny panel (Top panel) - warstwa górna (pasek ozdobny)
	top_panel = TextureRect.new()
	top_panel.name = "TopPanel"
	top_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_panel.stretch_mode = TextureRect.STRETCH_SCALE
	top_panel.size = Vector2(640, 360)
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(top_panel)

func _get_texture(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if not tex and FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			tex = ImageTexture.create_from_image(img)
	if tex:
		_tex_cache[path] = tex
	return tex

func apply_profile_textures(profile_id: int) -> void:
	var prof_data: Dictionary = LEVEL_LOADING_TEXTURES.get(profile_id, LEVEL_LOADING_TEXTURES[1])
	bot_panel.texture = _get_texture(prof_data["bot"])
	mid_panel.texture = _get_texture(prof_data["mid"])
	top_panel.texture = _get_texture(prof_data["top"])

## Odtwarza pełną animację przejścia z wejściem elementów, zmianą sceny i wyjściem elementów
func play_transition(profile_id: int, target_scene_path: String = "") -> void:
	if is_transitioning:
		return
	is_transitioning = true
	has_shown_for_scene = true
	apply_profile_textures(profile_id)

	root_control.visible = true
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP

	# Pozycje początkowe przed wejściem:
	bot_panel.position = Vector2(0, 160)
	bot_panel.modulate.a = 0.0

	mid_panel.position = Vector2(-90, 0)
	mid_panel.modulate.a = 0.0

	top_panel.position = Vector2(0, -45)
	top_panel.modulate.a = 0.0

	# --- 1. KOLEJNOŚĆ POJAWIANIA SIĘ: DOLNY PANEL ---
	var tween_in1 = create_tween().set_parallel(true)
	tween_in1.tween_property(bot_panel, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_in1.tween_property(bot_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.20, false).timeout

	# --- 2. KOLEJNOŚĆ POJAWIANIA SIĘ: ŚRODKOWY PANEL ---
	var tween_in2 = create_tween().set_parallel(true)
	tween_in2.tween_property(mid_panel, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_in2.tween_property(mid_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.20, false).timeout

	# --- 3. KOLEJNOŚĆ POJAWIANIA SIĘ: GÓRNY PANEL ---
	var tween_in3 = create_tween().set_parallel(true)
	tween_in3.tween_property(top_panel, "position:y", 0.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_in3.tween_property(top_panel, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween_in3.finished

	# Ekran jest w 100% złożony i zakrywa cały widok. Dokonujemy zmiany sceny w tle:
	if target_scene_path != "":
		get_tree().change_scene_to_file(target_scene_path)
		await get_tree().process_frame
		await get_tree().process_frame

	# Krótki hold, aby gracz mógł nacieszyć oko ekranem ładowania i przeczytać nazwę
	await get_tree().create_timer(0.70, false).timeout

	# --- 4. KOLEJNOŚĆ ZNIKANIA: ŚRODKOWY PANEL ZNIKA NAJPIERW ---
	var tween_out1 = create_tween().set_parallel(true)
	tween_out1.tween_property(mid_panel, "position:x", 90.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_out1.tween_property(mid_panel, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween_out1.finished

	await get_tree().create_timer(0.06, false).timeout

	# --- 5. KOLEJNOŚĆ ZNIKANIA: DOLNY I GÓRNY PANEL ZNIKAJĄ JEDNOCZEŚNIE ---
	var tween_out2 = create_tween().set_parallel(true)
	tween_out2.tween_property(top_panel, "position:y", -45.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_out2.tween_property(top_panel, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween_out2.tween_property(bot_panel, "position:y", 160.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_out2.tween_property(bot_panel, "modulate:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween_out2.finished

	# Zakończenie przejścia
	root_control.visible = false
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false

	transition_completed.emit()
	if is_instance_valid(Events) and Events.has_signal("loading_screen_finished"):
		Events.loading_screen_finished.emit()

## Wersja dla bezpośredniego wejścia do areny (np. F6 w edytorze)
func play_transition_direct(profile_id: int) -> void:
	play_transition(profile_id, "")
