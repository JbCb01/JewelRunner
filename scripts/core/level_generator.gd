extends RefCounted
class_name ProceduralLevelGenerator

## Generator Poziomów AI z obsługą:
## 1. "Żywiołów Ruchu" (Trials of Flow: Synergia [Las], Ascent [Zima], Momentum [Jesień], Aether / Szachownica AI)
## 2. "Szachownicy Stylu Gracza" opartej o deterministyczny seed (AILevelComposer + walidator przechodności)
## 3. "Niestabilnych Klejnotów" (Cursed Jewels) dla Kontraktu AI
## 4. Zadań z Aplikacji Webowej (`min_jewels`, `max_time_s`, `focus_mechanics`)
## 5. Pełnego TileSetu z `res://assets/tilesett.png` / `res://assets/tileset_world.tres`, trampolin `!`, cieczy i AI wrogów

const HazardScript = preload("res://scripts/core/hazard_area.gd")
const CheckpointScript = preload("res://scripts/core/checkpoint.gd")
const TrampolineScript = preload("res://scripts/core/trampoline_pad.gd")
const AILevelComposer = preload("res://scripts/core/ai_level_composer.gd")
const JewelScene = preload("res://scenes/Jewel.tscn")
const EnemyScene = preload("res://scenes/enemies/enemy_mockup.tscn")
const DEFAULT_TILESET_PATH := "res://assets/tileset_world.tres"
const TILESET_PNG_PATH := "res://assets/tilesett.png"

enum MechanicProfile {
	SYNERGY_CLASSIC = 1,  ## I. SYNERGIA RUCHU (Las: balans wszystkich mechanik)
	VERTICAL_ASCENT = 2,  ## II. SEKTOR PIONOWY: ASCENT (Zima: Wall Climb & studnie Air Trick)
	HORIZON_IMPULSE = 3,  ## III. SEKTOR IMPULSU: MOMENTUM (Jesień: Tunele Slide -> kaniony lawy Dash)
	AI_PROCEDURAL = 4     ## IV. SEKTOR AETHER: SZACHOWNICA AI (Kontra stylu gracza + Zadania z Portalu)
}

enum TileType {
	EMPTY = 0,
	FLOOR = 1,
	WALL = 2,
	PLATFORM = 3,
	TUNNEL_CEILING = 4,
	HAZARD_SPIKE = 5,
	BRIDGE = 6,
	TRAMPOLINE = 7,
	HAZARD_LIQUID = 8,
	FLOOR_FILL = 9,
	WALL_FILL = 10
}

enum BiomeId {
	FOREST = 1,
	WINTER = 2,
	AUTUMN = 3,
	AETHER = 4
}

const TILE_SIZE: int = 16

const FORBIDDEN_Q_TILES: Array[Vector2i] = [
	Vector2i(0, 2),
	Vector2i(3, 2),
	Vector2i(4, 2),
	Vector2i(7, 2)
]

const DEFAULT_ATLAS_MAP: Dictionary = {
	TileType.FLOOR: Vector2i(0, 0),
	TileType.FLOOR_FILL: Vector2i(0, 1),
	TileType.WALL: Vector2i(1, 0),
	TileType.WALL_FILL: Vector2i(1, 1),
	TileType.PLATFORM: Vector2i(0, 0),
	TileType.TUNNEL_CEILING: Vector2i(1, 1),
	TileType.BRIDGE: Vector2i(1, 7),
	TileType.HAZARD_LIQUID: Vector2i(4, 9),
	TileType.HAZARD_SPIKE: Vector2i(1, 1)
}

const BIOME_PALETTES: Dictionary = {
	BiomeId.FOREST: {
		"name": "Wiosna / Las",
		"floor_top": Vector2i(0, 0),
		"floor_fill": Vector2i(0, 1),
		"wall_top": Vector2i(1, 0),
		"wall_fill": Vector2i(1, 1),
		"platform": Vector2i(0, 0),
		"tunnel_ceiling": Vector2i(1, 1),
		"bridge": [Vector2i(0, 7), Vector2i(1, 7), Vector2i(2, 7)],
		"trampoline": Vector2i(1, 2),
		"liquid_top": Vector2i(4, 9),
		"liquid_fill": Vector2i(4, 10),
		"bg_col": 0,
		"bg_modulate": Color(0.84, 0.94, 1.0, 1.0),
		"sky_color": Color(0.84, 0.94, 1.0, 1.0),
		"bottom_color": Color8(62, 45, 82),
		"enemy_color": 2
	},
	BiomeId.WINTER: {
		"name": "Zima / Lód",
		"floor_top": Vector2i(7, 1),
		"floor_fill": Vector2i(6, 1),
		"wall_top": Vector2i(8, 0),
		"wall_fill": Vector2i(8, 1),
		"platform": Vector2i(6, 0),
		"tunnel_ceiling": Vector2i(8, 1),
		"bridge": [Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8)],
		"trampoline": Vector2i(8, 2),
		"liquid_top": Vector2i(6, 9),
		"liquid_fill": Vector2i(6, 10),
		"bg_col": 3,
		"bg_modulate": Color(0.92, 0.96, 1.0, 1.0),
		"sky_color": Color8(160, 217, 255),
		"bottom_color": Color8(100, 123, 250),
		"enemy_color": 1
	},
	BiomeId.AUTUMN: {
		"name": "Jesień / Kanion",
		"floor_top": Vector2i(4, 0),
		"floor_fill": Vector2i(4, 1),
		"wall_top": Vector2i(5, 0),
		"wall_fill": Vector2i(5, 1),
		"platform": Vector2i(4, 0),
		"tunnel_ceiling": Vector2i(5, 1),
		"bridge": [Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3)],
		"trampoline": Vector2i(5, 2),
		"liquid_top": Vector2i(4, 11),
		"liquid_fill": Vector2i(4, 12),
		"bg_col": 2,
		"bg_modulate": Color(1.0, 1.0, 1.0, 1.0),
		"sky_color": Color8(242, 174, 153),
		"bottom_color": Color8(135, 62, 132),
		"enemy_color": 3
	},
	BiomeId.AETHER: {
		"name": "Aether",
		"floor_top": Vector2i(2, 0),
		"floor_fill": Vector2i(2, 1),
		"wall_top": Vector2i(3, 0),
		"wall_fill": Vector2i(3, 1),
		"platform": Vector2i(2, 2),
		"tunnel_ceiling": Vector2i(3, 1),
		"bridge": [Vector2i(0, 8), Vector2i(1, 8), Vector2i(2, 8)],
		"trampoline": Vector2i(2, 3),
		"liquid_top": Vector2i(4, 11),
		"liquid_fill": Vector2i(4, 12),
		"bg_col": 1,
		"bg_modulate": Color(1.0, 1.0, 1.0, 1.0),
		"sky_color": Color8(255, 195, 242),
		"bottom_color": Color8(242, 174, 153),
		"enemy_color": 0
	}
}

static func get_biome_palette(biome_id: int) -> Dictionary:
	return BIOME_PALETTES.get(biome_id, BIOME_PALETTES[BiomeId.FOREST])

static func get_default_tileset() -> TileSet:
	if ResourceLoader.exists(DEFAULT_TILESET_PATH):
		var loaded: TileSet = ResourceLoader.load(DEFAULT_TILESET_PATH) as TileSet
		if loaded != null:
			return loaded
	if ResourceLoader.exists(TILESET_PNG_PATH):
		var tex: Texture2D = load(TILESET_PNG_PATH) as Texture2D
		if tex != null:
			var ts := TileSet.new()
			ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
			var src := TileSetAtlasSource.new()
			src.texture = tex
			src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
			var cols: int = tex.get_width() / TILE_SIZE
			var rows: int = tex.get_height() / TILE_SIZE
			for r in range(rows):
				for c in range(cols):
					var coords := Vector2i(c, r)
					if not FORBIDDEN_Q_TILES.has(coords):
						src.create_tile(coords)
			ts.add_source(src, 0)
			return ts
	return null

## Zwraca metadane sektora ruchu oraz jego bazowy rozkład DNA Mechanik dla Level Select.
static func get_profile_metadata(profile_id: int) -> Dictionary:
	match profile_id:
		MechanicProfile.SYNERGY_CLASSIC:
			return {
				"id": 1,
				"biome_id": BiomeId.FOREST,
				"title": "I. SYNERGIA RUCHU (LAS)",
				"subtitle": "Balans: Climb + Dash + Double Jump + Trampoliny",
				"dominant": "balanced",
				"dna": {"wall_climb": 33, "dash": 33, "double_jump": 34},
				"description": "Leśny tor łączący szyby wspinaczkowe, tunele, mostki nad kwasem i trampoliny [!]. Idealny do opanowania flow.",
				"music_path": "res://audio/music/yessirski.wav",
				"music_title": "Yessirski"
			}
		MechanicProfile.VERTICAL_ASCENT:
			return {
				"id": 2,
				"biome_id": BiomeId.WINTER,
				"title": "II. SEKTOR PIONOWY (ZIMA / LÓD)",
				"subtitle": "Żywioł: Wall Climb, Trampoliny & Studnie Tricków",
				"dominant": "wall_climb",
				"dna": {"wall_climb": 54, "dash": 18, "double_jump": 28},
				"description": "Lodowe kominy wspinaczkowe, wysokie wieże i lodowate przepaście. Ładuj staminę Trickiem [Ctrl] podczas spadków.",
				"music_path": "res://audio/music/onmymommaimthegoat.wav",
				"music_title": "On My Momma I'm The Goat"
			}
		MechanicProfile.HORIZON_IMPULSE:
			return {
				"id": 3,
				"biome_id": BiomeId.AUTUMN,
				"title": "III. SEKTOR IMPULSU (JESIEŃ / LAWA)",
				"subtitle": "Żywioł: Slide -> Air Dash nad kanionami lawy",
				"dominant": "dash",
				"dna": {"wall_climb": 14, "dash": 52, "double_jump": 34},
				"description": "Jesienne tunele pędu, mostki nad morzem lawy i dynamiczne zrywy powietrzne. Utrzymuj tempo biegu!",
				"music_path": "res://audio/music/onsumbull.wav",
				"music_title": "On Sum Bull"
			}
		_:
			var fav: String = "double_jump"
			var least: String = "wall_climb"
			if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
				fav = Events.ai_director.get_favorite_move()
				least = Events.ai_director.get_least_used_move()
			return {
				"id": 4,
				"biome_id": BiomeId.AETHER,
				"title": "IV. AETHER: SZACHOWNICA AI",
				"subtitle": "1. połowa: %s -> 2. połowa: %s" % [fav.to_upper(), least.to_upper()],
				"dominant": least,
				"dna": {"wall_climb": 35, "dash": 30, "double_jump": 35},
				"description": "Lokalny Generator AI (biom Aether): losuje warianty modułów z seeda, kontruje styl gracza i realizuje zadania z portalu!",
				"music_path": "res://audio/music/onsumbull.wav",
				"music_title": "On Sum Bull"
			}

