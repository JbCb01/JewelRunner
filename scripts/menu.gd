extends Control

const LevelGenerator = preload("res://scripts/core/level_generator.gd")

@export_file("*.tscn") var arenaScenePath: String = "res://scenes/test_arena.tscn"

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
@onready var lvlBackBtn: Button = get_node_or_null("LevelSelectView/BackBtn")
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

# --- Widoki i kontrolery Profilu (Ustawienia Profilu, SkinSelect, Profil, Zadania) ---
@onready var profileSettingsView: Control = get_node_or_null("ProfileSettingsView")
@onready var skinSelectView: Control = get_node_or_null("SkinSelectView")
@onready var profileView: Control = get_node_or_null("ProfileView")
@onready var zadaniaView: Control = get_node_or_null("ZadaniaView")

@onready var profSettingsProfileBtn: Button = get_node_or_null("ProfileSettingsView/ProfilBtn")
@onready var profSettingsSkinBtn: Button = get_node_or_null("ProfileSettingsView/SkinSelectBtn")
@onready var profSettingsZadaniaBtn: Button = get_node_or_null("ProfileSettingsView/ZadaniaBtn")
@onready var profSettingsBackBtn: Button = get_node_or_null("ProfileSettingsView/BackBtn")

@onready var skinButtons: Array[Button] = [
	get_node_or_null("SkinSelectView/Skin0Btn") as Button,
	get_node_or_null("SkinSelectView/Skin1Btn") as Button,
	get_node_or_null("SkinSelectView/Skin2Btn") as Button,
	get_node_or_null("SkinSelectView/Skin3Btn") as Button,
	get_node_or_null("SkinSelectView/Skin4Btn") as Button,
	get_node_or_null("SkinSelectView/Skin5Btn") as Button
]
@onready var skinSelectBackBtn: Button = get_node_or_null("SkinSelectView/BackBtn")
@onready var skinSelectActiveLabel: Label = get_node_or_null("SkinSelectView/ActiveSkinLabel")

@onready var profileCodeInput: LineEdit = get_node_or_null("ProfileView/PairingCodeInput")
@onready var profilePairBtn: Button = get_node_or_null("ProfileView/PairBtn")
@onready var profileOpenPortalBtn: Button = get_node_or_null("ProfileView/OpenPortalBtn")
@onready var profileStatusLabel: Label = get_node_or_null("ProfileView/StatusLabel")
@onready var profileBackBtn: Button = get_node_or_null("ProfileView/BackBtn")

@onready var zadaniaBackBtn: Button = get_node_or_null("ZadaniaView/BackBtn")
@onready var zadaniaTask1Box: Control = get_node_or_null("ZadaniaView/Task1Container")
@onready var zadaniaTask2Box: Control = get_node_or_null("ZadaniaView/Task2Container")
@onready var zadaniaTask3Box: Control = get_node_or_null("ZadaniaView/Task3Container")

@onready var sfxMenuSelect: AudioStreamPlayer = get_node_or_null("AudioMenuSelect")

var available_skins: Array[Dictionary] = [
	{
		"id": 0,
		"key": "base",
		"name": "Klasyczna Stelly",
		"display_name": "Klasyczna Stelly",
		"color_name": "Fioletowy",
		"color_hex": "#6A3FB5",
		"desc": "Klasyczny fioletowy strój bohaterki."
	},
	{
		"id": 1,
		"key": "noir",
		"name": "Noir Stelly",
		"display_name": "Noir Stelly",
		"color_name": "Monochrom",
		"color_hex": "#505050",
		"desc": "Elegancki czarno-biały styl film noir."
	},
	{
		"id": 2,
		"key": "office",
		"name": "Office Stelly",
		"display_name": "Office Stelly",
		"color_name": "Granatowy",
		"color_hex": "#2B3A4A",
		"desc": "Formalny garnitur korporacyjny."
	},
	{
		"id": 3,
		"key": "2077",
		"name": "2077 Stelly",
		"display_name": "2077 Stelly",
		"color_name": "Cyjan",
		"color_hex": "#2CE0D2",
		"desc": "Futurystyczny kombinezon z neonowymi akcentami."
	},
	{
		"id": 4,
		"key": "promissed",
		"name": "Promissed Stelly",
		"display_name": "Promissed Stelly",
		"color_name": "Morski",
		"color_hex": "#00B4D8",
		"desc": "Morski pancerz strażnika obietnicy."
	},
	{
		"id": 5,
		"key": "retro",
		"name": "Retro Stelly",
		"display_name": "Retro Stelly",
		"color_name": "Bursztynowy",
		"color_hex": "#F5A623",
		"desc": "Ciepłe barwy vintage z brzoskwiniowym odcieniem."
	}
]

