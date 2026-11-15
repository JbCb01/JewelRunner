extends Control

const LevelGenerator = preload("res://scripts/core/level_generator.gd")

@export_file("*.tscn") var arenaScenePath: String = "res://TestArena.tscn"

@onready var homeView: Control = get_node_or_null("HomeView")
@onready var lvlView: Control = get_node_or_null("LevelSelectView")
@onready var setView: Control = get_node_or_null("SettingsView")
@onready var creatorsView: Control = get_node_or_null("CreatorsView")
@onready var musicPlayer: AudioStreamPlayer = get_node_or_null("MusicPlayer")

@onready var profileBtn: Button = get_node_or_null("HomeView/ProfileBtn")
@onready var playBtn: Button = get_node_or_null("HomeView/MenuBtns/PlayBtn")
@onready var lvlBtn: Button = get_node_or_null("HomeView/MenuBtns/LvlBtn")
@onready var setBtn: Button = get_node_or_null("HomeView/MenuBtns/SetBtn")
@onready var creatorsBtn: Button = get_node_or_null("HomeView/MenuBtns/CreatorsBtn")
@onready var exitBtn: Button = get_node_or_null("HomeView/MenuBtns/ExitBtn")

@onready var lvl1Btn: Button = get_node_or_null("LevelSelectView/Lvl1Btn")
@onready var lvl2Btn: Button = get_node_or_null("LevelSelectView/Lvl2Btn")
@onready var lvl3Btn: Button = get_node_or_null("LevelSelectView/Lvl3Btn")
@onready var lvl1CompletedBadge: Control = get_node_or_null("LevelSelectView/Lvl1Btn/CompletedBadge")
@onready var lvl1CheckmarkIcon: Control = get_node_or_null("LevelSelectView/Lvl1Btn/CheckmarkIcon")

# --- Kontroler zakładek Ustawień ---
@onready var tabAudioBtn: Button = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/TabBar/TabAudioBtn")
@onready var tabGraphicsBtn: Button = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/TabBar/TabGraphicsBtn")
@onready var tabControlsBtn: Button = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/TabBar/TabControlsBtn")
@onready var tabLanguageBtn: Button = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/TabBar/TabLanguageBtn")
@onready var settingsBackBtn: Button = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/FooterBox/SettingsBackBtn")

@onready var audioPanel: Control = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel")
@onready var graphicsPanel: Control = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/GraphicsPanel")
@onready var controlsPanel: Control = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/ControlsPanel")
@onready var languagePanel: Control = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/LanguagePanel")

var currentSettingsTab: int = 0
var tabNames: Array[String] = ["Dźwięk", "Grafika", "Sterowanie", "Język"]

var isMusicMuted: bool = false
var isSfxMuted: bool = false

var mechanicInfoLabel: Label = null
var dnaRadarLabel: Label = null
var aiGenerateBtn: Button = null
var aiContractBtn: Button = null
var portalStatusBadge: Label = null
var portalDrawer: Control = null
var pairingCodeInput: LineEdit = null