static func get_level_music_path(profile_id: int) -> String:
	match profile_id:
		MechanicProfile.SYNERGY_CLASSIC:
			return "res://audio/music/yessirski.wav"
		MechanicProfile.VERTICAL_ASCENT:
			return "res://audio/music/onmymommaimthegoat.wav"
		MechanicProfile.HORIZON_IMPULSE:
			return "res://audio/music/onsumbull.wav"
		_:
			return "res://audio/music/onsumbull.wav"

## Buduje poziom dla wybranego profilu wewnątrz węzła areny, uwzględniając aktywne zadania ze strony internetowej.
static func build_level_for_arena(
	arena_root: Node2D,
	profile_id: int,
	seed_val: int = 0,
	custom_tileset: TileSet = null,
	_force_regenerate: bool = false,
	override_challenge_reqs: Dictionary = {}
) -> Dictionary:
	var resolved_tileset: TileSet = custom_tileset if custom_tileset != null else get_default_tileset()
	var tile_layer: TileMapLayer = _ensure_tilemap_layer(arena_root, "LevelTileMapLayer", -1, resolved_tileset)
	var challenge_reqs: Dictionary = override_challenge_reqs
	if challenge_reqs.is_empty() and is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		challenge_reqs = Events.portal_sync.get_aggregated_challenge_requirements()

	var rng := RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.seed = int(Time.get_unix_time_from_system()) + profile_id * 7919

	var blueprint: Dictionary = generate_blueprint(profile_id, rng, challenge_reqs)
	_apply_blueprint_to_arena(arena_root, tile_layer, blueprint, resolved_tileset)

	return {
		"profile_id": profile_id,
		"biome_id": int(blueprint.get("biome_id", BiomeId.FOREST)),
		"seed": rng.seed,
		"tile_count": (blueprint["logical_grid"] as Dictionary).size(),
		"jewel_count": (blueprint["jewels"] as Array).size(),
		"enemy_count": (blueprint.get("enemies", []) as Array).size(),
		"trampoline_count": (blueprint.get("trampolines", []) as Array).size(),
		"challenge_max_time_s": float(blueprint.get("challenge_max_time_s", -1.0)),
		"first_half_mechanic": String(blueprint.get("first_half_mechanic", "")),
		"second_half_mechanic": String(blueprint.get("second_half_mechanic", "")),
		"validation": blueprint.get("validation", {}),
		"generated": true
	}

## Generuje kompletny plan poziomu dla Profilu 1, 2, 3 lub 4 (Szachownica AI z seedem).
static func generate_blueprint(profile_id: int, rng: RandomNumberGenerator, challenge_reqs: Dictionary = {}) -> Dictionary:
	var use_cursed: bool = false
	if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
		use_cursed = (Events.ai_director.active_contract == AdaptiveAIDirector.ContractMode.CURSED_JEWELS)

	var blueprint: Dictionary
	match profile_id:
		MechanicProfile.SYNERGY_CLASSIC:
			blueprint = _build_level_1_forest(use_cursed)
		MechanicProfile.VERTICAL_ASCENT:
			blueprint = _build_level_2_winter(use_cursed)
		MechanicProfile.HORIZON_IMPULSE:
			blueprint = _build_level_3_autumn(use_cursed)
		_:
			var fav_move: String = "double_jump"
			var least_move: String = "wall_climb"
			if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
				fav_move = Events.ai_director.get_favorite_move()
				least_move = Events.ai_director.get_least_used_move()
			var focus_list: Array = challenge_reqs.get("focus_mechanics", [])
			if not focus_list.is_empty():
				least_move = String(focus_list[0])
			blueprint = AILevelComposer.compose_chessboard_level(rng, fav_move, least_move, challenge_reqs, use_cursed)

	# Upewnienie się, że nawet dla poziomów 1–3 spełnione są wymogi liczby klejnotów z wyzwań portalu
	var required_jewels: int = int(challenge_reqs.get("min_jewels", 0))
	var jewels: Array[Dictionary] = blueprint["jewels"]
	var blocks: Array[Dictionary] = blueprint["blocks"]
	var finish_pos: Vector2 = blueprint.get("finish_pos", Vector2(3000, 276))
	var extra_idx: int = 0
	while jewels.size() < required_jewels:
		extra_idx += 1
		var jx: float = _snap16(240.0 + float(extra_idx) * 224.0)
		if jx > finish_pos.x - 112.0:
			jx = _snap16(208.0 + float((extra_idx * 128) % int(max(256.0, finish_pos.x - 320.0))))
		var jy: float = 192.0 if extra_idx % 2 == 1 else 160.0
		blocks.append({
			"name": "ChallengeBonusPad_%d" % extra_idx,
			"pos": Vector2(jx, jy + 32.0),
			"size": Vector2(64.0, 16.0),
			"type": TileType.PLATFORM
		})
		jewels.append({"pos": Vector2(jx, jy), "cursed_mechanic": "", "jewel_type": 0})

	blueprint["challenge_max_time_s"] = float(challenge_reqs.get("max_time_s", -1.0))
	blueprint = AILevelComposer.validate_and_repair_blueprint(blueprint)
	blueprint["logical_grid"] = _rasterize_blocks_to_logical_grid(blueprint["blocks"], blueprint["hazards"])
	return blueprint

# ==============================================================================
# POZIOM 1: WIOSNA / LAS (SYNERGIA RUCHU)
# ==============================================================================

