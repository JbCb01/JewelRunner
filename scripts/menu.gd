extends Control

const LevelGenerator = preload("res://scripts/core/level_generator.gd")
const SkinManager = preload("res://scripts/core/skin_manager.gd")

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
@onready var tabAudioBtn: Button = get_node_or_null("SettingsView/TabBar/TabAudioBtn") if has_node("SettingsView/TabBar/TabAudioBtn") else get_node_or_null("SettingsView/DarkOverlay/SettingsContent/TabBar/TabAudioBtn")
@onready var tabGraphicsBtn: Button = get_node_or_null("SettingsView/TabBar/TabGraphicsBtn") if has_node("SettingsView/TabBar/TabGraphicsBtn") else get_node_or_null("SettingsView/DarkOverlay/SettingsContent/TabBar/TabGraphicsBtn")
@onready var tabControlsBtn: Button = get_node_or_null("SettingsView/TabBar/TabControlsBtn") if has_node("SettingsView/TabBar/TabControlsBtn") else get_node_or_null("SettingsView/DarkOverlay/SettingsContent/TabBar/TabControlsBtn")
@onready var tabLanguageBtn: Button = get_node_or_null("SettingsView/TabBar/TabLanguageBtn") if has_node("SettingsView/TabBar/TabLanguageBtn") else get_node_or_null("SettingsView/DarkOverlay/SettingsContent/TabBar/TabLanguageBtn")
@onready var settingsBackBtn: Button = get_node_or_null("SettingsView/BackBtn") if has_node("SettingsView/BackBtn") else get_node_or_null("SettingsView/DarkOverlay/SettingsContent/FooterBox/SettingsBackBtn")

@onready var audioPanel: Control = get_node_or_null("SettingsView/Panels/AudioPanel") if has_node("SettingsView/Panels/AudioPanel") else get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/AudioPanel")
@onready var graphicsPanel: Control = get_node_or_null("SettingsView/Panels/GraphicsPanel") if has_node("SettingsView/Panels/GraphicsPanel") else get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/GraphicsPanel")
@onready var controlsPanel: Control = get_node_or_null("SettingsView/Panels/ControlsPanel") if has_node("SettingsView/Panels/ControlsPanel") else get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/ControlsPanel")
@onready var languagePanel: Control = get_node_or_null("SettingsView/Panels/LanguagePanel") if has_node("SettingsView/Panels/LanguagePanel") else get_node_or_null("SettingsView/DarkOverlay/SettingsContent/Panels/LanguagePanel")

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
var profileDisconnectBtn: Button = null
var profileConflictCloudBtn: Button = null
var profileConflictLocalBtn: Button = null
var homeDailyRewardBtn: Button = null

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
var tabNames: Array = ["MUZYKA", "GRAFIKA", "STEROWANIE", "JĘZYK"]
var current_language: String = "pl"
var subtitles_enabled: bool = true

var isMasterMuted: bool = false
var isMusicMuted: bool = false
var isSfxMuted: bool = false

var mechanicInfoLabel: Label = null
var dnaRadarLabel: Label = null
var aiGenerateBtn: Button = null
var aiContractBtn: Button = null
var _last_rendered_skin_idx: int = -1

func _ready() -> void:
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		if Events.portal_sync.cosmetics_state.has("language"):
			current_language = String(Events.portal_sync.cosmetics_state.get("language", "pl"))
	_ensure_audio_buses()
	_ensure_top_profile_button()
	_ensure_daily_reward_button()
	_setup_profile_navigation_ui()
	_setup_mechanic_level_select_ui()
	if is_instance_valid(Events) and Events.get("return_to_level_select") == true:
		Events.return_to_level_select = false
		_showView(lvlView)
	else:
		_showView(homeView)
	_update_level_select()
	_setup_settings_mockups()
	_apply_language(current_language)

	if musicPlayer:
		if musicPlayer.stream is AudioStreamWAV:
			(musicPlayer.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		if not musicPlayer.finished.is_connected(musicPlayer.play):
			musicPlayer.finished.connect(musicPlayer.play)
		if not musicPlayer.playing and not isMusicMuted:
			musicPlayer.play()
	
	if is_instance_valid(Events):
		if not Events.portal_profile_synced.is_connected(_on_portal_profile_synced):
			Events.portal_profile_synced.connect(_on_portal_profile_synced)
		if not Events.portal_challenges_synced.is_connected(_on_portal_challenges_synced):
			Events.portal_challenges_synced.connect(_on_portal_challenges_synced)
		if not Events.portal_sync_failed.is_connected(_on_portal_sync_failed):
			Events.portal_sync_failed.connect(_on_portal_sync_failed)
		if not Events.portal_daily_reward_updated.is_connected(_on_portal_daily_reward_updated):
			Events.portal_daily_reward_updated.connect(_on_portal_daily_reward_updated)
		if not Events.portal_cloud_save_loaded.is_connected(_on_portal_cloud_save_loaded):
			Events.portal_cloud_save_loaded.connect(_on_portal_cloud_save_loaded)
		if not Events.portal_save_conflict.is_connected(_on_portal_save_conflict):
			Events.portal_save_conflict.connect(_on_portal_save_conflict)
		if is_instance_valid(Events.portal_sync):
			Events.portal_sync.sync_if_needed(1.5)
	
	if profileBtn and not profileBtn.pressed.is_connected(_on_profile_btn_pressed):
		profileBtn.pressed.connect(_on_profile_btn_pressed)
	if playBtn: playBtn.pressed.connect(_on_play_btn_pressed)
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

	var tab_btns = [tabAudioBtn, tabGraphicsBtn, tabControlsBtn, tabLanguageBtn]
	for idx in range(tab_btns.size()):
		var b = tab_btns[idx]
		if b and not b.focus_entered.is_connected(Callable(self, "_on_tab_focused").bind(idx)):
			b.focus_entered.connect(_on_tab_focused.bind(idx))

func _on_tab_focused(idx: int) -> void:
	if currentSettingsTab != idx:
		_switchSettingsTab(idx)

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
	_ensure_profile_action_buttons()
		
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
		if Events.portal_sync.is_linked and not Events.portal_sync.is_skin_owned(s["name"]):
			_play_menu_sfx()
			if skinSelectActiveLabel:
				if current_language == "en":
					skinSelectActiveLabel.text = "🔒 %s — Locked. Unlock by playing or check requirements in Portal (/kolekcja)." % s["display_name"]
				else:
					skinSelectActiveLabel.text = "🔒 %s — Zablokowana. Odblokuj grając lub sprawdź warunki w Portalu (/kolekcja)." % s["display_name"]
			return
		Events.portal_sync.cosmetics_state["active_skin"] = s["name"]
		Events.portal_sync.cosmetics_state["active_skin_key"] = s["key"]
		Events.portal_sync.cosmetics_state["active_skin_asset"] = ""
		if not Events.portal_sync.is_linked:
			Events.portal_sync.cosmetics_state["active_color_name"] = s["color_name"]
			Events.portal_sync.cosmetics_state["active_color_hex"] = s["color_hex"]
		Events.portal_sync.save_appearance_to_web(s["name"])
		var payload: Dictionary = Events.portal_sync.build_current_state_payload()
		payload["source"] = "skin_select"
		payload["is_local_skin_change"] = true
		Events.portal_profile_synced.emit(payload)
	_play_menu_sfx()
	_refresh_skin_select_ui()

func _get_active_skin_index() -> int:
	var active_name: String = "Klasyczna Stelly"
	var active_asset: String = ""
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		active_name = String(Events.portal_sync.cosmetics_state.get("active_skin", "Klasyczna Stelly"))
		active_asset = String(Events.portal_sync.cosmetics_state.get("active_skin_asset", ""))
	var info: Dictionary = SkinManager.get_skin_info(active_name)
	if int(info.get("id", 0)) == 0 and not active_asset.is_empty():
		info = SkinManager.get_skin_info(active_asset)
	return int(info.get("id", 0))

func _refresh_skin_select_ui() -> void:
	var cur_idx: int = _get_active_skin_index()
	var ps: Node = Events.portal_sync if is_instance_valid(Events) else null
	for idx in range(skinButtons.size()):
		var btn: Button = skinButtons[idx]
		if not btn:
			continue
		var s: Dictionary = available_skins[idx]
		var is_sel: bool = (idx == cur_idx)
		var is_owned: bool = is_sel or (true if not is_instance_valid(ps) else ps.is_skin_owned(s["name"]))
		btn.modulate = Color.WHITE if is_owned else Color(0.65, 0.65, 0.65, 1.0)
		if is_sel:
			var sb_sel := StyleBoxFlat.new()
			sb_sel.bg_color = Color(0.25, 0.95, 0.55, 0.14)
			sb_sel.border_color = Color(0.35, 1.0, 0.55, 0.95)
			sb_sel.set_border_width_all(2)
			sb_sel.set_corner_radius_all(4)
			btn.add_theme_stylebox_override("normal", sb_sel)
		else:
			btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		var badge: Label = btn.get_node_or_null("Badge") as Label
		if badge:
			if not is_owned:
				badge.visible = true
				badge.text = "🔒 LOCKED" if current_language == "en" else "🔒 ZABLOK."
				badge.add_theme_color_override("font_color", Color(1.0, 0.62, 0.42, 0.95))
			else:
				badge.visible = is_sel
				badge.text = "✔ SELECTED" if current_language == "en" else "✔ WYBRANA"
				badge.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6, 1.0))
	if skinSelectActiveLabel and cur_idx >= 0 and cur_idx < available_skins.size():
		var s: Dictionary = available_skins[cur_idx]
		var prefix = "Active Skin:" if current_language == "en" else "Aktywna skórka:"
		skinSelectActiveLabel.text = "%s %s (%s) — %s" % [prefix, s["display_name"], s["color_name"], s["desc"]]
	if skinSelectView and skinSelectView.visible and cur_idx != _last_rendered_skin_idx and cur_idx >= 0 and cur_idx < skinButtons.size() and skinButtons[cur_idx]:
		skinButtons[cur_idx].grab_focus()
	_last_rendered_skin_idx = cur_idx

