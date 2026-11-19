extends RefCounted
class_name ProceduralLevelGenerator

## Generator Poziomów AI z obsługą:
## 1. "Żywiołów Ruchu" (Trials of Flow: Synergia, Ascent, Momentum, Aether / Szachownica AI)
## 2. "Szachownicy Stylu Gracza" (Pierwsza połowa pod ulubiony ruch gracza -> podbicie ceny staminy -> druga połowa pod najrzadziej używany ruch)
## 3. "Niestabilnych Klejnotów" (Cursed Jewels) dla Kontraktu AI
## 4. Zadań z Aplikacji Webowej (dynamiczne dostosowanie liczby klejnotów `min_klejnotow`, limitu czasu `max_czas_s` oraz sekcji specjalnych)
## 5. Integracji pod przyszły TileSet (TileMapLayer)

const HazardScript = preload("res://scripts/core/hazard_area.gd")
const JewelScene = preload("res://scenes/Jewel.tscn")

enum MechanicProfile {
	SYNERGY_CLASSIC = 1,  ## I. SYNERGIA RUCHU (Flow: balans wszystkich mechanik)
	VERTICAL_ASCENT = 2,  ## II. SEKTOR PIONOWY: ASCENT (Wall Climb & głębokie studnie Air Trick)
	HORIZON_IMPULSE = 3,  ## III. SEKTOR IMPULSU: MOMENTUM (Tunele Slide -> szerokie przepaście Dash)
	AI_PROCEDURAL = 4     ## IV. SEKTOR AETHER: SZACHOWNICA AI (Kontra stylu gracza + Zadania z Portalu)
}

enum TileType {
	EMPTY = 0,
	FLOOR = 1,
	WALL = 2,
	PLATFORM = 3,
	TUNNEL_CEILING = 4,
	HAZARD_SPIKE = 5
}

const TILE_SIZE: int = 16

const DEFAULT_ATLAS_MAP: Dictionary = {
	TileType.FLOOR: Vector2i(0, 0),
	TileType.WALL: Vector2i(1, 0),
	TileType.PLATFORM: Vector2i(2, 0),
	TileType.TUNNEL_CEILING: Vector2i(3, 0),
	TileType.HAZARD_SPIKE: Vector2i(0, 1)
}

## Zwraca metadane sektora ruchu oraz jego bazowy rozkład DNA Mechanik dla Level Select.
static func get_profile_metadata(profile_id: int) -> Dictionary:
	match profile_id:
		MechanicProfile.SYNERGY_CLASSIC:
			return {
				"id": 1,
				"title": "I. SYNERGIA RUCHU (FLOW)",
				"subtitle": "Balans: Climb + Dash + Double Jump",
				"dominant": "balanced",
				"dna": {"wall_climb": 33, "dash": 33, "double_jump": 34},
				"description": "Zrównoważony tor łączący szyby wspinaczkowe, niskie tunele i przepaście. Idealny do nauki rotacji staminy."
			}
		MechanicProfile.VERTICAL_ASCENT:
			return {
				"id": 2,
				"title": "II. SEKTOR PIONOWY (ASCENT)",
				"subtitle": "Żywioł: Wall Climb & Studnie Tricków",
				"dominant": "wall_climb",
				"dna": {"wall_climb": 54, "dash": 18, "double_jump": 28},
				"description": "Wysokie kominy wspinaczkowe i głębokie studnie powietrzne. Ładuj staminę długim Trickiem [C] podczas spadków."
			}
		MechanicProfile.HORIZON_IMPULSE:
			return {
				"id": 3,
				"title": "III. SEKTOR IMPULSU (MOMENTUM)",
				"subtitle": "Żywioł: Slide -> Air Dash & Double Jump",
				"dominant": "dash",
				"dna": {"wall_climb": 14, "dash": 52, "double_jump": 34},
				"description": "Długie proste z niskimi sufitami przechodzące w szerokie kaniony kolców. Utrzymuj pęd poziomy!"
			}
		_:
			var fav: String = "double_jump"
			var least: String = "wall_climb"
			if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
				fav = Events.ai_director.get_favorite_move()
				least = Events.ai_director.get_least_used_move()
			return {
				"id": 4,
				"title": "IV. AETHER: SZACHOWNICA AI",
				"subtitle": "1. połowa: %s -> 2. połowa: %s" % [fav.to_upper(), least.to_upper()],
				"dominant": least,
				"dna": {"wall_climb": 35, "dash": 30, "double_jump": 35},
				"description": "Przeciwstawny Generator AI: 1. połowa podbija cenę Twojego ulubionego ruchu, a 2. połowa wymaga najtańszej mechaniki oraz realizuje zadania z portalu!"
			}