var currentSettingsTab: int = 0
var tabNames: Array[String] = ["Dźwięk", "Grafika", "Sterowanie", "Język"]

var isMusicMuted: bool = false
var isSfxMuted: bool = false

var mechanicInfoLabel: Label = null
var dnaRadarLabel: Label = null
var aiGenerateBtn: Button = null
var aiContractBtn: Button = null

func _ready() -> void:
	_ensure_audio_buses()
	_ensure_top_profile_button()
	_setup_profile_navigation_ui()
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

## Kliknięcie przycisku profilu na górze w menu (Prawy górny róg):
## Przenosi gracza do ekranu Ustawienia Profilu (UstawieniaProfilu.png),
## z którego ma dostęp do: Profil, Skórki (SkinSelect) oraz Zadania!
func _on_profile_btn_pressed() -> void:
	_play_menu_sfx()
	if profileSettingsView:
		_showView(profileSettingsView)

## Konfiguruje przyciski nawigacyjne dla ekranu Ustawienia Profilu oraz ekranów potomnych:
## SkinSelect, Profil, Zadania, LevelSelect oraz Twórcy.
func _setup_profile_navigation_ui() -> void:
	# 1. Ekran główny Ustawień Profilu (UstawieniaProfilu.png)
	if profSettingsProfileBtn and not profSettingsProfileBtn.pressed.is_connected(_on_nav_to_profile):
		profSettingsProfileBtn.pressed.connect(_on_nav_to_profile)
	if profSettingsSkinBtn and not profSettingsSkinBtn.pressed.is_connected(_on_nav_to_skin_select):
		profSettingsSkinBtn.pressed.connect(_on_nav_to_skin_select)
	if profSettingsZadaniaBtn and not profSettingsZadaniaBtn.pressed.is_connected(_on_nav_to_zadania):
		profSettingsZadaniaBtn.pressed.connect(_on_nav_to_zadania)
	if profSettingsBackBtn and not profSettingsBackBtn.pressed.is_connected(_on_nav_back_to_home):
		profSettingsBackBtn.pressed.connect(_on_nav_back_to_home)
		
	# 2. Ekran wyboru skórki (SkinSelect.png)
	for idx in range(skinButtons.size()):
		var btn: Button = skinButtons[idx]
		if btn:
			var s_idx: int = idx
			if not btn.pressed.is_connected(func(): _select_skin(s_idx)):
				btn.pressed.connect(func(): _select_skin(s_idx))
	if skinSelectBackBtn and not skinSelectBackBtn.pressed.is_connected(_on_nav_back_to_profile_settings):
		skinSelectBackBtn.pressed.connect(_on_nav_back_to_profile_settings)
		
	# 3. Ekran szczegółów profilu (Profil.png)
	if profilePairBtn and not profilePairBtn.pressed.is_connected(_on_profile_pair_btn_pressed):
		profilePairBtn.pressed.connect(_on_profile_pair_btn_pressed)
	if profileOpenPortalBtn and not profileOpenPortalBtn.pressed.is_connected(_on_profile_open_web_pressed):
		profileOpenPortalBtn.pressed.connect(_on_profile_open_web_pressed)
	if profileBackBtn and not profileBackBtn.pressed.is_connected(_on_nav_back_to_profile_settings):
		profileBackBtn.pressed.connect(_on_nav_back_to_profile_settings)
	if profileCodeInput and not profileCodeInput.text_submitted.is_connected(_on_profile_code_submitted):
		profileCodeInput.text_submitted.connect(_on_profile_code_submitted)
		
	# 4. Ekran zadań (Zadania.png)
	if zadaniaBackBtn and not zadaniaBackBtn.pressed.is_connected(_on_nav_back_to_profile_settings):
		zadaniaBackBtn.pressed.connect(_on_nav_back_to_profile_settings)
		
	# 5. Ekran wyboru poziomu (LevelSelect.png) - Powrót
	if lvlBackBtn and not lvlBackBtn.pressed.is_connected(_on_nav_back_to_home):
		lvlBackBtn.pressed.connect(_on_nav_back_to_home)
		
	# 6. Ekran twórców (CreatorsScreen)
	var creatorsBackBtn: Button = get_node_or_null("CreatorsView/BackBtn")
	if creatorsBackBtn and not creatorsBackBtn.pressed.is_connected(_on_nav_back_to_home):
		creatorsBackBtn.pressed.connect(_on_nav_back_to_home)