func _ready() -> void:
	_ensure_top_profile_button()
	_setup_portal_sync_bar()
	_setup_mechanic_level_select_ui()
	_showView(homeView)
	_update_level_select()
	_setup_settings_mockups()
	
	if is_instance_valid(Events):
		if not Events.portal_profile_synced.is_connected(_on_portal_profile_synced):
			Events.portal_profile_synced.connect(_on_portal_profile_synced)
		if not Events.portal_challenges_synced.is_connected(_on_portal_challenges_synced):
			Events.portal_challenges_synced.connect(_on_portal_challenges_synced)
	
	if profileBtn and not profileBtn.pressed.is_connected(_on_profile_btn_pressed):
		profileBtn.pressed.connect(_on_profile_btn_pressed)
	if playBtn: playBtn.pressed.connect(func(): _startLevelProfile(1))
	if lvlBtn and lvlView: lvlBtn.pressed.connect(func(): _showView(lvlView))
	if setBtn and setView: setBtn.pressed.connect(func(): _showView(setView))
	if creatorsBtn and creatorsView: creatorsBtn.pressed.connect(func(): _showView(creatorsView))
	if exitBtn: exitBtn.pressed.connect(func(): get_tree().quit())
	
	if lvl1Btn:
		lvl1Btn.pressed.connect(func(): _startLevelProfile(1))
		lvl1Btn.mouse_entered.connect(func(): _preview_mechanic_profile(1))
		lvl1Btn.focus_entered.connect(func(): _preview_mechanic_profile(1))
	if lvl2Btn:
		lvl2Btn.pressed.connect(func(): _startLevelProfile(2))
		lvl2Btn.mouse_entered.connect(func(): _preview_mechanic_profile(2))
		lvl2Btn.focus_entered.connect(func(): _preview_mechanic_profile(2))
	if lvl3Btn:
		lvl3Btn.pressed.connect(func(): _startLevelProfile(3))
		lvl3Btn.mouse_entered.connect(func(): _preview_mechanic_profile(3))
		lvl3Btn.focus_entered.connect(func(): _preview_mechanic_profile(3))
	
	if tabAudioBtn: tabAudioBtn.pressed.connect(func(): _switchSettingsTab(0))
	if tabGraphicsBtn: tabGraphicsBtn.pressed.connect(func(): _switchSettingsTab(1))
	if tabControlsBtn: tabControlsBtn.pressed.connect(func(): _switchSettingsTab(2))
	if tabLanguageBtn: tabLanguageBtn.pressed.connect(func(): _switchSettingsTab(3))
	if settingsBackBtn: settingsBackBtn.pressed.connect(func(): _showView(homeView))

## Zapewnia istnienie przycisku profilu na górze po prawej stronie w HomeView.
func _ensure_top_profile_button() -> void:
	if not profileBtn and homeView:
		profileBtn = homeView.get_node_or_null("ProfileBtn") as Button
		if not profileBtn:
			profileBtn = Button.new()
			profileBtn.name = "ProfileBtn"
			profileBtn.position = Vector2(564, 4)
			profileBtn.size = Vector2(44, 40)
			profileBtn.flat = true
			homeView.add_child(profileBtn)

## Kliknięcie przycisku profilu na górze w menu: przenosi do strony internetowej profilu
## oraz uruchamia synchronizację z aplikacją webową!
func _on_profile_btn_pressed() -> void:
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.open_profile_webpage("/profil")
		Events.portal_sync.request_sync_from_web()
	if portalDrawer:
		portalDrawer.visible = not portalDrawer.visible
	_refresh_portal_badge()