## Buduje poziom dla wybranego profilu wewnątrz węzła areny, uwzględniając aktywne zadania ze strony internetowej.
static func build_level_for_arena(
	arena_root: Node2D,
	profile_id: int,
	seed_val: int = 0,
	custom_tileset: TileSet = null,
	force_regenerate: bool = false,
	override_challenge_reqs: Dictionary = {}
) -> Dictionary:
	var tile_layer: TileMapLayer = _ensure_tilemap_layer(arena_root, custom_tileset)
	var challenge_reqs: Dictionary = override_challenge_reqs
	if challenge_reqs.is_empty() and is_instance_valid(Events) and is_instance_valid(Events.portal_sync):
		challenge_reqs = Events.portal_sync.get_aggregated_challenge_requirements()
		
	if profile_id == MechanicProfile.SYNERGY_CLASSIC and not force_regenerate:
		# Jeśli zadanie na stronie wymaga więcej klejnotów niż jest na scenie klasycznej, dołóż brakujące klejnoty!
		var min_req_jewels: int = int(challenge_reqs.get("min_jewels", 0))
		var extra_spawned: int = _ensure_minimum_jewels_on_existing_arena(arena_root, min_req_jewels)
		_apply_cursed_contract_to_existing_jewels(arena_root)
		
		var synced_grid: Dictionary = _extract_logical_grid_from_geometry(arena_root)
		tile_layer.set_meta("logical_tile_grid", synced_grid)
		if custom_tileset != null:
			apply_grid_to_tilemap_layer(tile_layer, synced_grid)
		return {
			"profile_id": profile_id,
			"tile_count": synced_grid.size(),
			"extra_challenge_jewels": extra_spawned,
			"challenge_max_time_s": float(challenge_reqs.get("max_time_s", -1.0)),
			"generated": false
		}
		
	var rng := RandomNumberGenerator.new()
	if seed_val != 0:
		rng.seed = seed_val
	else:
		rng.seed = int(Time.get_unix_time_from_system()) + profile_id * 7919
		
	var blueprint: Dictionary = generate_blueprint(profile_id, rng, challenge_reqs)
	_apply_blueprint_to_arena(arena_root, tile_layer, blueprint, custom_tileset)
	
	return {
		"profile_id": profile_id,
		"seed": rng.seed,
		"tile_count": (blueprint["logical_grid"] as Dictionary).size(),
		"jewel_count": (blueprint["jewels"] as Array).size(),
		"challenge_max_time_s": float(blueprint.get("challenge_max_time_s", -1.0)),
		"first_half_mechanic": String(blueprint.get("first_half_mechanic", "")),
		"second_half_mechanic": String(blueprint.get("second_half_mechanic", "")),
		"generated": true
	}