func _ensure_daily_reward_button() -> void:
	if not homeView:
		return
	homeDailyRewardBtn = homeView.get_node_or_null("DailyRewardBtn") as Button
	if not homeDailyRewardBtn:
		homeDailyRewardBtn = _create_profile_action_button("DailyRewardBtn", Vector2(12, 8), Vector2(260, 26))
		var sb_gold := StyleBoxFlat.new()
		sb_gold.bg_color = Color(0.14, 0.10, 0.04, 0.88)
		sb_gold.border_color = Color(1.0, 0.84, 0.25, 0.95)
		sb_gold.set_border_width_all(2)
		sb_gold.set_corner_radius_all(4)
		homeDailyRewardBtn.add_theme_stylebox_override("normal", sb_gold)
		homeView.add_child(homeDailyRewardBtn)
	if not homeDailyRewardBtn.pressed.is_connected(_on_daily_reward_btn_pressed):
		homeDailyRewardBtn.pressed.connect(_on_daily_reward_btn_pressed)
	_refresh_daily_reward_ui()

func _refresh_daily_reward_ui() -> void:
	if not homeDailyRewardBtn:
		return
	if not is_instance_valid(Events) or not is_instance_valid(Events.portal_sync) or not Events.portal_sync.is_linked:
		homeDailyRewardBtn.visible = false
		return
	var state: Dictionary = Events.portal_sync.daily_reward_state
	if not bool(state.get("available", false)):
		homeDailyRewardBtn.visible = false
		return
	var day := int(state.get("streak_day", 1))
	var gems := int(state.get("gems", 10))
	homeDailyRewardBtn.disabled = false
	homeDailyRewardBtn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.65, 1.0))
	homeDailyRewardBtn.text = ("🎁 Daily Reward (Day %d): +%d 💎" % [day, gems]) if current_language == "en" else ("🎁 Nagroda dzienna (Dzień %d): +%d 💎" % [day, gems])
	homeDailyRewardBtn.visible = true

func _on_daily_reward_btn_pressed() -> void:
	_play_menu_sfx()
	if not is_instance_valid(Events) or not is_instance_valid(Events.portal_sync):
		return
	if homeDailyRewardBtn:
		homeDailyRewardBtn.disabled = true
		homeDailyRewardBtn.text = "Claiming..." if current_language == "en" else "Odbieranie..."
	Events.portal_sync.claim_daily_reward()

func _on_portal_daily_reward_updated(daily_state: Dictionary) -> void:
	if daily_state.has("balance") and homeDailyRewardBtn:
		var gems := int(daily_state.get("gems", 0))
		var bal := int(daily_state.get("balance", 0))
		homeDailyRewardBtn.visible = true
		homeDailyRewardBtn.disabled = true
		homeDailyRewardBtn.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65, 1.0))
		homeDailyRewardBtn.text = ("✔ Claimed +%d 💎! Balance: %d" % [gems, bal]) if current_language == "en" else ("✔ Odebrano +%d 💎! Saldo: %d" % [gems, bal])
		get_tree().create_timer(3.5).timeout.connect(func():
			if is_instance_valid(self):
				_refresh_daily_reward_ui()
		)
	else:
		_refresh_daily_reward_ui()
	_refresh_profile_screen_ui()

func _ensure_profile_action_buttons() -> void:
	if not profileView:
		return
	var legacy_sync_btn := profileView.get_node_or_null("SyncNowBtn") as Button
	if legacy_sync_btn:
		legacy_sync_btn.visible = false

	profileDisconnectBtn = profileView.get_node_or_null("DisconnectBtn") as Button
	if not profileDisconnectBtn:
		profileDisconnectBtn = _create_profile_action_button("DisconnectBtn", Vector2(128, 294), Vector2(383, 24))
		profileView.add_child(profileDisconnectBtn)
	else:
		profileDisconnectBtn.position = Vector2(128, 294)
		profileDisconnectBtn.size = Vector2(383, 24)
	if not profileDisconnectBtn.pressed.is_connected(_on_profile_disconnect_btn_pressed):
		profileDisconnectBtn.pressed.connect(_on_profile_disconnect_btn_pressed)

	profileConflictCloudBtn = profileView.get_node_or_null("ConflictCloudBtn") as Button
	if not profileConflictCloudBtn:
		profileConflictCloudBtn = _create_profile_action_button("ConflictCloudBtn", Vector2(128, 294), Vector2(187, 24))
		profileView.add_child(profileConflictCloudBtn)
	if not profileConflictCloudBtn.pressed.is_connected(_on_profile_conflict_cloud_pressed):
		profileConflictCloudBtn.pressed.connect(_on_profile_conflict_cloud_pressed)

	profileConflictLocalBtn = profileView.get_node_or_null("ConflictLocalBtn") as Button
	if not profileConflictLocalBtn:
		profileConflictLocalBtn = _create_profile_action_button("ConflictLocalBtn", Vector2(324, 294), Vector2(187, 24))
		profileView.add_child(profileConflictLocalBtn)
	if not profileConflictLocalBtn.pressed.is_connected(_on_profile_conflict_local_pressed):
		profileConflictLocalBtn.pressed.connect(_on_profile_conflict_local_pressed)
	_update_profile_action_buttons()