## Buduje górny pasek statusu konta webowego oraz wysuwany panel parowania / synchronizacji z portalem.
func _setup_portal_sync_bar() -> void:
	if not homeView:
		return
	if not homeView.has_node("PortalStatusBadge"):
		portalStatusBadge = Label.new()
		portalStatusBadge.name = "PortalStatusBadge"
		portalStatusBadge.position = Vector2(360, 12)
		portalStatusBadge.size = Vector2(198, 22)
		portalStatusBadge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		portalStatusBadge.add_theme_font_size_override("font_size", 10)
		portalStatusBadge.add_theme_color_override("font_color", Color(0.95, 0.92, 1.0, 0.95))
		homeView.add_child(portalStatusBadge)
		
	if not homeView.has_node("PortalSyncDrawer"):
		portalDrawer = ColorRect.new()
		portalDrawer.name = "PortalSyncDrawer"
		portalDrawer.visible = false
		portalDrawer.position = Vector2(330, 46)
		portalDrawer.size = Vector2(296, 106)
		portalDrawer.color = Color(0.06, 0.08, 0.14, 0.94)
		
		var info_lbl := Label.new()
		info_lbl.name = "DrawerInfoLabel"
		info_lbl.position = Vector2(8, 6)
		info_lbl.size = Vector2(280, 34)
		info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_lbl.add_theme_font_size_override("font_size", 9)
		info_lbl.text = "Portal Webowy: wpisz 6-znakowy kod z /profil lub kliknij Synchronizuj."
		portalDrawer.add_child(info_lbl)
		
		pairingCodeInput = LineEdit.new()
		pairingCodeInput.name = "PairingCodeInput"
		pairingCodeInput.placeholder_text = "KOD (np. K7P2QX)"
		pairingCodeInput.max_length = 8
		pairingCodeInput.position = Vector2(8, 42)
		pairingCodeInput.size = Vector2(130, 26)
		pairingCodeInput.add_theme_font_size_override("font_size", 10)
		portalDrawer.add_child(pairingCodeInput)
		
		var pair_btn := Button.new()
		pair_btn.name = "PairSubmitBtn"
		pair_btn.position = Vector2(144, 42)
		pair_btn.size = Vector2(144, 26)
		pair_btn.add_theme_font_size_override("font_size", 10)
		pair_btn.text = "Połącz i Pobierz Dane"
		pair_btn.pressed.connect(func():
			if is_instance_valid(Events) and is_instance_valid(Events.portal_sync) and pairingCodeInput:
				var code_txt: String = pairingCodeInput.text.strip_edges()
				if code_txt.is_empty():
					code_txt = "DEMO99"
				Events.portal_sync.pair_with_code(code_txt)
				_refresh_portal_badge()
		)
		portalDrawer.add_child(pair_btn)
		
		var open_web_btn := Button.new()
		open_web_btn.name = "OpenWebPortalBtn"
		open_web_btn.position = Vector2(8, 72)
		open_web_btn.size = Vector2(280, 26)
		open_web_btn.add_theme_font_size_override("font_size", 10)
		open_web_btn.text = "🌐 Otwórz Portal w Przeglądarce (/profil)"
		open_web_btn.pressed.connect(func():
			if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
				Events.portal_sync.open_profile_webpage("/profil")
		)
		portalDrawer.add_child(open_web_btn)
		
		homeView.add_child(portalDrawer)
		
	_refresh_portal_badge()

func _refresh_portal_badge() -> void:
	if not portalStatusBadge or not is_instance_valid(Events) or not is_instance_valid(Events.portal_sync):
		return
	var ps: Node = Events.portal_sync
	var uname: String = String(ps.player_profile.get("username", "Gość"))
	var skin: String = String(ps.cosmetics_state.get("active_skin", "Podstawowa"))
	var ch_cnt: int = ps.get_active_challenges().size()
	portalStatusBadge.text = "👤 %s | %s | Zadania: %d ↗" % [uname, skin, ch_cnt]

func _on_portal_profile_synced(profile_state: Dictionary) -> void:
	_refresh_portal_badge()
	# Aktualizacja widżetów w zakładce Ustawienia pobranymi ze strony wartościami
	if profile_state.has("settings") and profile_state["settings"] is Dictionary:
		var s := profile_state["settings"] as Dictionary
		var musicSlider: HSlider = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel/MusicBox/MusicSlider")
		if musicSlider and s.has("music_volume"):
			musicSlider.value = float(s["music_volume"])
		var sfxSlider: HSlider = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel/SfxBox/SfxSlider")
		if sfxSlider and s.has("sfx_volume"):
			sfxSlider.value = float(s["sfx_volume"])

func _on_portal_challenges_synced(_challenges: Array) -> void:
	_refresh_portal_badge()
	_preview_mechanic_profile(Events.selected_level_profile if is_instance_valid(Events) else 1)