## Generuje kompletny plan poziomu z uwzględnieniem "Szachownicy Stylu Gracza" oraz Zadań ze Strony Webowej!
static func generate_blueprint(profile_id: int, rng: RandomNumberGenerator, challenge_reqs: Dictionary = {}) -> Dictionary:
	var blocks: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	var jewels: Array[Dictionary] = [] # {"pos": Vector2, "cursed_mechanic": String}
	var labels: Array[Dictionary] = []
	
	blocks.append({"name": "WallLeft", "pos": Vector2(0, 160), "size": Vector2(32, 360), "type": TileType.WALL})
	blocks.append({"name": "StartFloor", "pos": Vector2(160, 320), "size": Vector2(280, 32), "type": TileType.FLOOR})
	
	var cursor_x: float = 300.0
	var respawn_pos := Vector2(70, 270)
	var finish_pos := Vector2(1640, 276)
	var first_half_mech: String = "balanced"
	var second_half_mech: String = "balanced"
	
	var use_cursed: bool = false
	if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
		use_cursed = (Events.ai_director.active_contract == AdaptiveAIDirector.ContractMode.CURSED_JEWELS)
		
	if profile_id == MechanicProfile.VERTICAL_ASCENT:
		first_half_mech = "wall_climb"
		second_half_mech = "wall_climb"
		# --- PROFIL 2: SEKTOR PIONOWY (ASCENT: Wall Climb + Studnie Tricków) ---
		blocks.append({"name": "ClimbShaft1L", "pos": Vector2(160, 200), "size": Vector2(16, 170), "type": TileType.WALL})
		blocks.append({"name": "ClimbShaft1R", "pos": Vector2(235, 190), "size": Vector2(16, 190), "type": TileType.WALL})
		blocks.append({"name": "ClimbTopLedge1", "pos": Vector2(285, 110), "size": Vector2(84, 16), "type": TileType.PLATFORM})
		jewels.append({"pos": Vector2(285, 78), "cursed_mechanic": "wall_climb" if use_cursed else ""})
		labels.append({"pos": Vector2(140, 68), "text": "ASCENT: Wspinaczka [W] -> Studnia Tricków [C]"})
		
		blocks.append({"name": "DropLandingFloor", "pos": Vector2(520, 320), "size": Vector2(360, 32), "type": TileType.FLOOR})
		hazards.append({"name": "SpikesDropPit", "pos": Vector2(320, 324), "size": Vector2(40, 24)})
		jewels.append({"pos": Vector2(410, 195), "cursed_mechanic": ""})
		labels.append({"pos": Vector2(355, 135), "text": "Studnia Powietrzna: Trzymaj [C] -> REGEN STAMINY!"})
		
		blocks.append({"name": "TowerWall1", "pos": Vector2(560, 210), "size": Vector2(16, 180), "type": TileType.WALL})
		blocks.append({"name": "TowerWall2", "pos": Vector2(640, 165), "size": Vector2(16, 190), "type": TileType.WALL})
		blocks.append({"name": "TowerHighPlat", "pos": Vector2(720, 100), "size": Vector2(90, 16), "type": TileType.PLATFORM})
		jewels.append({"pos": Vector2(720, 68), "cursed_mechanic": "wall_climb" if use_cursed else ""})
		
		blocks.append({"name": "MidAirPlat", "pos": Vector2(920, 210), "size": Vector2(100, 16), "type": TileType.PLATFORM})
		blocks.append({"name": "MidFloor", "pos": Vector2(1050, 320), "size": Vector2(320, 32), "type": TileType.FLOOR})
		hazards.append({"name": "SpikesMidGap", "pos": Vector2(800, 324), "size": Vector2(160, 24)})
		jewels.append({"pos": Vector2(920, 175), "cursed_mechanic": ""})
		
		blocks.append({"name": "FinalClimbWall", "pos": Vector2(1140, 205), "size": Vector2(16, 190), "type": TileType.WALL})
		blocks.append({"name": "FinalHighLedge", "pos": Vector2(1240, 130), "size": Vector2(110, 16), "type": TileType.PLATFORM})
		jewels.append({"pos": Vector2(1240, 96), "cursed_mechanic": "double_jump" if use_cursed else ""})
		
		blocks.append({"name": "GoalFloor", "pos": Vector2(1500, 320), "size": Vector2(400, 32), "type": TileType.FLOOR})
		blocks.append({"name": "WallRight", "pos": Vector2(1700, 160), "size": Vector2(32, 360), "type": TileType.WALL})
		cursor_x = 1500.0
		finish_pos = Vector2(1620, 276)
		
	elif profile_id == MechanicProfile.HORIZON_IMPULSE:
		first_half_mech = "dash"
		second_half_mech = "double_jump"
		# --- PROFIL 3: SEKTOR IMPULSU (MOMENTUM: Slide -> Dash -> Double Jump) ---
		hazards.append({"name": "CanyonSpikes1", "pos": Vector2(370, 324), "size": Vector2(130, 24)})
		blocks.append({"name": "DashFloor1", "pos": Vector2(610, 320), "size": Vector2(340, 32), "type": TileType.FLOOR})
		jewels.append({"pos": Vector2(370, 245), "cursed_mechanic": "dash" if use_cursed else ""})
		labels.append({"pos": Vector2(315, 200), "text": "MOMENTUM: Skok + Dash [Shift] nad kanionem"})
		
		blocks.append({"name": "SlideTunnel", "pos": Vector2(610, 270), "size": Vector2(170, 20), "type": TileType.TUNNEL_CEILING})
		jewels.append({"pos": Vector2(610, 292), "cursed_mechanic": ""})
		labels.append({"pos": Vector2(545, 232), "text": "Tunel Pędu: Wślizg [S] -> Wybicie"})
		
		hazards.append({"name": "CanyonSpikes2", "pos": Vector2(960, 324), "size": Vector2(340, 24)})
		blocks.append({"name": "SkyPad1", "pos": Vector2(850, 230), "size": Vector2(84, 16), "type": TileType.PLATFORM})
		blocks.append({"name": "SkyPad2", "pos": Vector2(1010, 155), "size": Vector2(84, 16), "type": TileType.PLATFORM})
		blocks.append({"name": "SkyPad3", "pos": Vector2(1185, 155), "size": Vector2(84, 16), "type": TileType.PLATFORM})
		jewels.append({"pos": Vector2(1010, 120), "cursed_mechanic": "double_jump" if use_cursed else ""})
		jewels.append({"pos": Vector2(1100, 115), "cursed_mechanic": ""})
		labels.append({"pos": Vector2(940, 75), "text": "Aether: Double Jump + Trick [C] + Dash"})
		
		blocks.append({"name": "FinalSprintFloor", "pos": Vector2(1440, 320), "size": Vector2(500, 32), "type": TileType.FLOOR})
		blocks.append({"name": "SprintHighLedge", "pos": Vector2(1430, 220), "size": Vector2(96, 16), "type": TileType.PLATFORM})
		jewels.append({"pos": Vector2(1430, 185), "cursed_mechanic": ""})
		blocks.append({"name": "WallRight", "pos": Vector2(1700, 160), "size": Vector2(32, 360), "type": TileType.WALL})
		cursor_x = 1440.0
		finish_pos = Vector2(1630, 276)
		
	else:
		# --- PROFIL 4: SZACHOWNICA STYLU GRACZA (Counter-Playstyle AI + Zadania ze Strony) ---
		var fav_move: String = "double_jump"
		var least_move: String = "wall_climb"
		if is_instance_valid(Events) and is_instance_valid(Events.ai_director):
			fav_move = Events.ai_director.get_favorite_move()
			least_move = Events.ai_director.get_least_used_move()
			
		# Jeśli zadanie na stronie wymusza konkretną mechanikę, ustawiamy ją jako finałowe wyzwanie
		var focus_list: Array = challenge_reqs.get("focus_mechanics", [])
		if not focus_list.is_empty():
			least_move = String(focus_list[0])
			
		first_half_mech = fav_move
		second_half_mech = least_move
		
		labels.append({
			"pos": Vector2(120, 85),
			"text": "SZACHOWNICA AI: I połowa [%s] podbija koszt -> II połowa [%s] ma zniżkę staminy!" % [fav_move.to_upper(), least_move.to_upper()]
		})
		
		# Budujemy 2 segmenty pod ulubiony ruch gracza (I połowa), potem studnię regeneracji Tricków,
		# a następnie 2 segmenty pod najrzadziej używany ruch (II połowa)!
		var planned_segments: Array[String] = [
			_mechanic_to_segment_type(fav_move),
			_mechanic_to_segment_type(fav_move),
			"trick_drop",
			_mechanic_to_segment_type(least_move),
			_mechanic_to_segment_type(least_move)
		]
		
		# Jeśli na stronie aktywne jest szybkie wyzwanie czasowe (Mistrz czasu), dokładamy odcinek sprinterski Slide+Dash
		var max_time_req: float = float(challenge_reqs.get("max_time_s", -1.0))
		if max_time_req > 0.0 and max_time_req <= 65.0:
			planned_segments.insert(2, "slide_tunnel")
			
		var seg_idx: int = 0
		for seg in planned_segments:
			seg_idx += 1
			var is_cursed_seg: bool = use_cursed and (seg_idx == 2 or seg_idx == 5)
			match seg:
				"climb_shaft":
					blocks.append({"name": "ProcFloor_%d" % seg_idx, "pos": Vector2(cursor_x + 120, 320), "size": Vector2(240, 32), "type": TileType.FLOOR})
					blocks.append({"name": "ProcShaftL_%d" % seg_idx, "pos": Vector2(cursor_x + 70, 205), "size": Vector2(16, 175), "type": TileType.WALL})
					blocks.append({"name": "ProcShaftR_%d" % seg_idx, "pos": Vector2(cursor_x + 145, 205), "size": Vector2(16, 175), "type": TileType.WALL})
					jewels.append({"pos": Vector2(cursor_x + 108, 125), "cursed_mechanic": "wall_climb" if is_cursed_seg else ""})
					cursor_x += 240.0
				"dash_gap":
					hazards.append({"name": "ProcSpikes_%d" % seg_idx, "pos": Vector2(cursor_x + 55, 324), "size": Vector2(110, 24)})
					blocks.append({"name": "ProcLanding_%d" % seg_idx, "pos": Vector2(cursor_x + 210, 320), "size": Vector2(200, 32), "type": TileType.FLOOR})
					jewels.append({"pos": Vector2(cursor_x + 55, 250), "cursed_mechanic": "dash" if is_cursed_seg else ""})
					cursor_x += 310.0
				"double_jump_cascade":
					blocks.append({"name": "ProcBase_%d" % seg_idx, "pos": Vector2(cursor_x + 140, 320), "size": Vector2(280, 32), "type": TileType.FLOOR})
					blocks.append({"name": "ProcStep1_%d" % seg_idx, "pos": Vector2(cursor_x + 80, 230), "size": Vector2(80, 16), "type": TileType.PLATFORM})
					blocks.append({"name": "ProcStep2_%d" % seg_idx, "pos": Vector2(cursor_x + 195, 145), "size": Vector2(85, 16), "type": TileType.PLATFORM})
					jewels.append({"pos": Vector2(cursor_x + 195, 110), "cursed_mechanic": "double_jump" if is_cursed_seg else ""})
					cursor_x += 280.0
				"slide_tunnel":
					blocks.append({"name": "ProcTunFloor_%d" % seg_idx, "pos": Vector2(cursor_x + 120, 320), "size": Vector2(240, 32), "type": TileType.FLOOR})
					blocks.append({"name": "ProcTunCeil_%d" % seg_idx, "pos": Vector2(cursor_x + 120, 270), "size": Vector2(140, 20), "type": TileType.TUNNEL_CEILING})
					jewels.append({"pos": Vector2(cursor_x + 120, 290), "cursed_mechanic": ""})
					cursor_x += 240.0
				"trick_drop":
					blocks.append({"name": "ProcDropFloor_%d" % seg_idx, "pos": Vector2(cursor_x + 130, 320), "size": Vector2(260, 32), "type": TileType.FLOOR})
					blocks.append({"name": "ProcHighDive_%d" % seg_idx, "pos": Vector2(cursor_x + 70, 165), "size": Vector2(80, 16), "type": TileType.PLATFORM})
					jewels.append({"pos": Vector2(cursor_x + 170, 210), "cursed_mechanic": ""})
					cursor_x += 260.0
					
		blocks.append({"name": "ProcGoalFloor", "pos": Vector2(cursor_x + 120, 320), "size": Vector2(240, 32), "type": TileType.FLOOR})
		finish_pos = Vector2(cursor_x + 165, 276)
		blocks.append({"name": "WallRight", "pos": Vector2(cursor_x + 240, 160), "size": Vector2(32, 360), "type": TileType.WALL})
		
	# --- INTEGRACJA Z ZADANIAMI ZE STRONY INTERNETOWEJ ---
	# Jeśli aktywne zadanie ze strony wymaga np. min_klejnotow = 7, a wygenerowano mniej,
	# dokładamy dodatkowe półki z klejnotami, aby gracz mógł ukończyć zadanie z portalu!
	var required_jewels: int = int(challenge_reqs.get("min_jewels", 0))
	var extra_idx: int = 0
	while jewels.size() < required_jewels:
		extra_idx += 1
		var jx: float = 220.0 + float(extra_idx) * 165.0
		var jy: float = 185.0 - float(extra_idx % 2) * 35.0
		blocks.append({
			"name": "ChallengeBonusPad_%d" % extra_idx,
			"pos": Vector2(jx, jy + 28.0),
			"size": Vector2(64, 16),
			"type": TileType.PLATFORM
		})
		jewels.append({"pos": Vector2(jx, jy), "cursed_mechanic": ""})
		
	var logical_grid: Dictionary = _rasterize_blocks_to_logical_grid(blocks, hazards)
	
	return {
		"profile_id": profile_id,
		"respawn_pos": respawn_pos,
		"finish_pos": finish_pos,
		"blocks": blocks,
		"hazards": hazards,
		"jewels": jewels,
		"labels": labels,
		"logical_grid": logical_grid,
		"first_half_mechanic": first_half_mech,
		"second_half_mechanic": second_half_mech,
		"challenge_max_time_s": float(challenge_reqs.get("max_time_s", -1.0))
	}