func _create_profile_action_button(btn_name: String, pos: Vector2, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.name = btn_name
	btn.position = pos
	btn.size = sz
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", 9)
	btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.65, 1.0))

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.11, 0.08, 0.16, 0.85)
	sb_normal.border_color = Color(0.55, 0.42, 0.72, 0.8)
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(3)

	var sb_hover := StyleBoxFlat.new()
	sb_hover.bg_color = Color(0.18, 0.13, 0.26, 0.95)
	sb_hover.border_color = Color(1.0, 0.88, 0.35, 0.95)
	sb_hover.set_border_width_all(2)
	sb_hover.set_corner_radius_all(3)

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("focus", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	return btn

func _update_profile_action_buttons() -> void:
	var ps: Node = Events.portal_sync if is_instance_valid(Events) else null
	var linked: bool = is_instance_valid(ps) and bool(ps.is_linked)
	var has_conflict: bool = is_instance_valid(ps) and ("save_conflict_server" in ps) and not (ps.save_conflict_server as Dictionary).is_empty()
	if profileDisconnectBtn:
		profileDisconnectBtn.visible = linked and not has_conflict
		profileDisconnectBtn.text = "Disconnect" if current_language == "en" else "Odłącz konto"
	if profileConflictCloudBtn:
		profileConflictCloudBtn.visible = linked and has_conflict
		profileConflictCloudBtn.text = "Load Cloud Save" if current_language == "en" else "Wczytaj z chmury"
	if profileConflictLocalBtn:
		profileConflictLocalBtn.visible = linked and has_conflict
		profileConflictLocalBtn.text = "Overwrite with Local" if current_language == "en" else "Nadpisz moim"

func _refresh_profile_screen_ui() -> void:
	_update_profile_action_buttons()
	if not profileStatusLabel:
		return
	profileStatusLabel.add_theme_color_override("font_color", Color(1.0, 0.94, 0.65, 1.0))
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		var ps: Node = Events.portal_sync
		var uname: String = String(ps.player_profile.get("username", "Gość" if current_language == "pl" else "Guest"))
		var gems: int = int(ps.player_profile.get("gems", 0))
		if is_instance_valid(Events.wallet_sync) and Events.wallet_sync.has_method("local_balance"):
			gems = maxi(gems, int(Events.wallet_sync.local_balance()))
		var skin: String = String(ps.cosmetics_state.get("active_skin", "Skórka podstawowa" if current_language == "pl" else "Default Skin"))
		if ps.is_linked:
			if profileCodeInput and not profileCodeInput.text.is_empty():
				profileCodeInput.text = ""
			if "save_conflict_server" in ps and not (ps.save_conflict_server as Dictionary).is_empty():
				profileStatusLabel.add_theme_color_override("font_color", Color(1.0, 0.72, 0.3, 1.0))
				if current_language == "en":
					profileStatusLabel.text = "Cloud save conflict detected! Choose: Load Cloud Save or Overwrite with Local."
				else:
					profileStatusLabel.text = "Konflikt zapisu w chmurze! Wybierz: Wczytaj z chmury lub Nadpisz moim."
				return
			var pending_runs_cnt: int = (ps.pending_runs as Array).size() if "pending_runs" in ps else 0
			var pending_bst_cnt: int = (ps.pending_booster_uses as Array).size() if "pending_booster_uses" in ps else 0
			var pending_wallet_cnt: int = (Events.wallet_sync.pending as Array).size() if is_instance_valid(Events.wallet_sync) and "pending" in Events.wallet_sync else 0
			var total_pending: int = pending_runs_cnt + pending_bst_cnt + pending_wallet_cnt
			var save_suffix: String = ""
			if "cloud_save" in ps and not (ps.cloud_save as Dictionary).is_empty():
				var cs := ps.cloud_save as Dictionary
				var lvl_name: String = String(cs.get("level_name", "Poziom %d" % int(cs.get("level", 1))))
				save_suffix = (" | Save: %s" % lvl_name) if current_language == "en" else (" | Zapis: %s" % lvl_name)
			if total_pending > 0:
				if current_language == "en":
					profileStatusLabel.text = "Linked: %s | Jewels: %d | Skin: %s%s\nStatus: Active session (%d queued for sync)" % [uname, gems, skin, save_suffix, total_pending]
				else:
					profileStatusLabel.text = "Połączono: %s | Klejnoty: %d | Skórka: %s%s\nStatus: Aktywna sesja (%d w kolejce do wysłania)" % [uname, gems, skin, save_suffix, total_pending]
			else:
				if current_language == "en":
					profileStatusLabel.text = "Linked to account: %s | Jewels: %d | Skin: %s%s\nStatus: Auto-sync with Azure portal active" % [uname, gems, skin, save_suffix]
				else:
					profileStatusLabel.text = "Połączono z kontem: %s | Klejnoty: %d | Skórka: %s%s\nStatus: Automatyczna synchronizacja z portalem Azure" % [uname, gems, skin, save_suffix]
		else:
			if current_language == "en":
				profileStatusLabel.text = "Status: Account not linked (Guest Mode)\nEnter 6-character code from /profile or click 'Open Portal in Browser'."
			else:
				profileStatusLabel.text = "Status: Konto niepołączone (Tryb Gościa)\nWpisz 6-znakowy kod z /profil lub kliknij 'Otwórz Portal w Przeglądarce'."

func _on_profile_pair_btn_pressed() -> void:
	_play_menu_sfx()
	if not is_instance_valid(Events) or not is_instance_valid(Events.portal_sync):
		return
	var code_txt: String = profileCodeInput.text.strip_edges() if profileCodeInput else ""
	if code_txt.is_empty():
		if profileStatusLabel:
			profileStatusLabel.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
			profileStatusLabel.text = "Enter the 6-character pairing code from /profile." if current_language == "en" else "Wpisz 6-znakowy kod parowania ze strony /profil."
		return
		
	var ok: bool = Events.portal_sync.pair_with_code(code_txt)
	if ok:
		if profileStatusLabel:
			profileStatusLabel.add_theme_color_override("font_color", Color(1.0, 0.94, 0.65, 1.0))
			if current_language == "en":
				profileStatusLabel.text = "Connecting to Azure portal (Code: %s)... First wake-up may take up to 30s." % code_txt.to_upper()
			else:
				profileStatusLabel.text = "Łączenie z portalem Azure (Kod: %s)... Pierwsze połączenie może potrwać do 30s." % code_txt.to_upper()
	else:
		if profileStatusLabel:
			profileStatusLabel.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
			if current_language == "en":
				profileStatusLabel.text = "Error: Code must be 6 alphanumeric characters (e.g. K7P2QX)."
			else:
				profileStatusLabel.text = "Błąd: Kod musi mieć 6 znaków alfanumerycznych (np. K7P2QX)."

func _on_profile_disconnect_btn_pressed() -> void:
	_play_menu_sfx()
	if not is_instance_valid(Events) or not is_instance_valid(Events.portal_sync):
		return
	Events.portal_sync.disconnect_account()
	_refresh_profile_screen_ui()

func _on_profile_conflict_cloud_pressed() -> void:
	_play_menu_sfx()
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.resolve_save_conflict(false)

func _on_profile_conflict_local_pressed() -> void:
	_play_menu_sfx()
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.resolve_save_conflict(true)

func _on_portal_cloud_save_loaded(_save_data: Dictionary) -> void:
	_refresh_profile_screen_ui()

func _on_portal_save_conflict(_local_save: Dictionary, _server_save: Dictionary) -> void:
	_refresh_profile_screen_ui()

func _on_portal_sync_failed(_code: String, message: String) -> void:
	_update_profile_action_buttons()
	if profileStatusLabel:
		profileStatusLabel.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45, 1.0))
		profileStatusLabel.text = message

func _on_profile_open_web_pressed() -> void:
	_play_menu_sfx()
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.open_profile_webpage("/profil")
		if profileStatusLabel:
			if current_language == "en":
				profileStatusLabel.text = "Player Portal opened in browser (/profile)..."
			else:
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
			if titleLbl:
				titleLbl.visible = true
				titleLbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				titleLbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
				var t_name: String = String(ch.get("name", "Task %d" % (idx + 1) if current_language == "en" else "Zadanie %d" % (idx + 1)))
				titleLbl.text = t_name
			if descLbl:
				descLbl.visible = true
				descLbl.text = String(ch.get("description", ""))
			var pct: int = int(ch.get("progress_percent", 0))
			var is_done: bool = String(ch.get("status", "")) == "Ukończone" or pct >= 100
			if progLbl:
				progLbl.visible = true
				if is_done:
					progLbl.text = "✔ COMPLETED" if current_language == "en" else "✔ UKOŃCZONE"
					progLbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
				else:
					progLbl.text = ("Progress: %d%%" if current_language == "en" else "Postęp: %d%%") % pct
					progLbl.add_theme_color_override("font_color", Color(0.45, 1.0, 0.65, 1.0))
			if rewLbl:
				rewLbl.visible = true
				var r: Dictionary = ch.get("reward", {}) if ch.get("reward") is Dictionary else {}
				var r_type: String = String(r.get("type", ""))
				if r_type == "klejnoty":
					rewLbl.text = ("Reward: +%d Jewels 💎" if current_language == "en" else "Nagroda: +%d Klejnotów 💎") % int(r.get("gems", 0))
				elif r_type == "skórka":
					var sname: String = String(r.get("element_name", "Specjalna"))
					if sname == "Złoty biegacz":
						sname = "Bursztynowa Stelly"
					rewLbl.text = ("Reward: Skin %s" if current_language == "en" else "Nagroda: Skórka %s") % sname
				elif r_type == "akcesorium":
					rewLbl.text = ("Reward: %s" if current_language == "en" else "Nagroda: %s") % String(r.get("element_name", "Accessory" if current_language == "en" else "Akcesorium"))
				elif r_type == "wzmocnienie":
					rewLbl.text = ("Reward: Booster %s" if current_language == "en" else "Nagroda: Wzmocnienie %s") % String(r.get("booster_type", ""))
				else:
					rewLbl.text = "Reward: +200 Jewels" if current_language == "en" else "Nagroda: +200 Klejnotów"
		else:
			if titleLbl:
				titleLbl.visible = true
				titleLbl.text = "Empty" if current_language == "en" else "Puste"
				titleLbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				titleLbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.82, 0.85))
			if descLbl:
				descLbl.text = ""
				descLbl.visible = false
			if progLbl:
				progLbl.text = ""
				progLbl.visible = false
			if rewLbl:
				rewLbl.text = ""
				rewLbl.visible = false

func _play_menu_sfx() -> void:
	if sfxMenuSelect and not isSfxMuted:
		sfxMenuSelect.play()