## Rozbudowuje karty Level Select o Żywioły Ruchu (Trials of Flow), Dynamiczny Radar DNA Mechanik,
## wybór Kontraktu Reżysera AI oraz podgląd aktywnych zadań ze strony internetowej.
func _setup_mechanic_level_select_ui() -> void:
	if not lvlView:
		return
	var btns: Array[Button] = [lvl1Btn, lvl2Btn, lvl3Btn]
	for idx in range(btns.size()):
		var btn: Button = btns[idx]
		if not btn:
			continue
		var profile_id: int = idx + 1
		var meta: Dictionary = LevelGenerator.get_profile_metadata(profile_id)
		var dna: Dictionary = meta.get("dna", {"wall_climb": 33, "dash": 33, "double_jump": 34})
		if not btn.has_node("MechanicTag"):
			var tag_bg := ColorRect.new()
			tag_bg.name = "MechanicTag"
			tag_bg.position = Vector2(4, 4)
			tag_bg.size = Vector2(139, 50)
			tag_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tag_bg.color = Color(0.06, 0.10, 0.18, 0.90)
			
			var title_lbl := Label.new()
			title_lbl.name = "TitleLabel"
			title_lbl.position = Vector2(4, 2)
			title_lbl.size = Vector2(131, 15)
			title_lbl.add_theme_font_size_override("font_size", 9)
			title_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35, 1.0))
			title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			title_lbl.text = String(meta["title"])
			tag_bg.add_child(title_lbl)
			
			var sub_lbl := Label.new()
			sub_lbl.name = "SubLabel"
			sub_lbl.position = Vector2(4, 17)
			sub_lbl.size = Vector2(131, 14)
			sub_lbl.add_theme_font_size_override("font_size", 8)
			sub_lbl.add_theme_color_override("font_color", Color(0.70, 0.90, 1.0, 1.0))
			sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sub_lbl.text = String(meta["subtitle"])
			tag_bg.add_child(sub_lbl)
			
			var dna_lbl := Label.new()
			dna_lbl.name = "DnaMiniLabel"
			dna_lbl.position = Vector2(4, 33)
			dna_lbl.size = Vector2(131, 14)
			dna_lbl.add_theme_font_size_override("font_size", 8)
			dna_lbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65, 1.0))
			dna_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dna_lbl.text = "DNA: W:%d%% D:%d%% J:%d%%" % [
				int(dna.get("wall_climb", 33)),
				int(dna.get("dash", 33)),
				int(dna.get("double_jump", 34))
			]
			tag_bg.add_child(dna_lbl)
			
			btn.add_child(tag_bg)
			
	if not lvlView.has_node("MechanicInfoPanel"):
		var panel := ColorRect.new()
		panel.name = "MechanicInfoPanel"
		panel.position = Vector2(45, 228)
		panel.size = Vector2(547, 64)
		panel.color = Color(0.06, 0.09, 0.15, 0.94)
		
		mechanicInfoLabel = Label.new()
		mechanicInfoLabel.name = "MechanicInfoLabel"
		mechanicInfoLabel.position = Vector2(10, 4)
		mechanicInfoLabel.size = Vector2(527, 38)
		mechanicInfoLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mechanicInfoLabel.add_theme_font_size_override("font_size", 10)
		mechanicInfoLabel.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0, 1.0))
		panel.add_child(mechanicInfoLabel)
		
		dnaRadarLabel = Label.new()
		dnaRadarLabel.name = "DnaRadarLabel"
		dnaRadarLabel.position = Vector2(10, 44)
		dnaRadarLabel.size = Vector2(527, 16)
		dnaRadarLabel.add_theme_font_size_override("font_size", 9)
		dnaRadarLabel.add_theme_color_override("font_color", Color(0.45, 0.95, 0.72, 1.0))
		panel.add_child(dnaRadarLabel)
		
		lvlView.add_child(panel)
		
	if not lvlView.has_node("AIContractBtn"):
		aiContractBtn = Button.new()
		aiContractBtn.name = "AIContractBtn"
		aiContractBtn.position = Vector2(45, 296)
		aiContractBtn.size = Vector2(265, 28)
		aiContractBtn.add_theme_font_size_override("font_size", 10)
		aiContractBtn.pressed.connect(_cycle_ai_contract)
		lvlView.add_child(aiContractBtn)
		_update_contract_btn_text()
		
	if not lvlView.has_node("AIGenerateBtn"):
		aiGenerateBtn = Button.new()
		aiGenerateBtn.name = "AIGenerateBtn"
		aiGenerateBtn.position = Vector2(320, 296)
		aiGenerateBtn.size = Vector2(272, 28)
		aiGenerateBtn.add_theme_font_size_override("font_size", 10)
		aiGenerateBtn.text = "⚡ IV. SZACHOWNICA AI + ZADANIA Z PORTALU"
		aiGenerateBtn.pressed.connect(func():
			var new_seed: int = int(Time.get_unix_time_from_system()) + randi() % 10000
			_startLevelProfile(4, new_seed)
		)
		aiGenerateBtn.mouse_entered.connect(func(): _preview_mechanic_profile(4))
		lvlView.add_child(aiGenerateBtn)
		
	_preview_mechanic_profile(1)