static func _mechanic_to_segment_type(mech: String) -> String:
	match mech:
		"wall_climb":
			return "climb_shaft"
		"dash":
			return "dash_gap"
		_:
			return "double_jump_cascade"

static func _ensure_minimum_jewels_on_existing_arena(arena_root: Node2D, min_required: int) -> int:
	if min_required <= 0:
		return 0
	var existing_count: int = 0
	for child in arena_root.get_children():
		var scr: Script = child.get_script()
		var scr_path: String = scr.resource_path if scr else ""
		if child.is_in_group("jewels") or scr_path.ends_with("jewel.gd") or child.name.begins_with("Jewel"):
			existing_count += 1
	var added: int = 0
	while existing_count + added < min_required:
		added += 1
		var j_inst: Area2D = JewelScene.instantiate() as Area2D
		j_inst.name = "JewelChallengeExtra%d" % added
		j_inst.position = Vector2(280.0 + float(added) * 180.0, 225.0)
		arena_root.add_child(j_inst)
	return added

static func _apply_cursed_contract_to_existing_jewels(arena_root: Node2D) -> void:
	if not is_instance_valid(Events) or not is_instance_valid(Events.ai_director):
		return
	var is_cursed_mode: bool = (Events.ai_director.active_contract == AdaptiveAIDirector.ContractMode.CURSED_JEWELS)
	var idx: int = 0
	var mechanics: Array[String] = ["double_jump", "wall_climb", "dash"]
	for child in arena_root.get_children():
		if child.has_method("set_cursed"):
			if is_cursed_mode and idx % 2 == 0:
				child.call("set_cursed", mechanics[idx % mechanics.size()], 4.0)
			else:
				child.call("set_cursed", "", 0.0)
			idx += 1

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
				grid[Vector2i(gx, gy)] = t_type
				
	for h in hazards:
		var pos: Vector2 = h["pos"]
		var size: Vector2 = h["size"]
		var top_left: Vector2 = pos - size * 0.5
		var gx_start: int = int(floor(top_left.x / float(TILE_SIZE)))
		var gy_start: int = int(floor(top_left.y / float(TILE_SIZE)))
		var gx_end: int = int(ceil((top_left.x + size.x) / float(TILE_SIZE)))
		var gy_end: int = int(ceil((top_left.y + size.y) / float(TILE_SIZE)))
		for gx in range(gx_start, gx_end):
			for gy in range(gy_start, gy_end):
				grid[Vector2i(gx, gy)] = TileType.HAZARD_SPIKE
	return grid