func _on_portal_profile_synced(profile_state: Dictionary) -> void:
	_refresh_profile_screen_ui()
	_refresh_skin_select_ui()
	
	# Zmiana skórki w menu nie może resetować ani modyfikować ustawień audio/języka!
	if profile_state.get("is_local_skin_change", false) or String(profile_state.get("source", "")) == "skin_select":
		return
	_refresh_zadania_ui()
	_refresh_daily_reward_ui()
		
	if profile_state.has("settings") and profile_state["settings"] is Dictionary:
		var s := profile_state["settings"] as Dictionary
		var musicSlider: HSlider = _find_in_settings("MusicSlider") as HSlider
		if musicSlider and s.has("music_volume"):
			var raw_m = float(s["music_volume"])
			var target_m = raw_m * 100.0 if (raw_m > 0.0 and raw_m < 1.0) else raw_m
			musicSlider.value = clampf(target_m, 0.0, 100.0)
			_set_bus_volume_percent("MusicMenu", musicSlider.value)
			_set_bus_volume_percent("Music", musicSlider.value)
		var levelMusicSlider: HSlider = _find_in_settings("LevelMusicSlider") as HSlider
		if levelMusicSlider and s.has("level_music_volume"):
			var raw_lm = float(s["level_music_volume"])
			var target_lm = raw_lm * 100.0 if (raw_lm > 0.0 and raw_lm < 1.0) else raw_lm
			levelMusicSlider.value = clampf(target_lm, 0.0, 100.0)
			_set_bus_volume_percent("MusicLevel", levelMusicSlider.value)
		var sfxSlider: HSlider = _find_in_settings("SfxSlider") as HSlider
		if sfxSlider and s.has("sfx_volume"):
			var raw_s = float(s["sfx_volume"])
			var target_s = raw_s * 100.0 if (raw_s > 0.0 and raw_s < 1.0) else raw_s
			sfxSlider.value = clampf(target_s, 0.0, 100.0)
			_set_bus_volume_percent("SFX", sfxSlider.value)
		if s.has("language"):
			_apply_language(String(s["language"]))

func _on_portal_challenges_synced(_challenges: Array) -> void:
	_refresh_zadania_ui()
	_preview_mechanic_profile(Events.selected_level_profile if is_instance_valid(Events) else 1)

## Upewnia się, że szyny audio Master, Music, MusicMenu, MusicLevel i SFX istnieją w AudioServerze.
func _ensure_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("MusicMenu") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "MusicMenu")
		AudioServer.set_bus_send(idx, "Music")
	if AudioServer.get_bus_index("MusicLevel") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "MusicLevel")
		AudioServer.set_bus_send(idx, "Music")
	if AudioServer.get_bus_index("SFX") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

## Ustawia głośność na danej szynie (wartość od 0 do 100).
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

## Rozbudowuje karty Level Select o Żywioły Ruchu (Trials of Flow), Dynamiczny Radar DNA Mechanik,
## wybór Kontraktu Reżysera AI oraz podgląd aktywnych zadań ze strony internetowej na nowo utworzonych panelach.
func _setup_mechanic_level_select_ui() -> void:
	if not lvlView:
		return
		
	# 1. Pobranie lub utworzenie panelu informacyjnego dopasowanego do nowej grafiki LevelSelect.png
	var panel: Control = lvlView.get_node_or_null("MechanicInfoPanel") as Control
	if not panel:
		panel = Control.new()
		panel.name = "MechanicInfoPanel"
		panel.position = Vector2(45, 244)
		panel.size = Vector2(547, 45)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lvlView.add_child(panel)
	else:
		panel.position = Vector2(45, 244)
		panel.size = Vector2(547, 45)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	mechanicInfoLabel = panel.get_node_or_null("MechanicInfoLabel") as Label
	if not mechanicInfoLabel:
		mechanicInfoLabel = Label.new()
		mechanicInfoLabel.name = "MechanicInfoLabel"
		mechanicInfoLabel.position = Vector2(6, 2)
		mechanicInfoLabel.size = Vector2(535, 24)
		mechanicInfoLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mechanicInfoLabel.add_theme_font_size_override("font_size", 9)
		mechanicInfoLabel.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
		panel.add_child(mechanicInfoLabel)
	else:
		mechanicInfoLabel.position = Vector2(6, 2)
		mechanicInfoLabel.size = Vector2(535, 24)
		mechanicInfoLabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mechanicInfoLabel.add_theme_font_size_override("font_size", 9)

	dnaRadarLabel = panel.get_node_or_null("DnaRadarLabel") as Label
	if not dnaRadarLabel:
		dnaRadarLabel = Label.new()
		dnaRadarLabel.name = "DnaRadarLabel"
		dnaRadarLabel.position = Vector2(6, 27)
		dnaRadarLabel.size = Vector2(535, 16)
		dnaRadarLabel.add_theme_font_size_override("font_size", 8)
		dnaRadarLabel.add_theme_color_override("font_color", Color(0.45, 0.95, 0.72, 1.0))
		panel.add_child(dnaRadarLabel)
	else:
		dnaRadarLabel.position = Vector2(6, 27)
		dnaRadarLabel.size = Vector2(535, 16)
		dnaRadarLabel.add_theme_font_size_override("font_size", 8)

	# 2. Pobranie lub utworzenie lewego przycisku: Kontrakt Reżysera AI (x=45, y=296, w=244, h=24)
	aiContractBtn = lvlView.get_node_or_null("AIContractBtn") as Button
	if not aiContractBtn:
		aiContractBtn = Button.new()
		aiContractBtn.name = "AIContractBtn"
		aiContractBtn.position = Vector2(45, 296)
		aiContractBtn.size = Vector2(244, 24)
		aiContractBtn.flat = true
		aiContractBtn.add_theme_font_size_override("font_size", 9)
		aiContractBtn.pressed.connect(_cycle_ai_contract)
		lvlView.add_child(aiContractBtn)
	else:
		aiContractBtn.position = Vector2(45, 296)
		aiContractBtn.size = Vector2(244, 24)
		aiContractBtn.flat = true
		aiContractBtn.add_theme_font_size_override("font_size", 9)
		if not aiContractBtn.pressed.is_connected(_cycle_ai_contract):
			aiContractBtn.pressed.connect(_cycle_ai_contract)
	_update_contract_btn_text()

	# 3. Pobranie lub utworzenie prawego przycisku: Szachownica AI (x=345, y=296, w=247, h=24)
	aiGenerateBtn = lvlView.get_node_or_null("AIGenerateBtn") as Button
	if not aiGenerateBtn:
		aiGenerateBtn = Button.new()
		aiGenerateBtn.name = "AIGenerateBtn"
		aiGenerateBtn.position = Vector2(345, 296)
		aiGenerateBtn.size = Vector2(247, 24)
		aiGenerateBtn.flat = true
		aiGenerateBtn.add_theme_font_size_override("font_size", 9)
		aiGenerateBtn.text = "⚡ IV. SZACHOWNICA AI + ZADANIA"
		lvlView.add_child(aiGenerateBtn)
	else:
		aiGenerateBtn.position = Vector2(345, 296)
		aiGenerateBtn.size = Vector2(247, 24)
		aiGenerateBtn.flat = true
		aiGenerateBtn.add_theme_font_size_override("font_size", 9)
		aiGenerateBtn.text = "⚡ IV. SZACHOWNICA AI + ZADANIA"

	if not aiGenerateBtn.pressed.is_connected(_on_ai_generate_btn_pressed):
		aiGenerateBtn.pressed.connect(_on_ai_generate_btn_pressed)
	if not aiGenerateBtn.mouse_entered.is_connected(func(): _preview_mechanic_profile(4)):
		aiGenerateBtn.mouse_entered.connect(func(): _preview_mechanic_profile(4))
	if not aiGenerateBtn.focus_entered.is_connected(func(): _preview_mechanic_profile(4)):
		aiGenerateBtn.focus_entered.connect(func(): _preview_mechanic_profile(4))

	_preview_mechanic_profile(1)

func _on_ai_generate_btn_pressed() -> void:
	var new_seed: int = int(Time.get_unix_time_from_system()) + randi() % 10000
	_startLevelProfile(4, new_seed)

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
	if current_language == "en":
		aiContractBtn.text = "📜 AI CONTRACT: %s" % Events.ai_director.get_contract_name()
	else:
		aiContractBtn.text = "📜 KONTRAKT AI: %s" % Events.ai_director.get_contract_name()

func _on_play_btn_pressed() -> void:
	# Puszcza kolejny nieukończony poziom.
	# Jak wszystkie poziomy mają ukończony dany kontrakt (po 1 gwieździe), zmienia kontrakt na kolejny.
	# Jak wszystkie poziomy są ukończone na maksa (każdy ma 3 gwiazdki), puszcza szachownicę AI.
	for contract_idx in [0, 1, 2]:
		for lvl_id in [1, 2, 3]:
			var is_done: bool = Events.is_level_contract_completed(lvl_id, contract_idx) if is_instance_valid(Events) else false
			if not is_done:
				if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
					Events.ai_director.set_contract_mode(contract_idx as AdaptiveAIDirector.ContractMode)
					_update_contract_btn_text()
				_startLevelProfile(lvl_id)
				return

	# Wszystkie 3 poziomy mają komplet 3 gwiazdek -> puszczamy szachownicę AI
	_on_ai_generate_btn_pressed()