func _cycle_ai_contract() -> void:
	if not is_instance_valid(Events) or not is_instance_valid(Events.ai_director):
		return
	var cur: int = int(Events.ai_director.active_contract)
	var next_mode: AdaptiveAIDirector.ContractMode = ((cur + 1) % 3) as AdaptiveAIDirector.ContractMode
	Events.ai_director.set_contract_mode(next_mode)
	_update_contract_btn_text()

func _update_contract_btn_text() -> void:
	if not aiContractBtn or not is_instance_valid(Events) or not is_instance_valid(Events.ai_director):
		return
	aiContractBtn.text = "📜 KONTRAKT AI: %s" % Events.ai_director.get_contract_name()

func _preview_mechanic_profile(profile_id: int) -> void:
	if not mechanicInfoLabel:
		return
	var meta: Dictionary = LevelGenerator.get_profile_metadata(profile_id)
	var best_t: float = Events.get_level_best_time(profile_id) if is_instance_valid(Events) else -1.0
	var time_str: String = " | Rekord: %02d:%02d.%d" % [int(best_t) / 60, int(best_t) % 60, int((best_t - int(best_t)) * 10)] if best_t >= 0.0 else " | Zbierz wszystkie Jewele na czas!"
	mechanicInfoLabel.text = "%s — %s%s\n%s" % [
		String(meta["title"]),
		String(meta["subtitle"]),
		time_str,
		String(meta["description"])
	]
	if dnaRadarLabel:
		var dna: Dictionary = meta.get("dna", {"wall_climb": 33, "dash": 33, "double_jump": 34})
		var ch_info: String = "Brak"
		if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
			var reqs: Dictionary = Events.portal_sync.get_aggregated_challenge_requirements()
			var names: Array = reqs.get("active_challenge_names", [])
			if not names.is_empty():
				ch_info = ", ".join(names) + (" [min %d Jeweli]" % int(reqs.get("min_jewels", 0)))
		dnaRadarLabel.text = "RADAR DNA: Wspinaczka %d%% | Dash %d%% | Skoki %d%%   |   ZADANIA Z PORTALU: %s" % [
			int(dna.get("wall_climb", 33)),
			int(dna.get("dash", 33)),
			int(dna.get("double_jump", 34)),
			ch_info
		]

func _setup_settings_mockups() -> void:
	var modeOpt: OptionButton = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/GraphicsPanel/ModeBox/DisplayModeOpt")
	if modeOpt and modeOpt.item_count == 0:
		modeOpt.add_item("Pełny ekran (Fullscreen)")
		modeOpt.add_item("Okno (Windowed)")
		modeOpt.add_item("Okno bez ramek (Borderless)")
		modeOpt.selected = 1
		
	var resOpt: OptionButton = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/GraphicsPanel/ResBox/ResolutionOpt")
	if resOpt and resOpt.item_count == 0:
		resOpt.add_item("1280 x 720 (HD)")
		resOpt.add_item("1920 x 1080 (FHD)")
		resOpt.add_item("640 x 360 (Natywna makiety)")
		resOpt.selected = 0
		
	var fpsOpt: OptionButton = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/GraphicsPanel/FpsBox/FpsLimitOpt")
	if fpsOpt and fpsOpt.item_count == 0:
		fpsOpt.add_item("60 FPS")
		fpsOpt.add_item("120 FPS")
		fpsOpt.add_item("Bez limitu (Uncapped)")
		fpsOpt.selected = 0
		
	var langOpt: OptionButton = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/LanguagePanel/LangBox/LanguageOpt")
	if langOpt and langOpt.item_count == 0:
		langOpt.add_item("Polski (PL)")
		langOpt.add_item("English (EN)")
		langOpt.add_item("Deutsch (DE)")
		langOpt.selected = 0
		
	var masterSlider: HSlider = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel/MasterBox/MasterSlider")
	var masterVal: Label = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel/MasterBox/Value")
	if masterSlider and masterVal:
		masterSlider.value_changed.connect(func(v): masterVal.text = "%d%%" % int(v))
		
	var musicSlider: HSlider = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel/MusicBox/MusicSlider")
	var musicVal: Label = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel/MusicBox/Value")
	if musicSlider and musicVal:
		musicSlider.value_changed.connect(func(v): musicVal.text = "%d%%" % int(v))
		
	var sfxSlider: HSlider = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel/SfxBox/SfxSlider")
	var sfxVal: Label = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel/SfxBox/Value")
	if sfxSlider and sfxVal:
		sfxSlider.value_changed.connect(func(v): sfxVal.text = "%d%%" % int(v))