static func _extract_logical_grid_from_geometry(arena_root: Node2D) -> Dictionary:
	var blocks: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	var geom: Node = arena_root.get_node_or_null("Geometry")
	if geom:
		for child in geom.get_children():
			if child is StaticBody2D:
				for c in child.get_children():
					if c is CollisionShape2D and c.shape is RectangleShape2D:
						var sz: Vector2 = (c.shape as RectangleShape2D).size
						var t_type: int = TileType.WALL if sz.y > sz.x else TileType.FLOOR
						blocks.append({"pos": child.position, "size": sz, "type": t_type})
	var haz_root: Node = arena_root.get_node_or_null("Hazards")
	if haz_root:
		for child in haz_root.get_children():
			if child is Area2D:
				for c in child.get_children():
					if c is CollisionShape2D and c.shape is RectangleShape2D:
						var sz: Vector2 = (c.shape as RectangleShape2D).size
						hazards.append({"pos": child.position, "size": sz})
	return _rasterize_blocks_to_logical_grid(blocks, hazards)

static func _ensure_tilemap_layer(arena_root: Node2D, custom_tileset: TileSet = null) -> TileMapLayer:
	var layer: TileMapLayer = arena_root.get_node_or_null("LevelTileMapLayer") as TileMapLayer
	if not layer:
		layer = TileMapLayer.new()
		layer.name = "LevelTileMapLayer"
		arena_root.add_child(layer)
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
		if t_type != TileType.EMPTY and atlas_map.has(t_type):
			tile_layer.set_cell(coords, actual_source_id, atlas_map[t_type])