func _on_nav_to_profile() -> void:
	_play_menu_sfx()
	if profileView:
		_showView(profileView)

func _on_nav_to_skin_select() -> void:
	_play_menu_sfx()
	if skinSelectView:
		_showView(skinSelectView)

func _on_nav_to_zadania() -> void:
	_play_menu_sfx()
	if zadaniaView:
		_showView(zadaniaView)

func _on_nav_back_to_profile_settings() -> void:
	_play_menu_sfx()
	if profileSettingsView:
		_showView(profileSettingsView)
	else:
		_showView(homeView)

func _on_nav_back_to_home() -> void:
	_play_menu_sfx()
	_showView(homeView)

func _on_profile_code_submitted(_txt: String) -> void:
	_on_profile_pair_btn_pressed()

func _select_skin(skin_idx: int) -> void:
	if skin_idx < 0 or skin_idx >= available_skins.size():
		return
	var s: Dictionary = available_skins[skin_idx]
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.cosmetics_state["active_skin"] = s["name"]
		Events.portal_sync.cosmetics_state["active_skin_key"] = s["key"]
		Events.portal_sync.cosmetics_state["active_color_name"] = s["color_name"]
		Events.portal_sync.cosmetics_state["active_color_hex"] = s["color_hex"]
		Events.portal_profile_synced.emit(Events.portal_sync.build_current_state_payload())
	_play_menu_sfx()
	_refresh_skin_select_ui()

func _get_active_skin_index() -> int:
	var active_name: String = "Klasyczna Stelly"
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		active_name = String(Events.portal_sync.cosmetics_state.get("active_skin", "Klasyczna Stelly"))
	var info: Dictionary = SkinManager.get_skin_info(active_name)
	return int(info.get("id", 0))

func _refresh_skin_select_ui() -> void:
	var cur_idx: int = _get_active_skin_index()
	for idx in range(skinButtons.size()):
		var btn: Button = skinButtons[idx]
		if not btn:
			continue
		var is_sel: bool = (idx == cur_idx)
		var badge: Label = btn.get_node_or_null("Badge") as Label
		if badge:
			badge.visible = is_sel
	if skinSelectActiveLabel and cur_idx >= 0 and cur_idx < available_skins.size():
		var s: Dictionary = available_skins[cur_idx]
		skinSelectActiveLabel.text = "Aktywna skórka: %s (%s) — %s" % [s["display_name"], s["color_name"], s["desc"]]

