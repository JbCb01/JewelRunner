extends Control

@export_file("*.tscn") var arenaScenePath: String = "res://TestArena.tscn"

@onready var homeView: Control = get_node_or_null("HomeView")
@onready var lvlView: Control = get_node_or_null("LevelSelectView")
@onready var setView: Control = get_node_or_null("SettingsView")
@onready var creatorsView: Control = get_node_or_null("CreatorsView")
@onready var musicPlayer: AudioStreamPlayer = get_node_or_null("MusicPlayer")

@onready var playBtn: Button = get_node_or_null("HomeView/MenuBtns/PlayBtn")
@onready var lvlBtn: Button = get_node_or_null("HomeView/MenuBtns/LvlBtn")
@onready var setBtn: Button = get_node_or_null("HomeView/MenuBtns/SetBtn")
@onready var creatorsBtn: Button = get_node_or_null("HomeView/MenuBtns/CreatorsBtn")
@onready var exitBtn: Button = get_node_or_null("HomeView/MenuBtns/ExitBtn")

@onready var lvl1Btn: Button = get_node_or_null("LevelSelectView/Lvl1Btn")
@onready var lvl1CompletedBadge: Control = get_node_or_null("LevelSelectView/Lvl1Btn/CompletedBadge")
@onready var lvl1CheckmarkIcon: Control = get_node_or_null("LevelSelectView/Lvl1Btn/CheckmarkIcon")

# --- Kontroler zakładek Ustawień (Mockup) ---
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

func _ready() -> void:
	_showView(homeView)
	_update_level_select()
	_setup_settings_mockups()
	
	if playBtn: playBtn.pressed.connect(_startGame)
	if lvlBtn and lvlView: lvlBtn.pressed.connect(func(): _showView(lvlView))
	if setBtn and setView: setBtn.pressed.connect(func(): _showView(setView))
	if creatorsBtn and creatorsView: creatorsBtn.pressed.connect(func(): _showView(creatorsView))
	if exitBtn: exitBtn.pressed.connect(func(): get_tree().quit())
	
	if lvl1Btn: lvl1Btn.pressed.connect(_startGame)
	
	# Podpięcie nawigacji myszą w Ustawieniach
	if tabAudioBtn: tabAudioBtn.pressed.connect(func(): _switchSettingsTab(0))
	if tabGraphicsBtn: tabGraphicsBtn.pressed.connect(func(): _switchSettingsTab(1))
	if tabControlsBtn: tabControlsBtn.pressed.connect(func(): _switchSettingsTab(2))
	if tabLanguageBtn: tabLanguageBtn.pressed.connect(func(): _switchSettingsTab(3))
	if settingsBackBtn: settingsBackBtn.pressed.connect(func(): _showView(homeView))

func _setup_settings_mockups() -> void:
	# Wypełnienie mockupowych list rozwijanych (OptionButton)
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
		
	# Interaktywne aktualizowanie wartości suwaków w mockupie
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