static func _apply_blueprint_to_arena(
	arena_root: Node2D,
	tile_layer: TileMapLayer,
	blueprint: Dictionary,
	custom_tileset: TileSet
) -> void:
	var geom: Node2D = arena_root.get_node_or_null("Geometry")
	if not geom:
		geom = Node2D.new()
		geom.name = "Geometry"
		arena_root.add_child(geom)
	for child in geom.get_children():
		geom.remove_child(child)
		child.queue_free()
		
	var haz_root: Node2D = arena_root.get_node_or_null("Hazards")
	if not haz_root:
		haz_root = Node2D.new()
		haz_root.name = "Hazards"
		arena_root.add_child(haz_root)
	for child in haz_root.get_children():
		haz_root.remove_child(child)
		child.queue_free()
		
	var labels_root: Node2D = arena_root.get_node_or_null("Labels")
	if labels_root:
		for child in labels_root.get_children():
			labels_root.remove_child(child)
			child.queue_free()
			
	for child in arena_root.get_children():
		var scr: Script = child.get_script()
		var scr_path: String = scr.resource_path if scr else ""
		if child.is_in_group("jewels") or scr_path.ends_with("jewel.gd") or child.name.begins_with("Jewel"):
			arena_root.remove_child(child)
			child.queue_free()
			
	var logical_grid: Dictionary = blueprint["logical_grid"]
	tile_layer.set_meta("logical_tile_grid", logical_grid)
	if custom_tileset != null:
		apply_grid_to_tilemap_layer(tile_layer, logical_grid)
		
	var show_placeholder_visuals: bool = (custom_tileset == null)
	for b in blueprint["blocks"]:
		var sb := StaticBody2D.new()
		sb.name = String(b["name"])
		sb.position = b["pos"]
		sb.collision_mask = 0
		
		var col := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		var sz: Vector2 = b["size"]
		rect_shape.size = sz
		col.shape = rect_shape
		sb.add_child(col)
		
		if show_placeholder_visuals:
			var rect := ColorRect.new()
			rect.position = -sz * 0.5
			rect.size = sz
			var t_type: int = int(b.get("type", TileType.FLOOR))
			match t_type:
				TileType.WALL:
					rect.color = Color(0.24, 0.31, 0.42, 1.0)
				TileType.PLATFORM:
					rect.color = Color(0.28, 0.36, 0.48, 1.0)
				TileType.TUNNEL_CEILING:
					rect.color = Color(0.33, 0.40, 0.51, 1.0)
				_:
					rect.color = Color(0.18, 0.22, 0.28, 1.0)
			sb.add_child(rect)
		geom.add_child(sb)
		
	for h in blueprint["hazards"]:
		var area := Area2D.new()
		area.name = String(h["name"])
		area.position = h["pos"]
		area.collision_layer = 16
		area.collision_mask = 2
		area.set_script(HazardScript)
		
		var col := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		var sz: Vector2 = h["size"]
		rect_shape.size = sz
		col.shape = rect_shape
		area.add_child(col)
		
		if show_placeholder_visuals:
			if ResourceLoader.exists("res://assets/Kolce.png"):
				var spike_tex = load("res://assets/Kolce.png")
				var trect := TextureRect.new()
				trect.texture = spike_tex
				trect.stretch_mode = TextureRect.STRETCH_TILE
				trect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				var s_factor := 1.5
				trect.scale = Vector2(s_factor, s_factor)
				trect.position = -sz * 0.5
				trect.size = sz / s_factor
				area.add_child(trect)
			else:
				var rect := ColorRect.new()
				rect.position = -sz * 0.5
				rect.size = sz
				rect.color = Color(0.78, 0.22, 0.22, 1.0)
				area.add_child(rect)
		haz_root.add_child(area)
		
	var j_idx: int = 0
	for j_item in blueprint["jewels"]:
		j_idx += 1
		var j_inst: Area2D = JewelScene.instantiate() as Area2D
		j_inst.name = "Jewel%d" % j_idx
		if j_item is Dictionary:
			j_inst.position = j_item["pos"]
			var cursed_m: String = String(j_item.get("cursed_mechanic", ""))
			if not cursed_m.is_empty() and j_inst.has_method("set_cursed"):
				j_inst.call("set_cursed", cursed_m, 4.0)
		elif j_item is Vector2:
			j_inst.position = j_item
		arena_root.add_child(j_inst)
		
	if labels_root:
		for l_info in blueprint["labels"]:
			var lbl := Label.new()
			lbl.position = l_info["pos"]
			lbl.text = String(l_info["text"])
			labels_root.add_child(lbl)
			
	var respawn: Marker2D = arena_root.get_node_or_null("RespawnPoint")
	if respawn:
		respawn.position = blueprint["respawn_pos"]
	var player: Node2D = arena_root.get_node_or_null("Player")
	if player:
		player.position = blueprint["respawn_pos"]
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_right = int(max(1850.0, blueprint["finish_pos"].x + 220.0))
	var finish_goal: Area2D = arena_root.get_node_or_null("FinishGoal")
	if finish_goal:
		finish_goal.position = blueprint["finish_pos"]