func _refresh_profile_screen_ui() -> void:
	if not profileStatusLabel:
		return
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		var ps: Node = Events.portal_sync
		var uname: String = String(ps.player_profile.get("username", "Gość"))
		var gems: int = int(ps.player_profile.get("gems", 0))
		var skin: String = String(ps.cosmetics_state.get("active_skin", "Skórka podstawowa"))
		if ps.is_linked:
			profileStatusLabel.text = "Połączono z kontem: %s | Klejnoty: %d 💎 | Skórka: %s\nStatus: Aktywna sesja portalu webowego" % [uname, gems, skin]
		else:
			profileStatusLabel.text = "Status: Konto niepołączone (Tryb Gościa)\nWpisz 6-znakowy kod z /profil lub kliknij 'Otwórz Portal w Przeglądarce'."

func _on_profile_pair_btn_pressed() -> void:
	_play_menu_sfx()
	if not is_instance_valid(Events) or not is_instance_valid(Events.portal_sync):
		return
	var code_txt: String = "DEMO99"
	if profileCodeInput and not profileCodeInput.text.strip_edges().is_empty():
		code_txt = profileCodeInput.text.strip_edges()
		
	var ok: bool = Events.portal_sync.pair_with_code(code_txt)
	if ok:
		if profileStatusLabel:
			profileStatusLabel.text = "Trwa łączenie z kontem portalu (Kod: %s)..." % code_txt.to_upper()
	else:
		if profileStatusLabel:
			profileStatusLabel.text = "Błąd: Kod musi mieć 6 znaków alfanumerycznych (np. K7P2QX)."

func _on_profile_open_web_pressed() -> void:
	_play_menu_sfx()
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.open_profile_webpage("/profil")
		if profileStatusLabel:
			profileStatusLabel.text = "Otwarto Portal Gracza w przeglądarce (/profil)..."

func _refresh_zadania_ui() -> void:
	var challenges: Array = []
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		challenges = Events.portal_sync.get_active_challenges()
		
	var containers = [zadaniaTask1Box, zadaniaTask2Box, zadaniaTask3Box]
	for idx in range(containers.size()):
		var c = containers[idx]
		if not c:
			continue
		var titleLbl: Label = c.get_node_or_null("Title") as Label
		var descLbl: Label = c.get_node_or_null("Desc") as Label
		var progLbl: Label = c.get_node_or_null("Progress") as Label
		var rewLbl: Label = c.get_node_or_null("Reward") as Label
		
		if idx < challenges.size() and challenges[idx] is Dictionary:
			var ch: Dictionary = challenges[idx]
			if titleLbl: titleLbl.text = String(ch.get("name", "Zadanie %d" % (idx + 1)))
			if descLbl: descLbl.text = String(ch.get("description", ""))
			var pct: int = int(ch.get("progress_percent", 0))
			var is_done: bool = String(ch.get("status", "")) == "Ukończone" or pct >= 100
			if progLbl:
				if is_done:
					progLbl.text = "✔ UKOŃCZONE"
					progLbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
				else:
					progLbl.text = "Postęp: %d%%" % pct
					progLbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65, 1.0))
			if rewLbl:
				var r: Dictionary = ch.get("reward", {}) if ch.get("reward") is Dictionary else {}
				var r_type: String = String(r.get("type", ""))
				if r_type == "klejnoty":
					rewLbl.text = "Nagroda: +%d Klejnotów 💎" % int(r.get("gems", 0))
				elif r_type == "skórka":
					var sname: String = String(r.get("element_name", "Specjalna"))
					if sname == "Złoty biegacz":
						sname = "Bursztynowa Stelly"
					rewLbl.text = "Nagroda: Skórka %s" % sname
				elif r_type == "akcesorium":
					rewLbl.text = "Nagroda: %s" % String(r.get("element_name", "Akcesorium"))
				elif r_type == "wzmocnienie":
					rewLbl.text = "Nagroda: Wzmocnienie %s" % String(r.get("booster_type", ""))
				else:
					rewLbl.text = "Nagroda: +200 Klejnotów"

func _play_menu_sfx() -> void:
	if sfxMenuSelect and not isSfxMuted:
		sfxMenuSelect.play()