func _preview_mechanic_profile(profile_id: int) -> void:
	if not mechanicInfoLabel:
		return
	var meta: Dictionary = LevelGenerator.get_profile_metadata(profile_id)
	var best_t: float = Events.get_level_best_time(profile_id) if is_instance_valid(Events) else -1.0
	var time_str: String
	if current_language == "en":
		time_str = " | Record: %02d:%02d.%d" % [int(best_t) / 60, int(best_t) % 60, int((best_t - int(best_t)) * 10)] if best_t >= 0.0 else " | Collect all Jewels in time!"
	else:
		time_str = " | Rekord: %02d:%02d.%d" % [int(best_t) / 60, int(best_t) % 60, int((best_t - int(best_t)) * 10)] if best_t >= 0.0 else " | Zbierz wszystkie Jewele na czas!"

	var title: String = String(meta.get("title", ""))
	var subtitle: String = String(meta.get("subtitle", ""))
	var desc: String = String(meta.get("description", ""))
	if current_language == "en":
		match profile_id:
			1:
				title = "I. MOVEMENT SYNERGY (FLOW)"
				subtitle = "Balance: Climb + Dash + Double Jump"
				desc = "A balanced course combining climbing shafts, low tunnels, and chasms. Ideal for learning stamina rotation."
			2:
				title = "II. VERTICAL PEAKS (VERTICALITY)"
				subtitle = "Dominance: Wall Climb & Jump"
				desc = "Vertical shafts with strict climb windows and micro-ledges. Learn wall jump chaining without stamina burnout."
			3:
				title = "III. SPEED HYPERDRIVE (VELOCITY)"
				subtitle = "Dominance: Air Dash & Speed"
				desc = "Long horizontal sections requiring consecutive dashes and aerial trick recoveries."
			_:
				title = "AI ADAPTIVE RUN"
				subtitle = "Dynamic Profile"
				desc = "Custom generated challenge tailored to your playstyle."

	mechanicInfoLabel.text = "%s: %s%s\n%s" % [
		title,
		subtitle,
		time_str,
		desc
	]
	if dnaRadarLabel:
		var dna: Dictionary = meta.get("dna", {"wall_climb": 33, "dash": 33, "double_jump": 34})
		var ch_info: String = "None" if current_language == "en" else "Brak"
		if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
			var reqs: Dictionary = Events.portal_sync.get_aggregated_challenge_requirements()
			var names: Array = reqs.get("active_challenge_names", [])
			if not names.is_empty():
				var min_jewels_str: String = " [min %d Jewels]" if current_language == "en" else " [min %d Jeweli]"
				ch_info = ", ".join(names) + (min_jewels_str % int(reqs.get("min_jewels", 0)))
		if current_language == "en":
			dnaRadarLabel.text = "DNA RADAR: Wall Climb %d%% | Dash %d%% | Jumps %d%%   |   PORTAL QUESTS: %s" % [
				int(dna.get("wall_climb", 33)),
				int(dna.get("dash", 33)),
				int(dna.get("double_jump", 34)),
				ch_info
			]
		else:
			dnaRadarLabel.text = "RADAR DNA: Wspinaczka %d%% | Dash %d%% | Skoki %d%%   |   ZADANIA Z PORTALU: %s" % [
				int(dna.get("wall_climb", 33)),
				int(dna.get("dash", 33)),
				int(dna.get("double_jump", 34)),
				ch_info
			]

func _find_in_settings(child_path: String) -> Node:
	if not setView:
		return null
	var direct = setView.get_node_or_null(child_path)
	if direct:
		return direct
	var in_panels = setView.get_node_or_null("Panels/" + child_path)
	if in_panels:
		return in_panels
	for cat in ["AudioPanel", "GraphicsPanel", "ControlsPanel", "LanguagePanel"]:
		var p_node = setView.get_node_or_null("Panels/" + cat + "/" + child_path)
		if p_node:
			return p_node
	var fname = child_path.get_file()
	if fname == "Label" or fname == "Value":
		return null
	return setView.find_child(fname, true, false)

func _populate_display_mode_opt(opt: OptionButton) -> void:
	opt.clear()
	if current_language == "en":
		opt.add_item("Fullscreen")
		opt.add_item("Windowed")
		opt.add_item("Borderless Window")
	else:
		opt.add_item("Pełny ekran (Fullscreen)")
		opt.add_item("Okno (Windowed)")
		opt.add_item("Okno bez ramek (Borderless)")
	
	var cur_mode = DisplayServer.window_get_mode()
	var is_borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	if cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or cur_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		opt.selected = 0
	elif is_borderless:
		opt.selected = 2
	else:
		opt.selected = 1
		
	if not opt.item_selected.is_connected(_on_display_mode_selected):
		opt.item_selected.connect(_on_display_mode_selected)

func _on_display_mode_selected(idx: int) -> void:
	match idx:
		0:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		1:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)

func _populate_resolution_opt(opt: OptionButton) -> void:
	opt.clear()
	if current_language == "en":
		opt.add_item("1280 x 720 (HD)")
		opt.add_item("1920 x 1080 (FHD)")
		opt.add_item("640 x 360 (Native)")
	else:
		opt.add_item("1280 x 720 (HD)")
		opt.add_item("1920 x 1080 (FHD)")
		opt.add_item("640 x 360 (Natywna)")
		
	var cur_size = DisplayServer.window_get_size()
	if cur_size == Vector2i(1920, 1080):
		opt.selected = 1
	elif cur_size == Vector2i(640, 360):
		opt.selected = 2
	else:
		opt.selected = 0
		
	if not opt.item_selected.is_connected(_on_resolution_selected):
		opt.item_selected.connect(_on_resolution_selected)

func _on_resolution_selected(idx: int) -> void:
	var target_size := Vector2i(1280, 720)
	match idx:
		0: target_size = Vector2i(1280, 720)
		1: target_size = Vector2i(1920, 1080)
		2: target_size = Vector2i(640, 360)
		
	var cur_mode = DisplayServer.window_get_mode()
	if cur_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or cur_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var modeOpt: OptionButton = _find_in_settings("DisplayModeOpt") as OptionButton
		if modeOpt:
			modeOpt.selected = 1
			
	DisplayServer.window_set_size(target_size)
	var screen_id = DisplayServer.window_get_current_screen()
	var screen_size = DisplayServer.screen_get_size(screen_id)
	DisplayServer.window_set_position((screen_size - target_size) / 2)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		var res_str := "%dx%d" % [target_size.x, target_size.y]
		Events.portal_sync.profile_settings["resolution"] = res_str
		Events.portal_sync.queue_settings_sync({"resolution": res_str})

func _populate_fps_limit_opt(opt: OptionButton) -> void:
	opt.clear()
	if current_language == "en":
		opt.add_item("60 FPS")
		opt.add_item("120 FPS")
		opt.add_item("Uncapped")
	else:
		opt.add_item("60 FPS")
		opt.add_item("120 FPS")
		opt.add_item("Bez limitu (Uncapped)")
		
	if Engine.max_fps == 60:
		opt.selected = 0
	elif Engine.max_fps == 120:
		opt.selected = 1
	else:
		opt.selected = 2
		
	if not opt.item_selected.is_connected(_on_fps_limit_selected):
		opt.item_selected.connect(_on_fps_limit_selected)

func _on_fps_limit_selected(idx: int) -> void:
	match idx:
		0: Engine.max_fps = 60
		1: Engine.max_fps = 120
		2: Engine.max_fps = 0

