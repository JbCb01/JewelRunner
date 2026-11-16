class_name SkinManager
extends RefCounted

## Zarządca skórek gracza (SkinManager)
## Odpowiada za mapowanie wybranych w menu skórek na odpowiednie podfoldery
## w assets/sprites/player/ oraz podmianę zasobów SpriteFrames postaci.

const SKIN_DATA: Dictionary = {
	"base": {
		"id": 0,
		"key": "base",
		"name": "Klasyczna Stelly",
		"aliases": ["Klasyczna Stelly", "Skórka podstawowa", "Podstawowa", "base", "default"],
		"frames_path": "res://scenes/player/player_sprite_frames.tres",
		"display_name": "Klasyczna Stelly",
		"desc": "Klasyczny fioletowy strój bohaterki.",
		"color_name": "Fioletowy",
		"color_hex": "#6A3FB5"
	},
	"noir": {
		"id": 1,
		"key": "noir",
		"name": "Noir Stelly",
		"aliases": ["Noir Stelly", "NoirStelly", "noir", "Monochrom"],
		"frames_path": "res://scenes/player/skins/noir_stelly.tres",
		"display_name": "Noir Stelly",
		"desc": "Elegancki czarno-biały styl film noir.",
		"color_name": "Monochrom",
		"color_hex": "#505050"
	},
	"office": {
		"id": 2,
		"key": "office",
		"name": "Office Stelly",
		"aliases": ["Office Stelly", "OfficeStelly", "office", "Biznesowy"],
		"frames_path": "res://scenes/player/skins/office_stelly.tres",
		"display_name": "Office Stelly",
		"desc": "Formalny garnitur korporacyjny.",
		"color_name": "Granatowy",
		"color_hex": "#2B3A4A"
	},
	"2077": {
		"id": 3,
		"key": "2077",
		"name": "2077 Stelly",
		"aliases": ["2077 Stelly", "2077Stelly", "Cyber 2077", "Cyber Stelly", "2077", "cyber"],
		"frames_path": "res://scenes/player/skins/2077_stelly.tres",
		"display_name": "2077 Stelly",
		"desc": "Futurystyczny kombinezon z neonowymi akcentami.",
		"color_name": "Cyjan",
		"color_hex": "#2CE0D2"
	},
	"promissed": {
		"id": 4,
		"key": "promissed",
		"name": "Promissed Stelly",
		"aliases": ["Promissed Stelly", "PromissedStelly", "promissed", "Aqua Stelly", "Głębia Oceanu"],
		"frames_path": "res://scenes/player/skins/promissed_stelly.tres",
		"display_name": "Promissed Stelly",
		"desc": "Morski pancerz strażnika obietnicy.",
		"color_name": "Morski",
		"color_hex": "#00B4D8"
	},
	"retro": {
		"id": 5,
		"key": "retro",
		"name": "Retro Stelly",
		"aliases": ["Retro Stelly", "RetroStelly", "retro", "Bursztynowa Stelly", "Złoty biegacz"],
		"frames_path": "res://scenes/player/skins/retro_stelly.tres",
		"display_name": "Retro Stelly",
		"desc": "Ciepłe barwy vintage z brzoskwiniowym odcieniem.",
		"color_name": "Bursztynowy",
		"color_hex": "#F5A623"
	}
}

static var _cached_frames: Dictionary = {}

## Zwraca słownik informacyjny o skórce na podstawie ID (0..5), klucza lub nazwy.
static func get_skin_info(skin_identifier: Variant) -> Dictionary:
	if skin_identifier is int:
		var idx: int = int(skin_identifier)
		for k in SKIN_DATA.keys():
			if SKIN_DATA[k]["id"] == idx:
				return SKIN_DATA[k]
		return SKIN_DATA["base"]
		
	var s_name: String = String(skin_identifier).strip_edges()
	if s_name.is_empty():
		return SKIN_DATA["base"]
		
	var s_lower: String = s_name.to_lower()
	if SKIN_DATA.has(s_lower):
		return SKIN_DATA[s_lower]
		
	for k in SKIN_DATA.keys():
		var data: Dictionary = SKIN_DATA[k]
		if String(data["name"]).to_lower() == s_lower or String(data["display_name"]).to_lower() == s_lower:
			return data
		var aliases: Array = data.get("aliases", [])
		for a in aliases:
			if String(a).to_lower() == s_lower:
				return data
				
	return SKIN_DATA["base"]

## Zwraca unikalny klucz skórki ("base", "noir", "office", "2077", "promissed", "retro").
static func get_skin_key(skin_identifier: Variant) -> String:
	var info: Dictionary = get_skin_info(skin_identifier)
	return String(info.get("key", "base"))

## Zwraca instancję SpriteFrames dla podanej skórki, korzystając z pamięci podręcznej.
static func get_sprite_frames(skin_identifier: Variant) -> SpriteFrames:
	var info: Dictionary = get_skin_info(skin_identifier)
	var key: String = String(info.get("key", "base"))
	
	if _cached_frames.has(key) and is_instance_valid(_cached_frames[key]):
		return _cached_frames[key] as SpriteFrames
		
	var path: String = String(info.get("frames_path", "res://scenes/player/player_sprite_frames.tres"))
	var frames: SpriteFrames = null
	if ResourceLoader.exists(path):
		frames = ResourceLoader.load(path) as SpriteFrames
	
	if not frames:
		push_warning("SkinManager: Nie udało się załadować SpriteFrames z: %s, używam domyślnych." % path)
		frames = ResourceLoader.load("res://scenes/player/player_sprite_frames.tres") as SpriteFrames
		
	if frames:
		_cached_frames[key] = frames
		
	return frames

## Aplikuje wybraną skórkę bezpośrednio na postać gracza (PlayerController).
## Podmienia SpriteFrames w AnimatedSprite2D, resetuje self_modulate i wznawia animację.
static func apply_skin_to_player(player: Node, skin_identifier: Variant) -> bool:
	if not is_instance_valid(player):
		return false
		
	var anim_sprite: AnimatedSprite2D = player.get_node_or_null("Visuals/AnimatedSprite2D") as AnimatedSprite2D
	if not anim_sprite:
		return false
		
	var info: Dictionary = get_skin_info(skin_identifier)
	var frames: SpriteFrames = get_sprite_frames(info.get("key", "base"))
	if not frames:
		return false
		
	var cur_anim: StringName = anim_sprite.animation
	var cur_frame: int = anim_sprite.frame
	var was_playing: bool = anim_sprite.is_playing()
	
	anim_sprite.sprite_frames = frames
	anim_sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	if frames.has_animation(cur_anim):
		anim_sprite.animation = cur_anim
		var frame_count: int = frames.get_frame_count(cur_anim)
		anim_sprite.frame = clampi(cur_frame, 0, maxi(0, frame_count - 1))
		if was_playing:
			anim_sprite.play()
	else:
		anim_sprite.play(&"idle")
		
	player.set_meta("active_skin_key", String(info["key"]))
	player.set_meta("active_skin_name", String(info["name"]))
	player.set_meta("portal_active_skin", String(info["name"]))
	return true