func _switchSettingsTab(tabIdx: int) -> void:
	currentSettingsTab = clampi(tabIdx, 0, 3)
	
	var panels = [audioPanel, graphicsPanel, controlsPanel, languagePanel]
	var buttons = [tabAudioBtn, tabGraphicsBtn, tabControlsBtn, tabLanguageBtn]
	
	for i in range(panels.size()):
		var p = panels[i]
		if p:
			p.visible = (i == currentSettingsTab)
			
	for i in range(buttons.size()):
		var b: Button = buttons[i]
		if b:
			if i == currentSettingsTab:
				b.text = "[ %s ]" % tabNames[i]
			else:
				b.text = tabNames[i]
				
	if buttons[currentSettingsTab]:
		buttons[currentSettingsTab].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if setView and setView.visible:
		if event.is_action_pressed("ui_cancel"):
			_showView(homeView)
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed:
			if event.keycode == KEY_Q or event.keycode == KEY_PAGEUP:
				_switchSettingsTab((currentSettingsTab - 1 + 4) % 4)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_E or event.keycode == KEY_PAGEDOWN:
				_switchSettingsTab((currentSettingsTab + 1) % 4)
				get_viewport().set_input_as_handled()
				return
			elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
				_switchSettingsTab(event.keycode - KEY_1)
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("ui_cancel"):
		if homeView and not homeView.visible:
			_showView(homeView)
			get_viewport().set_input_as_handled()

func _showView(targetView: Control) -> void:
	if homeView: homeView.visible = (targetView == homeView)
	if lvlView: lvlView.visible = (targetView == lvlView)
	if setView: setView.visible = (targetView == setView)
	if creatorsView: creatorsView.visible = (targetView == creatorsView)
	
	if targetView == homeView and playBtn:
		playBtn.grab_focus()
	elif targetView == lvlView:
		_update_level_select()
		_update_contract_btn_text()
		if lvl1Btn:
			lvl1Btn.grab_focus()
	elif targetView == setView:
		_switchSettingsTab(currentSettingsTab)

func _update_level_select() -> void:
	var is_lvl1_done = Events.is_level_completed(1)
	if lvl1CompletedBadge:
		lvl1CompletedBadge.visible = is_lvl1_done
	if lvl1CheckmarkIcon:
		lvl1CheckmarkIcon.visible = is_lvl1_done

func _startLevelProfile(profile_id: int, custom_seed: int = 0) -> void:
	if is_instance_valid(Events):
		Events.selected_level_profile = profile_id
		Events.selected_level_seed = custom_seed
	_startGame()

func _startGame() -> void:
	if not ResourceLoader.exists(arenaScenePath):
		push_error("BŁĄD: Nie znaleziono pliku sceny: " + arenaScenePath)
		return
		
	Events.level_started.emit()
	get_tree().change_scene_to_file(arenaScenePath)

func _toggleMusic() -> void:
	isMusicMuted = not isMusicMuted
	if musicPlayer:
		musicPlayer.stream_paused = isMusicMuted
		
	var busIdx = AudioServer.get_bus_index("Music")
	if busIdx != -1:
		AudioServer.set_bus_mute(busIdx, isMusicMuted)

func _toggleSfx() -> void:
	isSfxMuted = not isSfxMuted
	var busIdx = AudioServer.get_bus_index("SFX")
	if busIdx != -1:
		AudioServer.set_bus_mute(busIdx, isSfxMuted)

func _toggleFullscreen() -> void:
	var curMode = DisplayServer.window_get_mode()
	if curMode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