func _on_vsync_toggled(on: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

func _on_subtitles_toggled(on: bool) -> void:
	subtitles_enabled = on

func _on_language_selected(idx: int) -> void:
	var code = "pl" if idx == 0 else "en"
	_apply_language(code)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["language"] = code
		Events.portal_sync.queue_settings_sync({"language": code})

func _on_master_slider_changed(v: float) -> void:
	var masterSlider: HSlider = _find_in_settings("MasterSlider") as HSlider
	var masterVal: Label = null
	if masterSlider:
		masterVal = masterSlider.get_parent().get_node_or_null("MasterValue") as Label
		if not masterVal:
			masterVal = masterSlider.get_parent().get_node_or_null("Value") as Label
	if not masterVal:
		masterVal = _find_in_settings("MasterValue") as Label
	if masterVal:
		masterVal.text = "%d%%" % int(v)
	_set_bus_volume_percent("Master", v)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["master_volume"] = v

func _on_music_slider_changed(v: float) -> void:
	var musicSlider: HSlider = _find_in_settings("MusicSlider") as HSlider
	var musicVal: Label = null
	if musicSlider:
		musicVal = musicSlider.get_parent().get_node_or_null("MusicValue") as Label
		if not musicVal:
			musicVal = musicSlider.get_parent().get_node_or_null("Value") as Label
	if not musicVal:
		musicVal = _find_in_settings("MusicValue") as Label
	if musicVal:
		musicVal.text = "%d%%" % int(v)
	_set_bus_volume_percent("MusicMenu", v)
	_set_bus_volume_percent("Music", v)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["music_volume"] = v
		Events.portal_sync.cosmetics_state["music_volume"] = v / 100.0
		Events.portal_sync.queue_settings_sync({"music_volume": int(round(v))})

func _on_level_music_slider_changed(v: float) -> void:
	var levelMusicSlider: HSlider = _find_in_settings("LevelMusicSlider") as HSlider
	var levelMusicVal: Label = null
	if levelMusicSlider:
		levelMusicVal = levelMusicSlider.get_parent().get_node_or_null("LevelMusicValue") as Label
		if not levelMusicVal:
			levelMusicVal = levelMusicSlider.get_parent().get_node_or_null("Value") as Label
	if not levelMusicVal:
		levelMusicVal = _find_in_settings("LevelMusicValue") as Label
	if levelMusicVal:
		levelMusicVal.text = "%d%%" % int(v)
	_set_bus_volume_percent("MusicLevel", v)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["level_music_volume"] = v
		Events.portal_sync.queue_settings_sync({"level_music_volume": int(round(v))})

func _on_sfx_slider_changed(v: float) -> void:
	var sfxSlider: HSlider = _find_in_settings("SfxSlider") as HSlider
	var sfxVal: Label = null
	if sfxSlider:
		sfxVal = sfxSlider.get_parent().get_node_or_null("SfxValue") as Label
		if not sfxVal:
			sfxVal = sfxSlider.get_parent().get_node_or_null("Value") as Label
	if not sfxVal:
		sfxVal = _find_in_settings("SfxValue") as Label
	if sfxVal:
		sfxVal.text = "%d%%" % int(v)
	_set_bus_volume_percent("SFX", v)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["sfx_volume"] = v
		Events.portal_sync.cosmetics_state["sfx_volume"] = v / 100.0
		Events.portal_sync.queue_settings_sync({"sfx_volume": int(round(v))})
	_play_menu_sfx()

func _on_mute_check_toggled(toggled_on: bool) -> void:
	var m_idx = AudioServer.get_bus_index("Master")
	if m_idx != -1:
		AudioServer.set_bus_mute(m_idx, toggled_on)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.profile_settings["is_muted"] = toggled_on

func _setup_settings_mockups() -> void:
	_ensure_audio_buses()
	
	var modeOpt: OptionButton = _find_in_settings("DisplayModeOpt") as OptionButton
	if modeOpt:
		_populate_display_mode_opt(modeOpt)
		
	var resOpt: OptionButton = _find_in_settings("ResolutionOpt") as OptionButton
	if resOpt:
		_populate_resolution_opt(resOpt)
		
	var vsyncCheck: CheckBox = _find_in_settings("VsyncCheck") as CheckBox
	if vsyncCheck:
		vsyncCheck.button_pressed = (DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)
		if not vsyncCheck.toggled.is_connected(_on_vsync_toggled):
			vsyncCheck.toggled.connect(_on_vsync_toggled)

	var fpsOpt: OptionButton = _find_in_settings("FpsLimitOpt") as OptionButton
	if fpsOpt:
		_populate_fps_limit_opt(fpsOpt)
		
	var langOpt: OptionButton = _find_in_settings("LanguageOpt") as OptionButton
	if langOpt:
		langOpt.clear()
		langOpt.add_item("Polski (PL)")
		langOpt.add_item("English (EN)")
		langOpt.selected = 0 if current_language == "pl" else 1
		if not langOpt.item_selected.is_connected(_on_language_selected):
			langOpt.item_selected.connect(_on_language_selected)

	var subsCheck: CheckBox = _find_in_settings("SubtitlesCheck") as CheckBox
	if subsCheck:
		subsCheck.button_pressed = subtitles_enabled
		if not subsCheck.toggled.is_connected(_on_subtitles_toggled):
			subsCheck.toggled.connect(_on_subtitles_toggled)
		
	# --- Rzeczywista regulacja głośności szyn AudioServer ---
	var masterSlider: HSlider = _find_in_settings("MasterSlider") as HSlider
	var masterVal: Label = null
	if masterSlider:
		masterVal = masterSlider.get_parent().get_node_or_null("MasterValue") as Label
		if not masterVal:
			masterVal = masterSlider.get_parent().get_node_or_null("Value") as Label
	if not masterVal:
		masterVal = _find_in_settings("MasterValue") as Label
		
	if masterSlider:
		var m_idx = AudioServer.get_bus_index("Master")
		if m_idx != -1:
			var cur_db = AudioServer.get_bus_volume_db(m_idx)
			var is_muted = AudioServer.is_bus_mute(m_idx)
			masterSlider.value = 0.0 if is_muted else clampf(db_to_linear(cur_db) * 100.0, 0.0, 100.0)
		if masterVal:
			masterVal.text = "%d%%" % int(masterSlider.value)
		if not masterSlider.value_changed.is_connected(_on_master_slider_changed):
			masterSlider.value_changed.connect(_on_master_slider_changed)
		
	var musicSlider: HSlider = _find_in_settings("MusicSlider") as HSlider
	var musicVal: Label = null
	if musicSlider:
		musicVal = musicSlider.get_parent().get_node_or_null("MusicValue") as Label
		if not musicVal:
			musicVal = musicSlider.get_parent().get_node_or_null("Value") as Label
	if not musicVal:
		musicVal = _find_in_settings("MusicValue") as Label
		
	if musicSlider:
		var mus_idx = AudioServer.get_bus_index("MusicMenu")
		if mus_idx == -1:
			mus_idx = AudioServer.get_bus_index("Music")
		if mus_idx != -1:
			var cur_db = AudioServer.get_bus_volume_db(mus_idx)
			var is_muted = AudioServer.is_bus_mute(mus_idx)
			musicSlider.value = 0.0 if is_muted else clampf(db_to_linear(cur_db) * 100.0, 0.0, 100.0)
		if musicVal:
			musicVal.text = "%d%%" % int(musicSlider.value)
		if not musicSlider.value_changed.is_connected(_on_music_slider_changed):
			musicSlider.value_changed.connect(_on_music_slider_changed)
		
	var levelMusicSlider: HSlider = _find_in_settings("LevelMusicSlider") as HSlider
	var levelMusicVal: Label = null
	if levelMusicSlider:
		levelMusicVal = levelMusicSlider.get_parent().get_node_or_null("LevelMusicValue") as Label
		if not levelMusicVal:
			levelMusicVal = levelMusicSlider.get_parent().get_node_or_null("Value") as Label
	if not levelMusicVal:
		levelMusicVal = _find_in_settings("LevelMusicValue") as Label
		
	if levelMusicSlider:
		var lvl_idx = AudioServer.get_bus_index("MusicLevel")
		if lvl_idx != -1:
			var cur_db = AudioServer.get_bus_volume_db(lvl_idx)
			var is_muted = AudioServer.is_bus_mute(lvl_idx)
			levelMusicSlider.value = 0.0 if is_muted else clampf(db_to_linear(cur_db) * 100.0, 0.0, 100.0)
		if levelMusicVal:
			levelMusicVal.text = "%d%%" % int(levelMusicSlider.value)
		if not levelMusicSlider.value_changed.is_connected(_on_level_music_slider_changed):
			levelMusicSlider.value_changed.connect(_on_level_music_slider_changed)
		
	var sfxSlider: HSlider = _find_in_settings("SfxSlider") as HSlider
	var sfxVal: Label = null
	if sfxSlider:
		sfxVal = sfxSlider.get_parent().get_node_or_null("SfxValue") as Label
		if not sfxVal:
			sfxVal = sfxSlider.get_parent().get_node_or_null("Value") as Label
	if not sfxVal:
		sfxVal = _find_in_settings("SfxValue") as Label
		
	if sfxSlider:
		var sfx_idx = AudioServer.get_bus_index("SFX")
		if sfx_idx != -1:
			var cur_db = AudioServer.get_bus_volume_db(sfx_idx)
			var is_muted = AudioServer.is_bus_mute(sfx_idx)
			sfxSlider.value = 0.0 if is_muted else clampf(db_to_linear(cur_db) * 100.0, 0.0, 100.0)
		if sfxVal:
			sfxVal.text = "%d%%" % int(sfxSlider.value)
		if not sfxSlider.value_changed.is_connected(_on_sfx_slider_changed):
			sfxSlider.value_changed.connect(_on_sfx_slider_changed)
		
	var muteCheck: CheckBox = _find_in_settings("MuteCheck") as CheckBox
	if muteCheck:
		var m_idx = AudioServer.get_bus_index("Master")
		if m_idx != -1:
			muteCheck.button_pressed = AudioServer.is_bus_mute(m_idx)
		if not muteCheck.toggled.is_connected(_on_mute_check_toggled):
			muteCheck.toggled.connect(_on_mute_check_toggled)

	# Usprawnienie nawigacji strzałkami w Settings
	if tabAudioBtn and tabGraphicsBtn and tabControlsBtn and tabLanguageBtn:
		tabAudioBtn.focus_neighbor_left = tabLanguageBtn.get_path()
		tabAudioBtn.focus_neighbor_right = tabGraphicsBtn.get_path()
		tabGraphicsBtn.focus_neighbor_left = tabAudioBtn.get_path()
		tabGraphicsBtn.focus_neighbor_right = tabControlsBtn.get_path()
		tabControlsBtn.focus_neighbor_left = tabGraphicsBtn.get_path()
		tabControlsBtn.focus_neighbor_right = tabLanguageBtn.get_path()
		tabLanguageBtn.focus_neighbor_left = tabControlsBtn.get_path()
		tabLanguageBtn.focus_neighbor_right = tabAudioBtn.get_path()
		if masterSlider:
			tabAudioBtn.focus_neighbor_bottom = masterSlider.get_path()
		if modeOpt:
			tabGraphicsBtn.focus_neighbor_bottom = modeOpt.get_path()
		if settingsBackBtn:
			tabControlsBtn.focus_neighbor_bottom = settingsBackBtn.get_path()
		if langOpt:
			tabLanguageBtn.focus_neighbor_bottom = langOpt.get_path()

	if masterSlider and tabAudioBtn:
		masterSlider.focus_neighbor_top = tabAudioBtn.get_path()
		if musicSlider:
			masterSlider.focus_neighbor_bottom = musicSlider.get_path()
	if musicSlider and masterSlider:
		musicSlider.focus_neighbor_top = masterSlider.get_path()
		if levelMusicSlider:
			musicSlider.focus_neighbor_bottom = levelMusicSlider.get_path()
	if levelMusicSlider and musicSlider:
		levelMusicSlider.focus_neighbor_top = musicSlider.get_path()
		if sfxSlider:
			levelMusicSlider.focus_neighbor_bottom = sfxSlider.get_path()
	if sfxSlider and levelMusicSlider:
		sfxSlider.focus_neighbor_top = levelMusicSlider.get_path()
		if muteCheck:
			sfxSlider.focus_neighbor_bottom = muteCheck.get_path()
	if muteCheck and sfxSlider:
		muteCheck.focus_neighbor_top = sfxSlider.get_path()
		if settingsBackBtn:
			muteCheck.focus_neighbor_bottom = settingsBackBtn.get_path()
	if settingsBackBtn and muteCheck:
		settingsBackBtn.focus_neighbor_top = muteCheck.get_path()

func _apply_language(lang_code: String) -> void:
	current_language = lang_code
	TranslationServer.set_locale(lang_code)
	if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		Events.portal_sync.cosmetics_state["language"] = lang_code
	
	tabNames = ["AUDIO", "GRAPHICS", "CONTROLS", "LANGUAGE"] if current_language == "en" else ["MUZYKA", "GRAFIKA", "STEROWANIE", "JĘZYK"]
	
	# Update Audio Panel labels
	var masterLabel = _find_in_settings("AudioPanel/MasterBox/Label") as Label
	if masterLabel: masterLabel.text = "Master Volume:" if current_language == "en" else "Głośność ogólna:"
	var musicLabel = _find_in_settings("AudioPanel/MusicBox/Label") as Label
	if musicLabel: musicLabel.text = "Menu Music:" if current_language == "en" else "Muzyka w menu:"
	var levelMusicLabel = _find_in_settings("AudioPanel/LevelMusicBox/Label") as Label
	if levelMusicLabel: levelMusicLabel.text = "Level Music:" if current_language == "en" else "Muzyka w poziomie:"
	var sfxLabel = _find_in_settings("AudioPanel/SfxBox/Label") as Label
	if sfxLabel: sfxLabel.text = "Sound Effects (SFX):" if current_language == "en" else "Efekty dźwiękowe (SFX):"
	var muteCheck = _find_in_settings("AudioPanel/MuteCheck") as CheckBox
	if muteCheck: muteCheck.text = "Mute All Sounds" if current_language == "en" else "Wycisz wszystkie dźwięki (Mute All)"
	
	# Update Graphics Panel labels and options
	var modeLabel = _find_in_settings("GraphicsPanel/ModeBox/Label") as Label
	if modeLabel: modeLabel.text = "Display Mode:" if current_language == "en" else "Tryb wyświetlania:"
	var modeOpt = _find_in_settings("DisplayModeOpt") as OptionButton
	if modeOpt:
		var saved_mode = modeOpt.selected
		_populate_display_mode_opt(modeOpt)
		if saved_mode >= 0 and saved_mode < modeOpt.item_count:
			modeOpt.selected = saved_mode
			
	var resLabel = _find_in_settings("GraphicsPanel/ResBox/Label") as Label
	if resLabel: resLabel.text = "Window Resolution:" if current_language == "en" else "Rozdzielczość okna:"
	var resOpt = _find_in_settings("ResolutionOpt") as OptionButton
	if resOpt:
		var saved_res = resOpt.selected
		_populate_resolution_opt(resOpt)
		if saved_res >= 0 and saved_res < resOpt.item_count:
			resOpt.selected = saved_res
			
	var vsyncCheck = _find_in_settings("GraphicsPanel/VsyncCheck") as CheckBox
	if vsyncCheck: vsyncCheck.text = "Vertical Sync (V-Sync)" if current_language == "en" else "Synchronizacja pionowa (V-Sync)"
	
	var fpsLabel = _find_in_settings("GraphicsPanel/FpsBox/Label") as Label
	if fpsLabel: fpsLabel.text = "Frame Rate Limit (FPS):" if current_language == "en" else "Limit klatek (FPS):"
	var fpsOpt = _find_in_settings("FpsLimitOpt") as OptionButton
	if fpsOpt:
		var saved_fps = fpsOpt.selected
		_populate_fps_limit_opt(fpsOpt)
		if saved_fps >= 0 and saved_fps < fpsOpt.item_count:
			fpsOpt.selected = saved_fps
			
	# Update Controls Panel labels
	var ctrlGrid = _find_in_settings("ControlsPanel/Grid")
	if ctrlGrid:
		var a1 = ctrlGrid.get_node_or_null("Action1") as Label
		if a1: a1.text = "Horizontal Movement (Left / Right):" if current_language == "en" else "Ruch poziomy (Lewo / Prawo):"
		var k1 = ctrlGrid.get_node_or_null("Key1") as Label
		if k1: k1.text = "A / D  (or Arrows)" if current_language == "en" else "A / D  (lub Strzałki)"
		var a2 = ctrlGrid.get_node_or_null("Action2") as Label
		if a2: a2.text = "Jump / Double Jump:" if current_language == "en" else "Skok / Podwójny skok:"
		var k2 = ctrlGrid.get_node_or_null("Key2") as Label
		if k2: k2.text = "Space / W" if current_language == "en" else "Spacja / W"
		var a3 = ctrlGrid.get_node_or_null("Action3") as Label
		if a3: a3.text = "Dash:" if current_language == "en" else "Zryw (Dash):"
		var a4 = ctrlGrid.get_node_or_null("Action4") as Label
		if a4: a4.text = "Crouch / Slide:" if current_language == "en" else "Kucanie / Wślizg:"
		var k4 = ctrlGrid.get_node_or_null("Key4") as Label
		if k4: k4.text = "S / Down Arrow" if current_language == "en" else "S / Strzałka w dół"
		var a5 = ctrlGrid.get_node_or_null("Action5") as Label
		if a5: a5.text = "Wall Climb:" if current_language == "en" else "Wspinaczka (przy ścianie):"
		var a6 = ctrlGrid.get_node_or_null("Action6") as Label
		if a6: a6.text = "Mid-air Trick (Charges stamina):" if current_language == "en" else "Trick (w locie - ładuje staminę):"
		var k6 = ctrlGrid.get_node_or_null("Key6") as Label
		if k6: k6.text = "C (Hold in mid-air)" if current_language == "en" else "C (przytrzymaj w locie)"
		var a7 = ctrlGrid.get_node_or_null("Action7") as Label
		if a7: a7.text = "Pause:" if current_language == "en" else "Pauza:"
		
	# Update Language Panel labels
	var langLabel = _find_in_settings("LanguagePanel/LangBox/Label") as Label
	if langLabel: langLabel.text = "Game Language:" if current_language == "en" else "Język gry (Language):"
	var subsCheck = _find_in_settings("LanguagePanel/SubtitlesCheck") as CheckBox
	if subsCheck: subsCheck.text = "Display Subtitles" if current_language == "en" else "Wyświetlaj napisy dialogowe (Subtitles)"
	
	# Update LanguageOpt selection
	var langOpt = _find_in_settings("LanguageOpt") as OptionButton
	if langOpt:
		langOpt.selected = 0 if current_language == "pl" else 1
	
	# Update Level Select texts
	var lvl1BadgeText = get_node_or_null("LevelSelectView/Lvl1Btn/CompletedBadge/BadgeText") as Label
	if lvl1BadgeText: lvl1BadgeText.text = "✔ COMPLETED" if current_language == "en" else "✔ UKOŃCZONY"
	var aiGenBtn = get_node_or_null("LevelSelectView/AIGenerateBtn") as Button
	if aiGenBtn: aiGenBtn.text = "⚡ IV. AI CHESSBOARD + QUESTS" if current_language == "en" else "⚡ IV. SZACHOWNICA AI + ZADANIA"
	_update_contract_btn_text()
	var prof_id = Events.selected_level_profile if is_instance_valid(Events) else 1
	_preview_mechanic_profile(prof_id)
	
	# Update Skins, Profile, Zadania, Daily Reward views
	_refresh_skin_select_ui()
	_refresh_profile_screen_ui()
	_refresh_zadania_ui()
	_refresh_daily_reward_ui()

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
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(1.0, 0.88, 0.35, 0.18)
				sb.border_color = Color(1.0, 0.88, 0.35, 0.95)
				sb.set_border_width_all(2)
				sb.set_corner_radius_all(3)
				b.add_theme_stylebox_override("normal", sb)
			else:
				var empty := StyleBoxEmpty.new()
				b.add_theme_stylebox_override("normal", empty)
				
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
			elif event.keycode == KEY_LEFT:
				var focused = get_viewport().gui_get_focus_owner()
				if not (focused is Slider or focused is OptionButton):
					_switchSettingsTab((currentSettingsTab - 1 + 4) % 4)
					get_viewport().set_input_as_handled()
					return
			elif event.keycode == KEY_RIGHT:
				var focused = get_viewport().gui_get_focus_owner()
				if not (focused is Slider or focused is OptionButton):
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

	if targetView in [homeView, lvlView, profileSettingsView, skinSelectView, profileView, zadaniaView]:
		if is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
			Events.portal_sync.sync_if_needed(2.0)

func _ensure_card_badge_and_lock(btn: Button, lvl_num: int) -> Dictionary:
	if not btn:
		return {}

	var stars_count: int = Events.get_level_stars(lvl_num) if is_instance_valid(Events) else 0

	var badge = btn.get_node_or_null("CompletedBadge") as Control
	if not badge:
		badge = ColorRect.new()
		badge.name = "CompletedBadge"
		badge.layout_mode = 1
		badge.anchors_preset = Control.PRESET_BOTTOM_WIDE
		badge.anchor_top = 1.0
		badge.anchor_right = 1.0
		badge.anchor_bottom = 1.0
		badge.offset_top = -24.0
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.color = Color(0.1, 0.5, 0.2, 0.85)
		
		var b_text = Label.new()
		b_text.name = "BadgeText"
		b_text.layout_mode = 1
		b_text.anchors_preset = Control.PRESET_FULL_RECT
		b_text.anchor_right = 1.0
		b_text.anchor_bottom = 1.0
		b_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b_text.add_theme_font_size_override("font_size", 12)
		b_text.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9, 1.0))
		b_text.text = "✔ COMPLETED" if current_language == "en" else "✔ UKOŃCZONY"
		badge.add_child(b_text)
		btn.add_child(badge)
	else:
		var b_text = badge.get_node_or_null("BadgeText") as Label
		if b_text:
			b_text.text = "✔ COMPLETED" if current_language == "en" else "✔ UKOŃCZONY"

	# Usuń stary pojedynczy CheckmarkIcon jeśli istnieje
	var old_star = btn.get_node_or_null("CheckmarkIcon")
	if old_star:
		old_star.queue_free()

	# Kontener z 3 gwiazdkami - 1 gwiazdka za każdy kontrakt AI Director
	var stars_box = btn.get_node_or_null("StarsBox") as HBoxContainer
	if not stars_box:
		stars_box = HBoxContainer.new()
		stars_box.name = "StarsBox"
		stars_box.layout_mode = 1
		stars_box.anchors_preset = Control.PRESET_TOP_RIGHT
		stars_box.anchor_left = 1.0
		stars_box.anchor_right = 1.0
		stars_box.offset_left = -78.0
		stars_box.offset_top = 6.0
		stars_box.offset_right = -8.0
		stars_box.offset_bottom = 28.0
		stars_box.alignment = BoxContainer.ALIGNMENT_END
		stars_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars_box.add_theme_constant_override("separation", 2)
		for i in range(3):
			var s_lbl = Label.new()
			s_lbl.name = "Star%d" % i
			s_lbl.text = "★"
			s_lbl.add_theme_font_size_override("font_size", 16)
			stars_box.add_child(s_lbl)
		btn.add_child(stars_box)

	# Odświeżenie kolorów 3 gwiazdek
	for i in range(3):
		var s_lbl = stars_box.get_node_or_null("Star%d" % i) as Label
		if s_lbl:
			var has_star: bool = Events.is_level_contract_completed(lvl_num, i) if is_instance_valid(Events) else false
			if has_star:
				s_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
			else:
				s_lbl.add_theme_color_override("font_color", Color(0.35, 0.40, 0.50, 0.4))

	var lock = btn.get_node_or_null("LockOverlay") as Control
	if not lock:
		lock = ColorRect.new()
		lock.name = "LockOverlay"
		lock.layout_mode = 1
		lock.anchors_preset = Control.PRESET_FULL_RECT
		lock.anchor_right = 1.0
		lock.anchor_bottom = 1.0
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.color = Color(0.06, 0.08, 0.12, 0.85)

		var l_text = Label.new()
		l_text.name = "LockText"
		l_text.layout_mode = 1
		l_text.anchors_preset = Control.PRESET_FULL_RECT
		l_text.anchor_right = 1.0
		l_text.anchor_bottom = 1.0
		l_text.offset_bottom = -14.0
		l_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l_text.add_theme_font_size_override("font_size", 12)
		l_text.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35, 1.0))
		l_text.text = "🔒 LOCKED" if current_language == "en" else "🔒 ZABLOKOWANY"
		lock.add_child(l_text)

		var l_sub = Label.new()
		l_sub.name = "LockSubtext"
		l_sub.layout_mode = 1
		l_sub.anchors_preset = Control.PRESET_FULL_RECT
		l_sub.anchor_right = 1.0
		l_sub.anchor_bottom = 1.0
		l_sub.offset_top = 22.0
		l_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l_sub.add_theme_font_size_override("font_size", 9)
		l_sub.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.8))
		if lvl_num > 1:
			l_sub.text = "Clear Level %d to unlock" % (lvl_num - 1) if current_language == "en" else "Ukończ Poziom %d" % (lvl_num - 1)
		lock.add_child(l_sub)
		btn.add_child(lock)
	else:
		var l_text = lock.get_node_or_null("LockText") as Label
		if l_text:
			l_text.text = "🔒 LOCKED" if current_language == "en" else "🔒 ZABLOKOWANY"
		var l_sub = lock.get_node_or_null("LockSubtext") as Label
		if l_sub and lvl_num > 1:
			l_sub.text = "Clear Level %d to unlock" % (lvl_num - 1) if current_language == "en" else "Ukończ Poziom %d" % (lvl_num - 1)

	return {"badge": badge, "stars_box": stars_box, "lock": lock}