static func _build_level_1_forest(use_cursed: bool) -> Dictionary:
	var blocks: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	var trampolines: Array[Dictionary] = []
	var checkpoints: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
	var jewels: Array[Dictionary] = []
	var decorations: Array[Dictionary] = []
	var labels: Array[Dictionary] = []

	blocks.append({"name": "WallLeft", "pos": Vector2(0, 160), "size": Vector2(32, 384), "type": TileType.WALL})

	# ==============================================================================
	# Sekcja 1 (0..1152): Startowa Polana, Komin Wspinaczkowy i Wzgórza
	# ==============================================================================
	blocks.append({"name": "FloorStart", "pos": Vector2(384, 328), "size": Vector2(768, 48), "type": TileType.FLOOR})
	blocks.append({"name": "ShaftWall1", "pos": Vector2(152, 176), "size": Vector2(16, 160), "type": TileType.WALL})
	blocks.append({"name": "ShaftWall2", "pos": Vector2(232, 208), "size": Vector2(16, 192), "type": TileType.WALL})
	blocks.append({"name": "ShaftTopPlat", "pos": Vector2(288, 120), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(288, 84), "cursed_mechanic": "wall_climb" if use_cursed else "", "jewel_type": 0})
	jewels.append({"pos": Vector2(448, 288), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(560, 288), "cursed_mechanic": "", "jewel_type": 0})
	enemies.append({"name": "ForestSlime1", "pos": Vector2(512, 294), "archetype": 0, "patrol_range": 64.0, "move_speed": 36.0, "detection_radius": 120.0})
	labels.append({"pos": Vector2(104, 72), "text": "GREEN HILL: Wspinaczka [W] lub Wall Jump w kominie"})

	# Alternatywna Górna Ścieżka (Upper Route): Start w koronach drzew ze szczytu komina
	blocks.append({"name": "UpperCanopyEntry", "pos": Vector2(390, 116), "size": Vector2(64, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "UpperCanopyPlat1", "pos": Vector2(530, 112), "size": Vector2(128, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "UpperCanopyPlat2", "pos": Vector2(740, 104), "size": Vector2(128, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "UpperHillOverlook", "pos": Vector2(980, 112), "size": Vector2(144, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(530, 76), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(740, 68), "cursed_mechanic": "", "jewel_type": 2}) # SPEED_JEWEL za wejście na górę!
	jewels.append({"pos": Vector2(980, 76), "cursed_mechanic": "", "jewel_type": 0})

	# Schodkowe wzniesienia (zielone pagórki)
	blocks.append({"name": "HillStep1", "pos": Vector2(848, 312), "size": Vector2(256, 48), "type": TileType.FLOOR})
	blocks.append({"name": "HillStep2", "pos": Vector2(1048, 280), "size": Vector2(208, 48), "type": TileType.FLOOR})
	jewels.append({"pos": Vector2(848, 260), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(1048, 230), "cursed_mechanic": "", "jewel_type": 0})

	# ==============================================================================
	# GAP 1 (1152..1264): Pierwszy Kanion Kolców (otwarta przepaść z kolcami na dnie)
	# ==============================================================================
	hazards.append({"name": "SpikesGap1", "pos": Vector2(1208, 324), "size": Vector2(112, 24), "kind": "spikes"})
	jewels.append({"pos": Vector2(1208, 240), "cursed_mechanic": "", "jewel_type": 2}) # SPEED_JEWEL
	labels.append({"pos": Vector2(1136, 190), "text": "Dash [Shift] nad kolcami!"})

	# Górny wiszący most nad GAP 1 (płynny przelot dla gracza na górnej ścieżce)
	blocks.append({"name": "UpperSkyBridgeGap1", "pos": Vector2(1208, 104), "size": Vector2(144, 16), "type": TileType.BRIDGE})
	jewels.append({"pos": Vector2(1208, 68), "cursed_mechanic": "", "jewel_type": 0})

	# ==============================================================================
	# Sekcja 2 (1264..1680): Tunel Wślizgu i Polana Przed Mostem
	# ==============================================================================
	blocks.append({"name": "FloorMid1", "pos": Vector2(1472, 328), "size": Vector2(416, 48), "type": TileType.FLOOR})
	blocks.append({"name": "LowCeilingTunnel1", "pos": Vector2(1420, 272), "size": Vector2(160, 16), "type": TileType.TUNNEL_CEILING})
	jewels.append({"pos": Vector2(1420, 288), "cursed_mechanic": "", "jewel_type": 0})
	labels.append({"pos": Vector2(1330, 236), "text": "Wślizg [S] pod niskim sufitem"})
	enemies.append({"name": "ForestSpider1", "pos": Vector2(1580, 294), "archetype": 2, "patrol_range": 64.0, "move_speed": 40.0, "detection_radius": 135.0})

	# Górna autostrada nad tunelem wślizgu (omija czołganie się dołem!)
	blocks.append({"name": "UpperSkyRunway1", "pos": Vector2(1420, 112), "size": Vector2(192, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "UpperSkyMidPlat", "pos": Vector2(1620, 104), "size": Vector2(96, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(1360, 76), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(1480, 76), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(1620, 68), "cursed_mechanic": "", "jewel_type": 0})

	# ==============================================================================
	# GAP 2 (1680..1920): Pierwszy Wodospad z Wiszącym Mostem i Podniebną Wyspą
	# ==============================================================================
	hazards.append({"name": "WaterfallChasm1", "pos": Vector2(1800, 336), "size": Vector2(240, 32), "kind": "liquid"})
	blocks.append({"name": "ForestBridge1", "pos": Vector2(1800, 296), "size": Vector2(192, 16), "type": TileType.BRIDGE})
	blocks.append({"name": "FloatingIsland1", "pos": Vector2(1800, 176), "size": Vector2(96, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(1800, 136), "cursed_mechanic": "dash" if use_cursed else "", "jewel_type": 0})
	enemies.append({"name": "ForestBat1", "pos": Vector2(1800, 208), "archetype": 1, "patrol_range": 56.0, "move_speed": 38.0, "detection_radius": 135.0})

	# Górny most widokowy nad pierwszym wodospadem
	blocks.append({"name": "UpperSkyBridge1", "pos": Vector2(1800, 96), "size": Vector2(208, 16), "type": TileType.BRIDGE})
	jewels.append({"pos": Vector2(1800, 60), "cursed_mechanic": "", "jewel_type": 0})

	# Sekcja za mostem i Checkpoint 1 (CP-1 stabilnie na podłożu!)
	blocks.append({"name": "FloorAfterBridge1", "pos": Vector2(2088, 328), "size": Vector2(336, 48), "type": TileType.FLOOR})
	checkpoints.append({"name": "Checkpoint1", "id": "CP-1", "pos": Vector2(2088, 280)})

	# Podniebna estakada nad Checkpointem 1 i GAP 3
	blocks.append({"name": "UpperSkyOverCP1", "pos": Vector2(2088, 104), "size": Vector2(160, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "UpperSkyChasmBridge1", "pos": Vector2(2320, 120), "size": Vector2(128, 16), "type": TileType.BRIDGE})
	jewels.append({"pos": Vector2(2088, 68), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(2320, 84), "cursed_mechanic": "", "jewel_type": 0})

	# ==============================================================================
	# GAP 3 (2256..2352): Pierwsza Otwarta Przepaść (widoczna czeluść do przeskoczenia)
	# ==============================================================================

	# ==============================================================================
	# Sekcja 3 (2352..3216): Falujące Wzgórza, Trampolina 1, Korony Drzew i Tunel 2
	# ==============================================================================
	blocks.append({"name": "HillRise1", "pos": Vector2(2456, 304), "size": Vector2(208, 48), "type": TileType.FLOOR})
	blocks.append({"name": "HillPlateau1", "pos": Vector2(2656, 272), "size": Vector2(256, 48), "type": TileType.FLOOR})
	trampolines.append({"name": "ForestTrampoline1", "pos": Vector2(2600, 240), "bounce_velocity": -480.0})
	labels.append({"pos": Vector2(2536, 184), "text": "Trampolina [!]: Wybicie w korony drzew!"})

	# Górna ścieżka w koronach drzew (High Route)
	blocks.append({"name": "CanopyPlat1", "pos": Vector2(2700, 144), "size": Vector2(96, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "CanopyPlat2", "pos": Vector2(2832, 112), "size": Vector2(96, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(2832, 76), "cursed_mechanic": "", "jewel_type": 3}) # IMMUNITY_JEWEL

	# Wielka Górna Autostrada (High Skyway) nad doliną, tunelem 2 i przepaścią kolców
	blocks.append({"name": "UpperHighBridge1", "pos": Vector2(3056, 96), "size": Vector2(160, 16), "type": TileType.BRIDGE})
	blocks.append({"name": "UpperSkyPlatGap2", "pos": Vector2(3280, 80), "size": Vector2(160, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(3056, 60), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(3280, 44), "cursed_mechanic": "", "jewel_type": 2}) # SPEED_JEWEL!
	labels.append({"pos": Vector2(3180, 24), "text": "GÓRNA ŚCIEŻKA: Trzymaj pęd w koronach drzew!"})

	# Dolna dolina z tunelem wślizgu (Low Route)
	blocks.append({"name": "ValleyFloor1", "pos": Vector2(2992, 328), "size": Vector2(448, 48), "type": TileType.FLOOR})
	blocks.append({"name": "LowCeilingTunnel2", "pos": Vector2(2940, 272), "size": Vector2(160, 16), "type": TileType.TUNNEL_CEILING})
	jewels.append({"pos": Vector2(2940, 288), "cursed_mechanic": "", "jewel_type": 0})
	enemies.append({"name": "ForestSlime2", "pos": Vector2(3100, 294), "archetype": 0, "patrol_range": 64.0, "move_speed": 40.0, "detection_radius": 130.0})

	# ==============================================================================
	# GAP 4 (3216..3344): Drugi Kanion Kolców z Podniebną Platformą
	# ==============================================================================
	hazards.append({"name": "SpikesGap2", "pos": Vector2(3280, 324), "size": Vector2(128, 24), "kind": "spikes"})
	blocks.append({"name": "SkyJumpPlat1", "pos": Vector2(3280, 232), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(3280, 196), "cursed_mechanic": "", "jewel_type": 0})
	enemies.append({"name": "ForestBat2", "pos": Vector2(3330, 168), "archetype": 1, "patrol_range": 48.0, "move_speed": 40.0, "detection_radius": 135.0})

	# ==============================================================================
	# Sekcja 4 (3344..4176): Leśne Ruiny i Komin Wspinaczkowy
	# ==============================================================================
	blocks.append({"name": "FloorRuinsEntry", "pos": Vector2(3512, 328), "size": Vector2(336, 48), "type": TileType.FLOOR})
	blocks.append({"name": "RuinsWallLeft", "pos": Vector2(3680, 176), "size": Vector2(16, 160), "type": TileType.WALL})
	blocks.append({"name": "RuinsWallRight", "pos": Vector2(3760, 208), "size": Vector2(16, 192), "type": TileType.WALL})
	blocks.append({"name": "RuinsPlatTop", "pos": Vector2(3824, 120), "size": Vector2(96, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(3824, 84), "cursed_mechanic": "double_jump" if use_cursed else "", "jewel_type": 0})

	# Podniebna estakada nad ruinami, szybem wspinaczkowym i drugim wodospadem
	blocks.append({"name": "RuinsHighRooftop", "pos": Vector2(3520, 80), "size": Vector2(160, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "RuinsSkyWalkway", "pos": Vector2(3760, 64), "size": Vector2(192, 16), "type": TileType.BRIDGE})
	blocks.append({"name": "SkyOverGorgePlat", "pos": Vector2(4040, 80), "size": Vector2(144, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(3520, 44), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(3760, 28), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(4040, 44), "cursed_mechanic": "", "jewel_type": 0})

	blocks.append({"name": "RuinsLowerFloor", "pos": Vector2(3952, 328), "size": Vector2(448, 48), "type": TileType.FLOOR})
	enemies.append({"name": "ForestSpider2", "pos": Vector2(4048, 294), "archetype": 2, "patrol_range": 64.0, "move_speed": 42.0, "detection_radius": 135.0})

	# ==============================================================================
	# GAP 5 (4176..4464): Drugi Wodospad z Kładką i Wysepkami Krokowymi
	# ==============================================================================
	hazards.append({"name": "WaterfallChasm2", "pos": Vector2(4320, 336), "size": Vector2(288, 32), "kind": "liquid"})
	blocks.append({"name": "ForestBridge2", "pos": Vector2(4260, 296), "size": Vector2(128, 16), "type": TileType.BRIDGE})
	blocks.append({"name": "SteppingStone1", "pos": Vector2(4400, 264), "size": Vector2(64, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(4400, 224), "cursed_mechanic": "", "jewel_type": 0})

	# Górny wiszący most nad drugim wodospadem i taras nad CP-2
	blocks.append({"name": "SkyBridgeWaterfall2", "pos": Vector2(4320, 72), "size": Vector2(208, 16), "type": TileType.BRIDGE})
	blocks.append({"name": "SkyMidwayStep", "pos": Vector2(4500, 76), "size": Vector2(64, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "SkyOverlookCP2", "pos": Vector2(4656, 80), "size": Vector2(160, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(4320, 36), "cursed_mechanic": "", "jewel_type": 3}) # IMMUNITY_JEWEL!
	jewels.append({"pos": Vector2(4656, 44), "cursed_mechanic": "", "jewel_type": 0})

	# Półmetek i Checkpoint 2 (CP-2 stabilnie na podłożu!)
	blocks.append({"name": "FloorMidway", "pos": Vector2(4656, 328), "size": Vector2(384, 48), "type": TileType.FLOOR})
	checkpoints.append({"name": "Checkpoint2", "id": "CP-2", "pos": Vector2(4656, 280)})
	labels.append({"pos": Vector2(4560, 236), "text": "PÓŁMETEK: Przygotuj się na Wielką Rampę!"})

	# ==============================================================================
	# GAP 6 (4848..4944): Druga Otwarta Przepaść (czysta czeluść przed rampą)
	# ==============================================================================
	blocks.append({"name": "SkyChasmBridge2", "pos": Vector2(4848, 84), "size": Vector2(96, 16), "type": TileType.BRIDGE})

	# ==============================================================================
	# Sekcja 5 (4944..6224): Wielka Rampa, Podniebne Wyspy, Dolny Wąwóz i Trampolina 2
	# ==============================================================================
	blocks.append({"name": "SkyRampExpress", "pos": Vector2(4960, 88), "size": Vector2(144, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "SkyRampBridge", "pos": Vector2(5200, 104), "size": Vector2(144, 16), "type": TileType.BRIDGE})
	jewels.append({"pos": Vector2(4960, 52), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(5200, 68), "cursed_mechanic": "", "jewel_type": 0})
	blocks.append({"name": "RampFloor1", "pos": Vector2(5056, 304), "size": Vector2(224, 48), "type": TileType.FLOOR})
	blocks.append({"name": "RampFloor2", "pos": Vector2(5256, 272), "size": Vector2(208, 48), "type": TileType.FLOOR})
	blocks.append({"name": "HighIsland1", "pos": Vector2(5440, 160), "size": Vector2(112, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "HighIsland2", "pos": Vector2(5600, 128), "size": Vector2(112, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(5056, 252), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(5256, 220), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(5440, 120), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(5600, 88), "cursed_mechanic": "", "jewel_type": 2}) # SPEED_JEWEL

	# Dolny wąwóz z kolcami i trampoliną powrotną (ForestTrampoline2 stabilnie na ziemi!)
	hazards.append({"name": "SpikesValley1", "pos": Vector2(5440, 324), "size": Vector2(208, 24), "kind": "spikes"})
	blocks.append({"name": "LowerFloorGorge", "pos": Vector2(5704, 328), "size": Vector2(368, 48), "type": TileType.FLOOR})
	trampolines.append({"name": "ForestTrampoline2", "pos": Vector2(5580, 296), "bounce_velocity": -490.0})
	enemies.append({"name": "ForestBat3", "pos": Vector2(5456, 192), "archetype": 1, "patrol_range": 64.0, "move_speed": 42.0, "detection_radius": 140.0})

	# Plateau środkowe i tunel wślizgu 3
	blocks.append({"name": "PlateauMid3", "pos": Vector2(6032, 328), "size": Vector2(384, 48), "type": TileType.FLOOR})
	blocks.append({"name": "LowCeilingTunnel3", "pos": Vector2(5980, 272), "size": Vector2(160, 16), "type": TileType.TUNNEL_CEILING})
	jewels.append({"pos": Vector2(5980, 288), "cursed_mechanic": "", "jewel_type": 0})
	enemies.append({"name": "ForestSlime3", "pos": Vector2(6120, 294), "archetype": 0, "patrol_range": 64.0, "move_speed": 42.0, "detection_radius": 135.0})

	# Górny wiszący most nad tunelem 3 i GAP 7
	blocks.append({"name": "UpperSkyBridge3", "pos": Vector2(5980, 112), "size": Vector2(176, 16), "type": TileType.BRIDGE})
	blocks.append({"name": "UpperBridgeOverSpikes3", "pos": Vector2(6288, 96), "size": Vector2(160, 16), "type": TileType.BRIDGE})
	jewels.append({"pos": Vector2(5980, 76), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(6288, 60), "cursed_mechanic": "", "jewel_type": 0})

	# ==============================================================================
	# GAP 7 (6224..6352): Trzeci Kanion Kolców z Kładką
	# ==============================================================================
	hazards.append({"name": "SpikesPit3", "pos": Vector2(6288, 324), "size": Vector2(128, 24), "kind": "spikes"})
	blocks.append({"name": "BridgeOverSpikes3", "pos": Vector2(6288, 280), "size": Vector2(112, 16), "type": TileType.BRIDGE})
	jewels.append({"pos": Vector2(6288, 240), "cursed_mechanic": "", "jewel_type": 0})

	# ==============================================================================
	# Sekcja 6 (6352..6968): Jaskinia Wodospadów, Komin i Checkpoint 3
	# ==============================================================================
	blocks.append({"name": "FloorCaveEntry", "pos": Vector2(6520, 328), "size": Vector2(336, 48), "type": TileType.FLOOR})
	blocks.append({"name": "FloorCaveShaft", "pos": Vector2(6824, 328), "size": Vector2(288, 48), "type": TileType.FLOOR})
	blocks.append({"name": "CaveWallShaft1", "pos": Vector2(6680, 184), "size": Vector2(16, 160), "type": TileType.WALL})
	blocks.append({"name": "CaveWallShaft2", "pos": Vector2(6760, 216), "size": Vector2(16, 192), "type": TileType.WALL})
	blocks.append({"name": "CaveShaftPlat", "pos": Vector2(6824, 128), "size": Vector2(96, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(6824, 92), "cursed_mechanic": "", "jewel_type": 0})
	enemies.append({"name": "ForestSpider3", "pos": Vector2(6552, 294), "archetype": 2, "patrol_range": 64.0, "move_speed": 44.0, "detection_radius": 140.0})

	# Górny dach jaskini i podniebna kładka nad Checkpointem 3
	blocks.append({"name": "UpperCaveRooftop", "pos": Vector2(6520, 88), "size": Vector2(160, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "UpperCaveShaftWalk", "pos": Vector2(6760, 72), "size": Vector2(176, 16), "type": TileType.BRIDGE})
	jewels.append({"pos": Vector2(6520, 52), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(6760, 36), "cursed_mechanic": "", "jewel_type": 0})

	# Checkpoint 3 (CP-3 stoi stabilnie na FloorCaveShaft!)
	checkpoints.append({"name": "Checkpoint3", "id": "CP-3", "pos": Vector2(6880, 280)})

	# ==============================================================================
	# GAP 8 (6968..7248): Trzeci Duży Wodospad z Kładką i Górną Półką Koron
	# ==============================================================================
	hazards.append({"name": "WaterfallChasm3", "pos": Vector2(7108, 336), "size": Vector2(280, 32), "kind": "liquid"})
	blocks.append({"name": "ForestBridge3", "pos": Vector2(7080, 296), "size": Vector2(144, 16), "type": TileType.BRIDGE})
	blocks.append({"name": "UpperCanopyLedge", "pos": Vector2(7216, 200), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(7216, 160), "cursed_mechanic": "", "jewel_type": 0})

	# Podniebny most nad wodospadem kierujący wprost do sekretu
	blocks.append({"name": "UpperChasm3Bridge", "pos": Vector2(7108, 80), "size": Vector2(208, 16), "type": TileType.BRIDGE})
	jewels.append({"pos": Vector2(7108, 44), "cursed_mechanic": "", "jewel_type": 0})

	# ==============================================================================
	# Sekcja 6 c.d. (7248..7584): Sekretne Wyspy i Trampolina 3 (ForestTrampoline3 na ziemi!)
	# ==============================================================================
	blocks.append({"name": "FloorSecretUnder", "pos": Vector2(7416, 328), "size": Vector2(336, 48), "type": TileType.FLOOR})
	trampolines.append({"name": "ForestTrampoline3", "pos": Vector2(7320, 296), "bounce_velocity": -480.0})
	blocks.append({"name": "SecretIslandFinale", "pos": Vector2(7440, 128), "size": Vector2(96, 16), "type": TileType.PLATFORM})
	jewels.append({
		"pos": Vector2(7440, 92),
		"cursed_mechanic": "",
		"jewel_type": 0,
		"is_secret_special": true,
		"special_id": "SEC-LVL-1",
		"special_name": "Klejnot Eteru #1",
		"special_rarity": "Legendarny"
	})

	# ==============================================================================
	# GAP 9 (7584..7680): Trzecia Otwarta Przepaść przed Finiszem
	# ==============================================================================

	# ==============================================================================
	# Sekcja 7 (7680..8800): Finałowy Pęd, Pagórki i Meta (Finish Goal)
	# ==============================================================================
	blocks.append({"name": "HillDrop1", "pos": Vector2(7792, 304), "size": Vector2(224, 48), "type": TileType.FLOOR})
	blocks.append({"name": "HillDrop2", "pos": Vector2(8000, 312), "size": Vector2(208, 48), "type": TileType.FLOOR})
	blocks.append({"name": "FloorFinaleRunway", "pos": Vector2(8384, 328), "size": Vector2(608, 48), "type": TileType.FLOOR})
	enemies.append({"name": "ForestSlime4", "pos": Vector2(8120, 294), "archetype": 0, "patrol_range": 64.0, "move_speed": 42.0, "detection_radius": 130.0})
	enemies.append({"name": "ForestBat4", "pos": Vector2(8320, 216), "archetype": 1, "patrol_range": 48.0, "move_speed": 40.0, "detection_radius": 135.0})

	# Finałowy łuk klejnotów (jak w Sonicu przed tablicą z metą)
	jewels.append({"pos": Vector2(7792, 252), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(8000, 268), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(8220, 280), "cursed_mechanic": "", "jewel_type": 0})
	jewels.append({"pos": Vector2(8384, 268), "cursed_mechanic": "", "jewel_type": 1}) # JEW_JEWEL
	jewels.append({"pos": Vector2(8540, 280), "cursed_mechanic": "", "jewel_type": 0})

	# Platforma mety i tablica finiszu
	blocks.append({"name": "FloorFinishPlat", "pos": Vector2(8712, 328), "size": Vector2(192, 48), "type": TileType.FLOOR})
	blocks.append({"name": "WallRight", "pos": Vector2(8784, 160), "size": Vector2(32, 384), "type": TileType.WALL})
	hazards.append({"name": "AbyssZone", "pos": Vector2(4400, 448), "size": Vector2(10000, 64), "is_abyss": true})

	# ==============================================================================
	# Dekoracje: Drzewa i Roślinność automatycznie osadzane dokładnie na szczycie stałego podłoża!
	# ==============================================================================
	_add_tree_decor(decorations, blocks, 6)
	_add_plant_decor(decorations, blocks, 15, Vector2i(1, 6))
	_add_plant_decor(decorations, blocks, 25, Vector2i(0, 6))
	_add_tree_decor(decorations, blocks, 54)
	_add_plant_decor(decorations, blocks, 60, Vector2i(9, 0))

	_add_tree_decor(decorations, blocks, 88)
	_add_plant_decor(decorations, blocks, 102, Vector2i(1, 3))
	_add_tree_decor(decorations, blocks, 130)

	_add_tree_decor(decorations, blocks, 155)
	_add_plant_decor(decorations, blocks, 175, Vector2i(1, 6))
	_add_tree_decor(decorations, blocks, 195)

	_add_tree_decor(decorations, blocks, 225)
	_add_plant_decor(decorations, blocks, 255, Vector2i(7, 6))

	_add_tree_decor(decorations, blocks, 320)
	_add_plant_decor(decorations, blocks, 345, Vector2i(9, 3))
	_add_tree_decor(decorations, blocks, 375)

	_add_tree_decor(decorations, blocks, 415)
	_add_plant_decor(decorations, blocks, 440, Vector2i(1, 6))
	_add_tree_decor(decorations, blocks, 465)

	_add_tree_decor(decorations, blocks, 495)
	_add_plant_decor(decorations, blocks, 515, Vector2i(10, 0))
	_add_tree_decor(decorations, blocks, 535)
	_add_plant_decor(decorations, blocks, 545, Vector2i(4, 3))

	return {
		"profile_id": MechanicProfile.SYNERGY_CLASSIC,
		"biome_id": BiomeId.FOREST,
		"respawn_pos": Vector2(72, 272),
		"finish_pos": Vector2(8650, 276),
		"level_width": 8800.0,
		"blocks": blocks,
		"hazards": hazards,
		"trampolines": trampolines,
		"checkpoints": checkpoints,
		"enemies": enemies,
		"jewels": jewels,
		"decorations": decorations,
		"labels": labels,
		"first_half_mechanic": "balanced",
		"second_half_mechanic": "balanced"
	}

# ==============================================================================
# POZIOM 2: ZIMA / LÓD (SEKTOR PIONOWY: ASCENT)
# ==============================================================================

static func _build_level_2_winter(use_cursed: bool) -> Dictionary:
	var blocks: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	var trampolines: Array[Dictionary] = []
	var checkpoints: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
	var jewels: Array[Dictionary] = []
	var decorations: Array[Dictionary] = []
	var labels: Array[Dictionary] = []

	blocks.append({"name": "WallLeft", "pos": Vector2(0, 160), "size": Vector2(32, 384), "type": TileType.WALL})

	# Sekcja 1 (16..592): Lodowa Baza i Podwójny Komin
	blocks.append({"name": "IceStartFloor", "pos": Vector2(304, 328), "size": Vector2(576, 48), "type": TileType.FLOOR})
	blocks.append({"name": "GlacialShaftL", "pos": Vector2(168, 168), "size": Vector2(16, 160), "type": TileType.WALL})
	blocks.append({"name": "GlacialShaftR", "pos": Vector2(248, 200), "size": Vector2(16, 208), "type": TileType.WALL})
	blocks.append({"name": "GlacialTopLedge", "pos": Vector2(304, 112), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(304, 76), "cursed_mechanic": "wall_climb" if use_cursed else "", "jewel_type": 0})
	jewels.append({"pos": Vector2(400, 196), "cursed_mechanic": "", "jewel_type": 0})
	enemies.append({"name": "WinterSlime1", "pos": Vector2(456, 294), "archetype": 0, "patrol_range": 64.0, "move_speed": 38.0, "detection_radius": 130.0})
	labels.append({"pos": Vector2(96, 68), "text": "ZIMA ASCENT: Wspinaczka [W] -> Studnia Tricków [Ctrl]"})

	_add_decor_tile(decorations, 3, 18, Vector2i(4, 3))
	_add_decor_column(decorations, 7, 19, [Vector2i(7, 4), Vector2i(7, 5)])
	_add_decor_column(decorations, 28, 19, [Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6)])
	_add_decor_tile(decorations, 33, 18, Vector2i(8, 7))

	# Sekcja 2 (592..1136): Lodowate Wody, Trampolina 1 i Lodowe Wieże
	hazards.append({"name": "FreezePool1", "pos": Vector2(656, 336), "size": Vector2(128, 32), "kind": "liquid"})
	blocks.append({"name": "IceStepBridge1", "pos": Vector2(656, 288), "size": Vector2(64, 16), "type": TileType.BRIDGE})
	enemies.append({"name": "WinterBat1", "pos": Vector2(656, 192), "archetype": 1, "patrol_range": 48.0, "move_speed": 40.0, "detection_radius": 135.0})

	blocks.append({"name": "IceBankMid1", "pos": Vector2(928, 328), "size": Vector2(416, 48), "type": TileType.FLOOR})
	trampolines.append({"name": "WinterTrampoline1", "pos": Vector2(784, 296), "bounce_velocity": -480.0})
	blocks.append({"name": "TowerWallA", "pos": Vector2(872, 160), "size": Vector2(16, 176), "type": TileType.WALL})
	blocks.append({"name": "TowerWallB", "pos": Vector2(952, 192), "size": Vector2(16, 224), "type": TileType.WALL})
	blocks.append({"name": "TowerCrownPlat", "pos": Vector2(1016, 96), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(1016, 60), "cursed_mechanic": "", "jewel_type": 2}) # SPEED_JEWEL
	checkpoints.append({"name": "Checkpoint1", "id": "CP-1", "pos": Vector2(1096, 280)})
	labels.append({"pos": Vector2(816, 56), "text": "Ładuj staminę Trickiem [Ctrl] podczas lotu!"})
	_add_decor_tile(decorations, 65, 18, Vector2i(6, 8))

	# Sekcja 3 (1136..1760): Kolce i Schodkowa Wspinaczka na Szczyt Lodowca
	hazards.append({"name": "GlacierSpikes1", "pos": Vector2(1208, 324), "size": Vector2(144, 24), "kind": "spikes"})
	blocks.append({"name": "GlacierWall1", "pos": Vector2(1160, 192), "size": Vector2(16, 144), "type": TileType.WALL})
	blocks.append({"name": "GlacierPlat1", "pos": Vector2(1224, 240), "size": Vector2(64, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "GlacierWall2", "pos": Vector2(1272, 168), "size": Vector2(16, 144), "type": TileType.WALL})

	blocks.append({"name": "GlacierBank2", "pos": Vector2(1520, 328), "size": Vector2(480, 48), "type": TileType.FLOOR})
	blocks.append({"name": "GlacierPlatHigh", "pos": Vector2(1352, 128), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(1352, 92), "cursed_mechanic": "wall_climb" if use_cursed else "", "jewel_type": 0})
	enemies.append({"name": "WinterSpider1", "pos": Vector2(1488, 294), "archetype": 2, "patrol_range": 64.0, "move_speed": 42.0, "detection_radius": 140.0})
	enemies.append({"name": "WinterBat2", "pos": Vector2(1632, 196), "archetype": 1, "patrol_range": 48.0, "move_speed": 42.0, "detection_radius": 135.0})
	checkpoints.append({"name": "Checkpoint2", "id": "CP-2", "pos": Vector2(1728, 280)})
	_add_decor_column(decorations, 86, 19, [Vector2i(7, 4), Vector2i(7, 5)])
	_add_decor_tile(decorations, 102, 18, Vector2i(8, 8))

	# Sekcja 4 (1760..2448): Lodowata Zatoka, Mosty Linowe i Centralny Filar
	hazards.append({"name": "FreezeSea2", "pos": Vector2(1928, 336), "size": Vector2(336, 32), "kind": "liquid"})
	blocks.append({"name": "IceBridgeA", "pos": Vector2(1824, 288), "size": Vector2(64, 16), "type": TileType.BRIDGE})
	blocks.append({"name": "ClimbPillarMid", "pos": Vector2(1928, 176), "size": Vector2(16, 160), "type": TileType.WALL})
	blocks.append({"name": "ClimbPillarTop", "pos": Vector2(1928, 96), "size": Vector2(48, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(1928, 60), "cursed_mechanic": "", "jewel_type": 3}) # IMMUNITY_JEWEL
	blocks.append({"name": "IceBridgeB", "pos": Vector2(2032, 272), "size": Vector2(64, 16), "type": TileType.BRIDGE})

	blocks.append({"name": "IceBank3", "pos": Vector2(2272, 328), "size": Vector2(352, 48), "type": TileType.FLOOR})
	enemies.append({"name": "WinterSlime2", "pos": Vector2(2256, 294), "archetype": 0, "patrol_range": 64.0, "move_speed": 40.0, "detection_radius": 135.0})
	_add_decor_column(decorations, 134, 19, [Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6)])

	# Sekcja 5 (2448..3136): Lodowa Cytadela, Trampolina 2, Sekret i Wyjście
	hazards.append({"name": "GlacierSpikes2", "pos": Vector2(2512, 324), "size": Vector2(128, 24), "kind": "spikes"})
	blocks.append({"name": "CitadelStep", "pos": Vector2(2512, 240), "size": Vector2(64, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(2512, 204), "cursed_mechanic": "double_jump" if use_cursed else "", "jewel_type": 0})

	blocks.append({"name": "IceGoalFloor", "pos": Vector2(2856, 328), "size": Vector2(560, 48), "type": TileType.FLOOR})
	trampolines.append({"name": "WinterTrampoline2", "pos": Vector2(2640, 296), "bounce_velocity": -480.0})
	blocks.append({"name": "CitadelWall", "pos": Vector2(2728, 152), "size": Vector2(16, 160), "type": TileType.WALL})
	blocks.append({"name": "SecretIceAlcove", "pos": Vector2(2808, 112), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	jewels.append({
		"pos": Vector2(2808, 76),
		"cursed_mechanic": "",
		"jewel_type": 0,
		"is_secret_special": true,
		"special_id": "SEC-LVL-2",
		"special_name": "Klejnot Eteru #2",
		"special_rarity": "Legendarny"
	})
	enemies.append({"name": "WinterSpider2", "pos": Vector2(2848, 294), "archetype": 2, "patrol_range": 64.0, "move_speed": 45.0, "detection_radius": 145.0})
	jewels.append({"pos": Vector2(2928, 268), "cursed_mechanic": "", "jewel_type": 1}) # JEW_JEWEL
	_add_decor_column(decorations, 182, 19, [Vector2i(7, 4), Vector2i(7, 5)])

	blocks.append({"name": "WallRight", "pos": Vector2(3152, 160), "size": Vector2(32, 384), "type": TileType.WALL})
	hazards.append({"name": "AbyssZone", "pos": Vector2(1584, 432), "size": Vector2(3840, 48), "is_abyss": true})

	return {
		"profile_id": MechanicProfile.VERTICAL_ASCENT,
		"biome_id": BiomeId.WINTER,
		"respawn_pos": Vector2(72, 272),
		"finish_pos": Vector2(3040, 276),
		"level_width": 3184.0,
		"blocks": blocks,
		"hazards": hazards,
		"trampolines": trampolines,
		"checkpoints": checkpoints,
		"enemies": enemies,
		"jewels": jewels,
		"decorations": decorations,
		"labels": labels,
		"first_half_mechanic": "wall_climb",
		"second_half_mechanic": "wall_climb"
	}

# ==============================================================================
# POZIOM 3: JESIEŃ / KANION Z LAWĄ (SEKTOR IMPULSU: MOMENTUM)
# ==============================================================================

static func _build_level_3_autumn(use_cursed: bool) -> Dictionary:
	var blocks: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	var trampolines: Array[Dictionary] = []
	var checkpoints: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
	var jewels: Array[Dictionary] = []
	var decorations: Array[Dictionary] = []
	var labels: Array[Dictionary] = []

	blocks.append({"name": "WallLeft", "pos": Vector2(0, 160), "size": Vector2(32, 384), "type": TileType.WALL})

	# Sekcja 1 (16..512): Rozbieg Jesienny i Skok nad Lawą
	blocks.append({"name": "AutumnStartFloor", "pos": Vector2(200, 328), "size": Vector2(368, 48), "type": TileType.FLOOR})
	enemies.append({"name": "AutumnSlime1", "pos": Vector2(272, 294), "archetype": 0, "patrol_range": 48.0, "move_speed": 40.0, "detection_radius": 135.0})
	hazards.append({"name": "LavaPit1", "pos": Vector2(448, 336), "size": Vector2(128, 32), "kind": "liquid"})
	jewels.append({"pos": Vector2(448, 252), "cursed_mechanic": "dash" if use_cursed else "", "jewel_type": 0})
	labels.append({"pos": Vector2(360, 200), "text": "MOMENTUM: Skok + Dash [Shift] nad lawą!"})

	_add_decor_tile(decorations, 3, 18, Vector2i(4, 3))
	_add_decor_column(decorations, 7, 19, [Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5)])
	_add_decor_tile(decorations, 12, 18, Vector2i(6, 6))
	_add_decor_tile(decorations, 19, 18, Vector2i(5, 6))

	# Sekcja 2 (512..944): Tunel Pędu 1 i Pościg Pająka
	blocks.append({"name": "AutumnBank1", "pos": Vector2(728, 328), "size": Vector2(432, 48), "type": TileType.FLOOR})
	blocks.append({"name": "SlideTunnel1", "pos": Vector2(656, 272), "size": Vector2(144, 16), "type": TileType.TUNNEL_CEILING})
	jewels.append({"pos": Vector2(656, 288), "cursed_mechanic": "", "jewel_type": 2}) # SPEED_JEWEL
	labels.append({"pos": Vector2(592, 232), "text": "Tunel Pędu: Wślizg [S] -> Wybicie"})
	enemies.append({"name": "AutumnSpider1", "pos": Vector2(832, 294), "archetype": 2, "patrol_range": 56.0, "move_speed": 46.0, "detection_radius": 145.0})
	checkpoints.append({"name": "Checkpoint1", "id": "CP-1", "pos": Vector2(912, 280)})
	_add_decor_tile(decorations, 34, 18, Vector2i(9, 1))

	# Sekcja 3 (944..1520): Szerokie Morze Lawy i Powietrzne Platformy Dasha
	hazards.append({"name": "LavaSea", "pos": Vector2(1232, 336), "size": Vector2(576, 32), "kind": "liquid"})
	blocks.append({"name": "SkyDashPad1", "pos": Vector2(1024, 240), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "SkyDashBridge", "pos": Vector2(1184, 192), "size": Vector2(96, 16), "type": TileType.BRIDGE})
	jewels.append({"pos": Vector2(1184, 156), "cursed_mechanic": "double_jump" if use_cursed else "", "jewel_type": 0})
	enemies.append({"name": "AutumnBat1", "pos": Vector2(1264, 136), "archetype": 1, "patrol_range": 64.0, "move_speed": 44.0, "detection_radius": 145.0})
	blocks.append({"name": "SkyDashPad2", "pos": Vector2(1344, 176), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(1344, 140), "cursed_mechanic": "", "jewel_type": 3}) # IMMUNITY_JEWEL
	blocks.append({"name": "SkyDashPad3", "pos": Vector2(1472, 240), "size": Vector2(64, 16), "type": TileType.PLATFORM})
	labels.append({"pos": Vector2(1120, 96), "text": "Double Jump + Trick [Ctrl] + Dash"})

	# Sekcja 4 (1520..2576): Drugi Tunel Pędu, Trampolina nad Kolcami i Checkpoint 2
	blocks.append({"name": "AutumnBank2", "pos": Vector2(1752, 328), "size": Vector2(464, 48), "type": TileType.FLOOR})
	blocks.append({"name": "SlideTunnel2", "pos": Vector2(1648, 272), "size": Vector2(128, 16), "type": TileType.TUNNEL_CEILING})
	jewels.append({"pos": Vector2(1648, 288), "cursed_mechanic": "", "jewel_type": 0})
	enemies.append({"name": "AutumnSpider2", "pos": Vector2(1824, 294), "archetype": 2, "patrol_range": 64.0, "move_speed": 46.0, "detection_radius": 145.0})
	trampolines.append({"name": "AutumnTrampoline1", "pos": Vector2(1928, 296), "bounce_velocity": -480.0})
	_add_palm_decor(decorations, 98, 19)

	hazards.append({"name": "SpikeGorge1", "pos": Vector2(2072, 324), "size": Vector2(176, 24), "kind": "spikes"})
	blocks.append({"name": "VaultPlatform", "pos": Vector2(2072, 184), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	jewels.append({"pos": Vector2(2072, 148), "cursed_mechanic": "", "jewel_type": 0})

	blocks.append({"name": "AutumnBank3", "pos": Vector2(2368, 328), "size": Vector2(416, 48), "type": TileType.FLOOR})
	checkpoints.append({"name": "Checkpoint2", "id": "CP-2", "pos": Vector2(2240, 280)})
	enemies.append({"name": "AutumnSlime2", "pos": Vector2(2416, 294), "archetype": 0, "patrol_range": 64.0, "move_speed": 42.0, "detection_radius": 135.0})
	_add_decor_tile(decorations, 145, 18, Vector2i(6, 6))
	_add_decor_tile(decorations, 157, 18, Vector2i(7, 8))

	# Sekcja 5 (2576..3456): Finałowy Przelot nad Lawą, Trampolina 2, Sekret i Wyjście
	hazards.append({"name": "LavaGauntlet", "pos": Vector2(2728, 336), "size": Vector2(304, 32), "kind": "liquid"})
	blocks.append({"name": "GauntletBridge", "pos": Vector2(2656, 288), "size": Vector2(64, 16), "type": TileType.BRIDGE})
	blocks.append({"name": "GauntletDashPad", "pos": Vector2(2800, 256), "size": Vector2(64, 16), "type": TileType.PLATFORM})
	enemies.append({"name": "AutumnBat2", "pos": Vector2(2728, 196), "archetype": 1, "patrol_range": 56.0, "move_speed": 44.0, "detection_radius": 145.0})

	blocks.append({"name": "AutumnGoalFloor", "pos": Vector2(3168, 328), "size": Vector2(576, 48), "type": TileType.FLOOR})
	trampolines.append({"name": "AutumnTrampoline2", "pos": Vector2(2960, 296), "bounce_velocity": -480.0})
	blocks.append({"name": "SecretSunsetPlat1", "pos": Vector2(3056, 176), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	blocks.append({"name": "SecretSunsetPlat2", "pos": Vector2(3168, 128), "size": Vector2(80, 16), "type": TileType.PLATFORM})
	jewels.append({
		"pos": Vector2(3168, 92),
		"cursed_mechanic": "",
		"jewel_type": 0,
		"is_secret_special": true,
		"special_id": "SEC-LVL-3",
		"special_name": "Klejnot Eteru #3",
		"special_rarity": "Legendarny"
	})
	jewels.append({"pos": Vector2(3088, 268), "cursed_mechanic": "", "jewel_type": 1}) # JEW_JEWEL
	_add_decor_column(decorations, 202, 19, [Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5)])
	_add_decor_tile(decorations, 205, 18, Vector2i(7, 6))

	blocks.append({"name": "WallRight", "pos": Vector2(3472, 160), "size": Vector2(32, 384), "type": TileType.WALL})
	hazards.append({"name": "AbyssZone", "pos": Vector2(1744, 432), "size": Vector2(4096, 48), "is_abyss": true})

	return {
		"profile_id": MechanicProfile.HORIZON_IMPULSE,
		"biome_id": BiomeId.AUTUMN,
		"respawn_pos": Vector2(72, 272),
		"finish_pos": Vector2(3344, 276),
		"level_width": 3504.0,
		"blocks": blocks,
		"hazards": hazards,
		"trampolines": trampolines,
		"checkpoints": checkpoints,
		"enemies": enemies,
		"jewels": jewels,
		"decorations": decorations,
		"labels": labels,
		"first_half_mechanic": "dash",
		"second_half_mechanic": "double_jump"
	}

# ==============================================================================
# POMOCNICZE FUNKCJE SIATKI, DEKORACJI I RENDEROWANIA TILEMAPLAYER
# ==============================================================================

static func _snap16(val: float) -> float:
	return round(val / float(TILE_SIZE)) * float(TILE_SIZE)

static func _add_decor_tile(decorations: Array[Dictionary], gx: int, gy: int, atlas: Vector2i) -> void:
	if FORBIDDEN_Q_TILES.has(atlas):
		return
	decorations.append({"cell": Vector2i(gx, gy), "atlas": atlas})

static func _add_decor_column(decorations: Array[Dictionary], gx: int, ground_row_y: int, atlas_top_to_bot: Array[Vector2i]) -> void:
	var n: int = atlas_top_to_bot.size()
	for i in range(n):
		var row_y: int = ground_row_y - (n - i)
		_add_decor_tile(decorations, gx, row_y, atlas_top_to_bot[i])

static func _find_ground_surface_row(blocks: Array[Dictionary], gx: int) -> int:
	var world_x: float = float(gx * TILE_SIZE) + 8.0
	var ground_y_top: float = INF
	for b in blocks:
		var bt: int = int(b.get("type", TileType.FLOOR))
		if bt != TileType.FLOOR:
			continue
		var pos: Vector2 = b["pos"]
		var sz: Vector2 = b["size"]
		var x0: float = pos.x - sz.x * 0.5
		var x1: float = pos.x + sz.x * 0.5
		if world_x >= x0 and world_x <= x1:
			var y_top: float = pos.y - sz.y * 0.5
			ground_y_top = min(ground_y_top, y_top)
	if ground_y_top < INF:
		return int(round(ground_y_top / float(TILE_SIZE)))
	return -1

static func _add_tree_decor(decorations: Array[Dictionary], blocks: Array[Dictionary], gx: int) -> void:
	var g_row: int = _find_ground_surface_row(blocks, gx)
	if g_row > 0:
		_add_decor_column(decorations, gx, g_row, [Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5)])

static func _add_plant_decor(decorations: Array[Dictionary], blocks: Array[Dictionary], gx: int, atlas: Vector2i) -> void:
	var g_row: int = _find_ground_surface_row(blocks, gx)
	if g_row > 0:
		_add_decor_tile(decorations, gx, g_row - 1, atlas)

static func _add_palm_decor(decorations: Array[Dictionary], gx: int, ground_row_y: int) -> void:
	_add_decor_tile(decorations, gx, ground_row_y - 1, Vector2i(3, 8))
	_add_decor_tile(decorations, gx, ground_row_y - 2, Vector2i(3, 7))
	_add_decor_tile(decorations, gx, ground_row_y - 3, Vector2i(3, 6))
	for dx in range(-1, 2):
		_add_decor_tile(decorations, gx + dx, ground_row_y - 4, Vector2i(3 + dx, 5))
		_add_decor_tile(decorations, gx + dx, ground_row_y - 5, Vector2i(3 + dx, 4))

static func _rasterize_blocks_to_logical_grid(blocks: Array[Dictionary], hazards: Array[Dictionary]) -> Dictionary:
	var grid: Dictionary = {}
	for b in blocks:
		var pos: Vector2 = b["pos"]
		var size: Vector2 = b["size"]
		var t_type: int = int(b.get("type", TileType.FLOOR))
		var top_left: Vector2 = pos - size * 0.5
		var gx_start: int = int(floor(top_left.x / float(TILE_SIZE)))
		var gy_start: int = int(floor(top_left.y / float(TILE_SIZE)))
		var gx_end: int = int(ceil((top_left.x + size.x) / float(TILE_SIZE)))
		var gy_end: int = int(ceil((top_left.y + size.y) / float(TILE_SIZE)))
		for gx in range(gx_start, gx_end):
			for gy in range(gy_start, gy_end):
				var cell_type: int = t_type
				if t_type == TileType.FLOOR and gy > gy_start:
					cell_type = TileType.FLOOR_FILL
				elif t_type == TileType.WALL and gy > gy_start:
					cell_type = TileType.WALL_FILL
				grid[Vector2i(gx, gy)] = cell_type

	# Wypełnienie logicznej siatki kafelkami FLOOR_FILL wyłącznie bezpośrednio pod litą ziemią (FLOOR/WALL)
	for b in blocks:
		var bt: int = int(b.get("type", TileType.FLOOR))
		if bt != TileType.FLOOR and bt != TileType.WALL:
			continue
		var pos: Vector2 = b["pos"]
		var size: Vector2 = b["size"]
		var top_left: Vector2 = pos - size * 0.5
		var gx_start: int = int(floor(top_left.x / float(TILE_SIZE)))
		var gy_bottom: int = int(ceil((top_left.y + size.y) / float(TILE_SIZE)))
		var gx_end: int = int(ceil((top_left.x + size.x) / float(TILE_SIZE)))
		for gx in range(gx_start, gx_end):
			for gy in range(gy_bottom, 38):
				if not grid.has(Vector2i(gx, gy)):
					grid[Vector2i(gx, gy)] = TileType.FLOOR_FILL

	for h in hazards:
		if bool(h.get("is_abyss", false)):
			continue
		var pos: Vector2 = h["pos"]
		var size: Vector2 = h["size"]
		var is_liq: bool = String(h.get("kind", "spikes")) == "liquid"
		var top_left: Vector2 = pos - size * 0.5
		var gx_start: int = int(floor(top_left.x / float(TILE_SIZE)))
		var gy_start: int = int(floor(top_left.y / float(TILE_SIZE)))
		var gx_end: int = int(ceil((top_left.x + size.x) / float(TILE_SIZE)))
		var gy_end: int = int(ceil((top_left.y + size.y) / float(TILE_SIZE)))
		for gx in range(gx_start, gx_end):
			for gy in range(gy_start, gy_end):
				grid[Vector2i(gx, gy)] = TileType.HAZARD_LIQUID if is_liq else TileType.HAZARD_SPIKE
	return grid

static func _ensure_tilemap_layer(arena_root: Node2D, layer_name: String = "LevelTileMapLayer", z_ord: int = -1, custom_tileset: TileSet = null) -> TileMapLayer:
	var layer: TileMapLayer = arena_root.get_node_or_null(layer_name) as TileMapLayer
	if not layer:
		layer = TileMapLayer.new()
		layer.name = layer_name
		arena_root.add_child(layer)
	layer.z_index = z_ord
	layer.set_meta("visual_only", true)
	if custom_tileset != null:
		layer.tile_set = custom_tileset
	return layer

static func apply_grid_to_tilemap_layer(
	tile_layer: TileMapLayer,
	logical_grid: Dictionary,
	source_id: int = 0,
	atlas_map: Dictionary = DEFAULT_ATLAS_MAP
) -> void:
	if not tile_layer or not tile_layer.tile_set:
		return
	tile_layer.clear()
	if tile_layer.tile_set.get_source_count() == 0:
		return
	var actual_source_id: int = tile_layer.tile_set.get_source_id(0) if source_id == 0 else source_id
	for coords in logical_grid.keys():
		var t_type: int = int(logical_grid[coords])
		if t_type != TileType.EMPTY and t_type != TileType.TUNNEL_CEILING and t_type != TileType.HAZARD_SPIKE and atlas_map.has(t_type):
			var atlas_coords: Vector2i = atlas_map[t_type]
			if not FORBIDDEN_Q_TILES.has(atlas_coords):
				tile_layer.set_cell(coords, actual_source_id, atlas_coords)

static func _render_biome_tilemap_layers(
	arena_root: Node2D,
	tile_layer: TileMapLayer,
	blueprint: Dictionary,
	tileset: TileSet
) -> void:
	var biome_id: int = int(blueprint.get("biome_id", BiomeId.FOREST))
	var palette: Dictionary = get_biome_palette(biome_id)
	var level_width: float = float(blueprint.get("level_width", 3200.0))

	# 1. Kolorowe tło nieba i wypełnienie dolne dopasowane do biomu (lub tło graficzne dla Lasu/Poziomu 1)
	var is_forest_with_custom_bg: bool = (biome_id == BiomeId.FOREST and ResourceLoader.exists("res://assets/Background-export.png"))
	
	if is_forest_with_custom_bg:
		var existing_bg = arena_root.get_node_or_null("Background")
		var bg_tex_rect: TextureRect = existing_bg as TextureRect
		if not bg_tex_rect:
			if existing_bg:
				existing_bg.name = "OldBackground"
				existing_bg.queue_free()
			bg_tex_rect = TextureRect.new()
			bg_tex_rect.name = "Background"
			arena_root.add_child(bg_tex_rect)
		bg_tex_rect.texture = load("res://assets/Background-export.png")
		bg_tex_rect.stretch_mode = TextureRect.STRETCH_TILE
		bg_tex_rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		bg_tex_rect.z_index = -30
		bg_tex_rect.offset_left = -400.0
		bg_tex_rect.offset_top = -450.0
		bg_tex_rect.offset_right = level_width + 600.0
		bg_tex_rect.offset_bottom = 336.0
		
		var existing_fill = arena_root.get_node_or_null("BgBottomFill")
		if existing_fill:
			existing_fill.visible = false
	else:
		var bg_rect: ColorRect = arena_root.get_node_or_null("Background") as ColorRect
		if not bg_rect:
			var old_bg = arena_root.get_node_or_null("Background")
			if old_bg:
				old_bg.name = "OldBackground"
				old_bg.queue_free()
			bg_rect = ColorRect.new()
			bg_rect.name = "Background"
			arena_root.add_child(bg_rect)
		bg_rect.z_index = -30
		bg_rect.offset_left = -400.0
		bg_rect.offset_top = -400.0
		bg_rect.offset_right = level_width + 600.0
		bg_rect.offset_bottom = 336.0
		bg_rect.color = palette["sky_color"]

		var existing_fill = arena_root.get_node_or_null("BgBottomFill")
		if existing_fill:
			existing_fill.visible = false

	# 2. Pasmowe tło krajobrazu (BgTileMapLayer, skala 2x od y=112 do y=336)
	var bg_layer: TileMapLayer = _ensure_tilemap_layer(arena_root, "BgTileMapLayer", -20, tileset)
	bg_layer.clear()
	if not is_forest_with_custom_bg:
		bg_layer.scale = Vector2(2.0, 2.0)
		bg_layer.position = Vector2(0.0, 112.0)
		bg_layer.modulate = palette["bg_modulate"]

		var bg_col: int = int(palette["bg_col"])
		if tileset != null and tileset.get_source_count() > 0:
			var src_id: int = tileset.get_source_id(0)
			var max_bg_col: int = int(ceil(level_width / 32.0)) + 16
			for gx in range(-16, max_bg_col):
				for r in range(7):
					bg_layer.set_cell(Vector2i(gx, r), src_id, Vector2i(bg_col, 9 + r))

	# 3. Warstwa dekoracji biomowych (DecorTileMapLayer)
	var decor_layer: TileMapLayer = _ensure_tilemap_layer(arena_root, "DecorTileMapLayer", -5, tileset)
	decor_layer.clear()
	if tileset != null and tileset.get_source_count() > 0:
		var src_id: int = tileset.get_source_id(0)
		for d in blueprint.get("decorations", []):
			var cell: Vector2i = d["cell"]
			var atlas: Vector2i = d["atlas"]
			if not FORBIDDEN_Q_TILES.has(atlas):
				decor_layer.set_cell(cell, src_id, atlas)

	# 4. Główna warstwa terenu (LevelTileMapLayer) oraz sufity tuneli (CeilingTileMapLayer)
	tile_layer.clear()
	tile_layer.z_index = -1
	tile_layer.set_meta("visual_only", true)

	var ceil_layer: TileMapLayer = _ensure_tilemap_layer(arena_root, "CeilingTileMapLayer", -1, tileset)
	ceil_layer.clear()
	ceil_layer.position = Vector2(0.0, 8.0)

	if tileset == null or tileset.get_source_count() == 0:
		return

	var actual_src: int = tileset.get_source_id(0)
	var bridge_tiles: Array = palette["bridge"]

	# Stemplowanie bloków
	for b in blueprint.get("blocks", []):
		var pos: Vector2 = b["pos"]
		var sz: Vector2 = b["size"]
		var bt: int = int(b.get("type", TileType.FLOOR))
		var top_left: Vector2 = pos - sz * 0.5
		var gx0: int = int(round(top_left.x / float(TILE_SIZE)))
		var gy0: int = int(round(top_left.y / float(TILE_SIZE)))
		var gw: int = max(1, int(round(sz.x / float(TILE_SIZE))))
		var gh: int = max(1, int(round(sz.y / float(TILE_SIZE))))

		if bt == TileType.TUNNEL_CEILING:
			var c_gy0: int = int(round((top_left.y - 8.0) / float(TILE_SIZE)))
			for ix in range(gw):
				for iy in range(gh):
					var c_atlas: Vector2i = palette["tunnel_ceiling"]
					if not FORBIDDEN_Q_TILES.has(c_atlas):
						ceil_layer.set_cell(Vector2i(gx0 + ix, c_gy0 + iy), actual_src, c_atlas)
			continue

		for ix in range(gw):
			for iy in range(gh):
				var atlas: Vector2i
				match bt:
					TileType.WALL:
						atlas = palette["wall_top"] if iy == 0 else palette["wall_fill"]
					TileType.PLATFORM:
						atlas = palette["platform"]
					TileType.BRIDGE:
						if ix == 0:
							atlas = bridge_tiles[0]
						elif ix == gw - 1:
							atlas = bridge_tiles[2]
						else:
							atlas = bridge_tiles[1]
					_:
						atlas = palette["floor_top"] if iy == 0 else palette["floor_fill"]
				if not FORBIDDEN_Q_TILES.has(atlas):
					tile_layer.set_cell(Vector2i(gx0 + ix, gy0 + iy), actual_src, atlas)

	# Stemplowanie cieczy (kwas / lodowa woda / lawa)
	for h in blueprint.get("hazards", []):
		if bool(h.get("is_abyss", false)):
			continue
		if String(h.get("kind", "spikes")) != "liquid":
			continue
		var pos: Vector2 = h["pos"]
		var sz: Vector2 = h["size"]
		var top_left: Vector2 = pos - sz * 0.5
		var gx0: int = int(round(top_left.x / float(TILE_SIZE)))
		var gy0: int = int(round(top_left.y / float(TILE_SIZE)))
		var gw: int = max(1, int(round(sz.x / float(TILE_SIZE))))
		var gh: int = max(1, int(round(sz.y / float(TILE_SIZE))))
		for ix in range(gw):
			for iy in range(gh):
				var liq_atlas: Vector2i = palette["liquid_top"] if iy == 0 else palette["liquid_fill"]
				if not FORBIDDEN_Q_TILES.has(liq_atlas):
					tile_layer.set_cell(Vector2i(gx0 + ix, gy0 + iy), actual_src, liq_atlas)

	# 5. Wypełnienie przestrzeni pod planszą kafelkami (floor_fill)
	# Kafelki podłoża (floor_fill) stemplujemy WYŁĄCZNIE pod blokami FLOOR i WALL,
	# aby pod litą ziemią była lita skała, a wszelkie przepaście i doły były
	# w 100% widoczne jako otwarte czeluści bez mylących tekstur, przez które gracz by spadał.
	var fill_atlas: Vector2i = palette["floor_fill"]
	if not FORBIDDEN_Q_TILES.has(fill_atlas):
		for b in blueprint.get("blocks", []):
			var bt: int = int(b.get("type", TileType.FLOOR))
			if bt != TileType.FLOOR and bt != TileType.WALL:
				continue
			var pos: Vector2 = b["pos"]
			var sz: Vector2 = b["size"]
			var top_left: Vector2 = pos - sz * 0.5
			var gx0: int = int(round(top_left.x / float(TILE_SIZE)))
			var gy0: int = int(round(top_left.y / float(TILE_SIZE)))
			var gw: int = max(1, int(round(sz.x / float(TILE_SIZE))))
			var gh: int = max(1, int(round(sz.y / float(TILE_SIZE))))
			var gy_bottom: int = gy0 + gh
			for ix in range(gw):
				for gy in range(gy_bottom, 38):
					if tile_layer.get_cell_source_id(Vector2i(gx0 + ix, gy)) == -1:
						tile_layer.set_cell(Vector2i(gx0 + ix, gy), actual_src, fill_atlas)

static func _clear_or_create_container(arena_root: Node2D, node_name: String, z_ord: int = 0) -> Node2D:
	var container: Node2D = arena_root.get_node_or_null(node_name) as Node2D
	if not container:
		container = Node2D.new()
		container.name = node_name
		arena_root.add_child(container)
	container.z_index = z_ord
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	return container

static func _apply_blueprint_to_arena(
	arena_root: Node2D,
	tile_layer: TileMapLayer,
	blueprint: Dictionary,
	custom_tileset: TileSet
) -> void:
	var geom: Node2D = _clear_or_create_container(arena_root, "Geometry", 0)
	var haz_root: Node2D = _clear_or_create_container(arena_root, "Hazards", 2)
	var cp_root: Node2D = _clear_or_create_container(arena_root, "Checkpoints", 2)
	var tramp_root: Node2D = _clear_or_create_container(arena_root, "Trampolines", 1)
	var enemy_root: Node2D = _clear_or_create_container(arena_root, "Enemies", 3)

	var labels_root: Node2D = arena_root.get_node_or_null("Labels") as Node2D
	if labels_root:
		labels_root.z_index = 6
		for child in labels_root.get_children():
			labels_root.remove_child(child)
			child.queue_free()

	# Usunięcie wcześniejszych klejnotów oraz statycznego EnemyMockup z korzenia areny
	for child in arena_root.get_children():
		var scr: Script = child.get_script()
		var scr_path: String = scr.resource_path if scr else ""
		if child.is_in_group("jewels") or scr_path.ends_with("jewel.gd") or child.name.begins_with("Jewel"):
			arena_root.remove_child(child)
			child.queue_free()
		elif child.is_in_group("enemies") or scr_path.ends_with("enemy_mockup.gd") or child.name.begins_with("EnemyMockup"):
			arena_root.remove_child(child)
			child.queue_free()

	var logical_grid: Dictionary = blueprint["logical_grid"]
	tile_layer.set_meta("logical_tile_grid", logical_grid)
	_render_biome_tilemap_layers(arena_root, tile_layer, blueprint, custom_tileset)

	var palette: Dictionary = get_biome_palette(int(blueprint.get("biome_id", BiomeId.FOREST)))
	var show_placeholder_visuals: bool = (custom_tileset == null)

	for b in blueprint["blocks"]:
		var pos: Vector2 = b["pos"]
		var sz: Vector2 = b["size"]
		var bt: int = int(b.get("type", TileType.FLOOR))
		var top_left: Vector2 = pos - sz * 0.5
		var gx0: int = int(round(top_left.x / float(TILE_SIZE)))
		var gy0: int = int(round(top_left.y / float(TILE_SIZE)))
		var gw: int = max(1, int(round(sz.x / float(TILE_SIZE))))
		var gh: int = max(1, int(round(sz.y / float(TILE_SIZE))))

		var cell_x: float = gx0 * float(TILE_SIZE)
		var cell_y: float = gy0 * float(TILE_SIZE)
		var cell_w: float = gw * float(TILE_SIZE)
		var cell_h: float = gh * float(TILE_SIZE)

		var sb := StaticBody2D.new()
		sb.name = String(b["name"])
		sb.collision_mask = 0

		var col := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()

		if bt == TileType.BRIDGE:
			# Kładka mostu w tilesecie znajduje się w wierszu 4 (4px poniżej góry komórki) i ma grubość 8-12px.
			# Ustawienie górnej krawędzi collidera dokładnie na cell_y + 4.0 eliminuje lewitację nad deskami.
			var bridge_thick: float = 12.0
			rect_shape.size = Vector2(cell_w, bridge_thick)
			sb.position = Vector2(cell_x + cell_w * 0.5, cell_y + 4.0 + bridge_thick * 0.5)
			col.one_way_collision = false
		elif bt == TileType.TUNNEL_CEILING:
			# Sufity tuneli / platformy kamienne (np. LowCeilingTunnel) w CeilTileMapLayer leżą od pos.y - sz.y*0.5 (264) do pos.y + sz.y*0.5 (280).
			# Użycie oryginalnego pos i sz zapewnia 24px prześwitu do wślizgu pod spodem oraz brak clippingu z góry.
			rect_shape.size = sz
			sb.position = pos
			col.one_way_collision = false
		elif bt == TileType.PLATFORM:
			# Solidne platformy - górna krawędź leży dokładnie na cell_y (powierzchnia trawy), eliminując lewitację i clipping.
			rect_shape.size = Vector2(cell_w, cell_h)
			sb.position = Vector2(cell_x + cell_w * 0.5, cell_y + cell_h * 0.5)
			col.one_way_collision = false
		else:
			rect_shape.size = Vector2(cell_w, cell_h)
			sb.position = Vector2(cell_x + cell_w * 0.5, cell_y + cell_h * 0.5)
			col.one_way_collision = false

		col.shape = rect_shape
		sb.add_child(col)

		if show_placeholder_visuals:
			var rect := ColorRect.new()
			if bt == TileType.BRIDGE:
				rect.position = Vector2(-cell_w * 0.5, -4.0)
				rect.size = Vector2(cell_w, 8.0)
			elif bt == TileType.TUNNEL_CEILING:
				rect.position = -sz * 0.5
				rect.size = sz
			else:
				rect.position = Vector2(-cell_w * 0.5, -cell_h * 0.5)
				rect.size = Vector2(cell_w, cell_h)
			match bt:
				TileType.WALL:
					rect.color = Color(0.24, 0.31, 0.42, 1.0)
				TileType.PLATFORM, TileType.BRIDGE:
					rect.color = Color(0.28, 0.36, 0.48, 1.0)
				TileType.TUNNEL_CEILING:
					rect.color = Color(0.33, 0.40, 0.51, 1.0)
				_:
					rect.color = Color(0.18, 0.22, 0.28, 1.0)
			sb.add_child(rect)
		geom.add_child(sb)

	for t_item in blueprint.get("trampolines", []):
		var pad: Area2D = Area2D.new()
		pad.name = String(t_item.get("name", "Trampoline"))
		pad.position = t_item["pos"]
		pad.set_script(TrampolineScript)
		pad.call("configure", palette["trampoline"], float(t_item.get("bounce_velocity", -475.0)))
		tramp_root.add_child(pad)

	for h in blueprint["hazards"]:
		var is_abyss_zone: bool = bool(h.get("is_abyss", false))
		var h_kind: String = String(h.get("kind", "spikes"))
		var area := Area2D.new()
		area.name = String(h["name"])
		area.position = h["pos"]
		area.collision_layer = 16
		area.collision_mask = 2
		area.set_script(HazardScript)
		area.set("is_abyss", is_abyss_zone)

		var col := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		var sz: Vector2 = h["size"]
		rect_shape.size = sz
		col.shape = rect_shape
		area.add_child(col)

		if not is_abyss_zone and h_kind == "spikes":
			if ResourceLoader.exists("res://assets/Kolce.png"):
				var spike_tex: Texture2D = load("res://assets/Kolce.png")
				var trect := TextureRect.new()
				trect.name = "TextureRect"
				trect.texture = spike_tex
				trect.stretch_mode = TextureRect.STRETCH_TILE
				trect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				var s_factor := 1.5
				trect.scale = Vector2(s_factor, s_factor)
				trect.position = -sz * 0.5
				trect.size = sz / s_factor
				area.add_child(trect)
			elif show_placeholder_visuals:
				var rect := ColorRect.new()
				rect.position = -sz * 0.5
				rect.size = sz
				rect.color = Color(0.78, 0.22, 0.22, 1.0)
				area.add_child(rect)
		elif show_placeholder_visuals and not is_abyss_zone:
			var rect := ColorRect.new()
			rect.position = -sz * 0.5
			rect.size = sz
			rect.color = Color(0.85, 0.28, 0.18, 0.9)
			area.add_child(rect)
		haz_root.add_child(area)

	for cp in blueprint.get("checkpoints", []):
		var cp_area := Area2D.new()
		cp_area.name = String(cp.get("name", "Checkpoint"))
		cp_area.position = cp["pos"]
		cp_area.collision_layer = 0
		cp_area.collision_mask = 2
		cp_area.set_script(CheckpointScript)
		cp_area.set("checkpoint_id", String(cp.get("id", "CP-1")))
		var cp_col := CollisionShape2D.new()
		var cp_shape := RectangleShape2D.new()
		cp_shape.size = Vector2(36, 64)
		cp_col.position = Vector2(0, -8)
		cp_col.shape = cp_shape
		cp_area.add_child(cp_col)
		cp_root.add_child(cp_area)

	var enemy_color: int = int(palette.get("enemy_color", 0))
	for en in blueprint.get("enemies", []):
		var e_inst: Area2D = EnemyScene.instantiate() as Area2D
		e_inst.name = String(en.get("name", "Enemy"))
		e_inst.position = en["pos"]
		if e_inst.has_method("configure"):
			e_inst.call(
				"configure",
				int(en.get("archetype", 0)),
				enemy_color,
				float(en.get("patrol_range", 48.0)),
				float(en.get("move_speed", 38.0)),
				float(en.get("detection_radius", 135.0))
			)
		enemy_root.add_child(e_inst)

	var j_idx: int = 0
	for j_item in blueprint["jewels"]:
		j_idx += 1
		var j_inst: Area2D = JewelScene.instantiate() as Area2D
		j_inst.name = "Jewel%d" % j_idx
		j_inst.z_index = 4
		if j_item is Dictionary:
			j_inst.position = j_item["pos"]
			var j_type: int = int(j_item.get("jewel_type", 0))
			if j_type != 0 and j_inst.has_method("set_jewel_type"):
				j_inst.call("set_jewel_type", j_type)
			var cursed_m: String = String(j_item.get("cursed_mechanic", ""))
			if not cursed_m.is_empty() and j_inst.has_method("set_cursed"):
				j_inst.call("set_cursed", cursed_m, 4.0)
			if bool(j_item.get("is_secret_special", false)) and j_inst.has_method("configure_secret_jewel"):
				j_inst.call(
					"configure_secret_jewel",
					String(j_item.get("special_id", "SEC-%d" % j_idx)),
					String(j_item.get("special_name", "Klejnot Eteru")),
					String(j_item.get("special_rarity", "Legendarny"))
				)
		elif j_item is Vector2:
			j_inst.position = j_item
		arena_root.add_child(j_inst)

	if labels_root:
		for l_info in blueprint["labels"]:
			var lbl := Label.new()
			lbl.position = l_info["pos"]
			lbl.text = String(l_info["text"])
			lbl.add_theme_constant_override("outline_size", 3)
			lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.12, 0.95))
			lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			labels_root.add_child(lbl)

	var respawn: Marker2D = arena_root.get_node_or_null("RespawnPoint")
	if respawn:
		respawn.position = blueprint["respawn_pos"]
	var player: Node2D = arena_root.get_node_or_null("Player")
	if player:
		player.position = blueprint["respawn_pos"]
		if player.has_method("set_checkpoint"):
			player.call("set_checkpoint", blueprint["respawn_pos"], "START")
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left = -64
			cam.limit_top = -120
			cam.limit_right = int(max(1850.0, blueprint["finish_pos"].x + 220.0))
			cam.limit_bottom = 440
	var finish_goal: Area2D = arena_root.get_node_or_null("FinishGoal")
	if finish_goal:
		finish_goal.position = blueprint["finish_pos"]
		finish_goal.z_index = 2