func _on_portal_profile_synced(profile_state: Dictionary) -> void:
	_refresh_profile_screen_ui()
	_refresh_skin_select_ui()
	if profile_state.has("settings") and profile_state["settings"] is Dictionary:
		var s := profile_state["settings"] as Dictionary
		var musicSlider: HSlider = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel/MusicBox/MusicSlider")
		if musicSlider and s.has("music_volume"):
			musicSlider.value = float(s["music_volume"])
		var sfxSlider: HSlider = get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel/SfxBox/SfxSlider")
		if sfxSlider and s.has("sfx_volume"):
			sfxSlider.value = float(s["sfx_volume"])

func _on_portal_challenges_synced(_challenges: Array) -> void:
	_refresh_zadania_ui()
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
		aiGenerateBtn.focus_entered.connect(func(): _preview_mechanic_profile(4))
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

## Upewnia sie, ze szyny audio Master, Music i SFX istnieja w AudioServerze.
func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

## Ustawia glosnosc na danej szynie (wartosc od 0 do 100).
func _set_bus_volume_percent(bus_name: String, pct: float) -> void:
	_ensure_audio_buses()
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return
	if pct <= 0.001:
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		var linear = clampf(pct / 100.0, 0.0001, 1.0)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear))
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
			_play_menu_sfx()
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
		if (skinSelectView and skinSelectView.visible) or \
		   (profileView and profileView.visible) or \
		   (zadaniaView and zadaniaView.visible):
			_play_menu_sfx()
			_showView(profileSettingsView)
			get_viewport().set_input_as_handled()
			return
		if profileSettingsView and profileSettingsView.visible:
			_play_menu_sfx()
			_showView(homeView)
			get_viewport().set_input_as_handled()
			return
		if lvlView and lvlView.visible:
			_play_menu_sfx()
			_showView(homeView)
			get_viewport().set_input_as_handled()
			return
		if creatorsView and creatorsView.visible:
			_play_menu_sfx()
			_showView(homeView)
			get_viewport().set_input_as_handled()
			return
		if homeView and not homeView.visible:
			_play_menu_sfx()
			_showView(homeView)
			get_viewport().set_input_as_handled()
			return

func _showView(targetView: Control) -> void:
	if homeView: homeView.visible = (targetView == homeView)
	if lvlView: lvlView.visible = (targetView == lvlView)
	if setView: setView.visible = (targetView == setView)
	if creatorsView: creatorsView.visible = (targetView == creatorsView)
	if profileSettingsView: profileSettingsView.visible = (targetView == profileSettingsView)
	if skinSelectView: skinSelectView.visible = (targetView == skinSelectView)
	if profileView: profileView.visible = (targetView == profileView)
	if zadaniaView: zadaniaView.visible = (targetView == zadaniaView)
	
	if targetView == homeView:
		if playBtn: playBtn.grab_focus()
	elif targetView == lvlView:
		_update_level_select()
		_update_contract_btn_text()
		_preview_mechanic_profile(1)
		if lvl1Btn: lvl1Btn.grab_focus()
	elif targetView == setView:
		_switchSettingsTab(currentSettingsTab)
	elif targetView == profileSettingsView:
		if profSettingsProfileBtn: profSettingsProfileBtn.grab_focus()
	elif targetView == skinSelectView:
		_refresh_skin_select_ui()
		var s_idx: int = _get_active_skin_index()
		if s_idx >= 0 and s_idx < skinButtons.size() and skinButtons[s_idx]:
			skinButtons[s_idx].grab_focus()
	elif targetView == profileView:
		_refresh_profile_screen_ui()
		if profileCodeInput: profileCodeInput.grab_focus()
	elif targetView == zadaniaView:
		_refresh_zadania_ui()
		if zadaniaBackBtn: zadaniaBackBtn.grab_focus()

func _update_level_select() -> void:
	var is_lvl1_done = Events.is_level_completed(1) if is_instance_valid(Events) else false
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