func _update_level_select() -> void:
	var lvl1_done: bool = Events.is_level_completed(1) if is_instance_valid(Events) else false
	var lvl2_done: bool = Events.is_level_completed(2) if is_instance_valid(Events) else false
	var lvl3_done: bool = Events.is_level_completed(3) if is_instance_valid(Events) else false

	# Poziom 1: zawsze odblokowany
	var card1 = _ensure_card_badge_and_lock(lvl1Btn, 1)
	if not card1.is_empty():
		card1["lock"].visible = false
		card1["badge"].visible = lvl1_done
		card1["stars_box"].visible = lvl1_done
		lvl1Btn.disabled = false
		lvl1Btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# Poziom 2: odblokowany dopiero po ukończeniu poziomu 1
	var lvl2_unlocked: bool = lvl1_done
	var card2 = _ensure_card_badge_and_lock(lvl2Btn, 2)
	if not card2.is_empty():
		card2["lock"].visible = not lvl2_unlocked
		card2["badge"].visible = lvl2_unlocked and lvl2_done
		card2["stars_box"].visible = lvl2_unlocked and lvl2_done
		lvl2Btn.disabled = not lvl2_unlocked
		lvl2Btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if lvl2_unlocked else Control.CURSOR_FORBIDDEN

	# Poziom 3: odblokowany dopiero po ukończeniu poziomu 2
	var lvl3_unlocked: bool = lvl2_done
	var card3 = _ensure_card_badge_and_lock(lvl3Btn, 3)
	if not card3.is_empty():
		card3["lock"].visible = not lvl3_unlocked
		card3["badge"].visible = lvl3_unlocked and lvl3_done
		card3["stars_box"].visible = lvl3_unlocked and lvl3_done
		lvl3Btn.disabled = not lvl3_unlocked
		lvl3Btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if lvl3_unlocked else Control.CURSOR_FORBIDDEN

func _startLevelProfile(profile_id: int, custom_seed: int = 0) -> void:
	if profile_id == 2 and not (Events.is_level_completed(1) if is_instance_valid(Events) else false):
		_preview_mechanic_profile(2)
		return
	if profile_id == 3 and not (Events.is_level_completed(2) if is_instance_valid(Events) else false):
		_preview_mechanic_profile(3)
		return
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
