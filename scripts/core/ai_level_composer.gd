extends RefCounted
class_name AILevelComposer

## Lokalny proceduralny kompozytor poziomów dla IV. Szachownicy AI (oparty o seed)
## oraz walidator przechodności / naprawiacz blueprintów dla wszystkich poziomów.
## Zasady:
## - Poziom 4 korzysta wyłącznie z jednego, spójnego biomu AETHER (bez podziału biomów w połowie).
## - Wszystkie kafelki z `?` są całkowicie wykluczone.
## - Ten sam `seed` daje identyczny układ mapy przy tych samych parametrach wejściowych.

const T_EMPTY: int = 0
const T_FLOOR: int = 1
const T_WALL: int = 2
const T_PLATFORM: int = 3
const T_TUNNEL_CEILING: int = 4
const T_HAZARD_SPIKE: int = 5
const T_BRIDGE: int = 6
const T_TRAMPOLINE: int = 7
const T_HAZARD_LIQUID: int = 8

const BIOME_AETHER: int = 4
const TILE_PX: float = 16.0

const FORBIDDEN_Q_TILES: Array[Vector2i] = [
	Vector2i(0, 2),
	Vector2i(3, 2),
	Vector2i(4, 2),
	Vector2i(7, 2)
]

# Dekoracje Aether (tylko bezpieczne grafiki biomu 4 — zero bloków `?`)
const AETHER_MUSHROOMS: Array[Vector2i] = [
	Vector2i(9, 2),
	Vector2i(10, 2),
	Vector2i(9, 0),
	Vector2i(10, 0)
]
const AETHER_PROPS: Array[Vector2i] = [
	Vector2i(6, 7),
	Vector2i(7, 7),
	Vector2i(6, 8),
	Vector2i(7, 8),
	Vector2i(3, 3)
]
const AETHER_SIGN: Vector2i = Vector2i(4, 3)

static func compute_difficulty_tier(challenge_reqs: Dictionary = {}) -> int:
	var tier: int = 1
	if is_instance_valid(Events):
		var done_cnt: int = Events.completed_levels.size()
		if done_cnt >= 2:
			tier = 2
		if done_cnt >= 3:
			tier = 3
		if is_instance_valid(Events.ai_director):
			var hist_sum: float = 0.0
			for m in Events.ai_director.TRACKED_MOVES:
				hist_sum += float(Events.ai_director.historical_move_uses.get(m, 0.0))
			if hist_sum >= 45.0:
				tier = maxi(tier, 2)
			if hist_sum >= 110.0:
				tier = 3
	if int(challenge_reqs.get("min_jewels", 0)) >= 8 or (float(challenge_reqs.get("max_time_s", -1.0)) > 0.0 and float(challenge_reqs.get("max_time_s", -1.0)) <= 50.0):
		tier = maxi(tier, 2)
	return clampi(tier, 1, 3)

static func compose_chessboard_level(
	rng: RandomNumberGenerator,
	fav_move: String,
	least_move: String,
	challenge_reqs: Dictionary = {},
	use_cursed: bool = false,
	difficulty_tier: int = -1
) -> Dictionary:
	var tier: int = difficulty_tier if difficulty_tier >= 1 else compute_difficulty_tier(challenge_reqs)

	var blocks: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	var trampolines: Array[Dictionary] = []
	var checkpoints: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
	var jewels: Array[Dictionary] = []
	var decorations: Array[Dictionary] = []
	var labels: Array[Dictionary] = []

	# Ściana lewa + bezpieczny podest startowy (wyrównane do siatki 16px)
	blocks.append({"name": "WallLeft", "pos": Vector2(0, 160), "size": Vector2(32, 384), "type": T_WALL})
	blocks.append({"name": "StartFloor", "pos": Vector2(160, 328), "size": Vector2(288, 48), "type": T_FLOOR})
	decorations.append({"cell": Vector2i(3, 18), "atlas": AETHER_SIGN})
	decorations.append({"cell": Vector2i(7, 18), "atlas": AETHER_MUSHROOMS[0]})
	decorations.append({"cell": Vector2i(13, 18), "atlas": AETHER_PROPS[4]})

	var respawn_pos := Vector2(72, 272)
	var cursor_x: float = 304.0

	labels.append({
		"pos": Vector2(64, 108),
		"text": "SZACHOWNICA AI [Tier %d]: 1. połowa [%s] -> 2. połowa [%s]" % [tier, fav_move.to_upper(), least_move.to_upper()]
	})

	# Wybór 3 wariantowych modułów pod ulubiony ruch (1. połowa)
	var first_half_chunks: Array[String] = _pick_chunk_sequence(rng, _pool_for_mechanic(fav_move), 3)
	# Wybór modułu regeneracji w środku trasy (+ ewentualny tunel sprinterski pod wyzwanie czasowe)
	var mid_pool: Array[String] = ["trampoline_trick_well", "high_dive_trick_well"]
	var mid_chunk: String = mid_pool[rng.randi_range(0, mid_pool.size() - 1)]
	var second_half_chunks: Array[String] = _pick_chunk_sequence(rng, _pool_for_mechanic(least_move), 3)

	var sequence: Array[String] = []
	sequence.append_array(first_half_chunks)
	var max_time_req: float = float(challenge_reqs.get("max_time_s", -1.0))
	if max_time_req > 0.0 and max_time_req <= 65.0:
		sequence.append("slide_tunnel_sprint")
	sequence.append(mid_chunk)
	sequence.append_array(second_half_chunks)

	var ctx: Dictionary = {
		"blocks": blocks,
		"hazards": hazards,
		"trampolines": trampolines,
		"checkpoints": checkpoints,
		"enemies": enemies,
		"jewels": jewels,
		"decorations": decorations,
		"labels": labels,
		"tier": tier,
		"use_cursed": use_cursed
	}

	var first_half_end_idx: int = first_half_chunks.size()
	var mid_end_idx: int = first_half_end_idx + (2 if (max_time_req > 0.0 and max_time_req <= 65.0) else 1)

	for i in range(sequence.size()):
		var chunk_id: String = sequence[i]
		var seg_num: int = i + 1
		var curse_target: String = ""
		if use_cursed:
			if i == 1:
				curse_target = fav_move
			elif i == sequence.size() - 2:
				curse_target = least_move

		cursor_x = _append_chunk(ctx, rng, chunk_id, seg_num, cursor_x, curse_target)

		if seg_num == first_half_end_idx:
			checkpoints.append({"name": "Checkpoint1", "id": "CP-1", "pos": Vector2(cursor_x - 32.0, 280.0)})
		elif seg_num == mid_end_idx + 1:
			checkpoints.append({"name": "Checkpoint2", "id": "CP-2", "pos": Vector2(cursor_x - 32.0, 280.0)})

	# Końcowy sektor z sekretnym klejnotem Eteru i wyjściem
	var goal_floor_w: float = 288.0
	blocks.append({
		"name": "ProcGoalFloor",
		"pos": Vector2(cursor_x + goal_floor_w * 0.5, 328.0),
		"size": Vector2(goal_floor_w, 48.0),
		"type": T_FLOOR
	})
	# Osiągalna półka bonusowa na sekretny klejnot Eteru
	blocks.append({
		"name": "ProcSecretStep",
		"pos": Vector2(cursor_x + 56.0, 232.0),
		"size": Vector2(64.0, 16.0),
		"type": T_PLATFORM
	})
	blocks.append({
		"name": "ProcSecretAlcove",
		"pos": Vector2(cursor_x + 128.0, 152.0),
		"size": Vector2(80.0, 16.0),
		"type": T_PLATFORM
	})
	jewels.append({
		"pos": Vector2(cursor_x + 128.0, 116.0),
		"cursed_mechanic": "",
		"jewel_type": 0,
		"is_secret_special": true,
		"special_id": "SEC-LVL-4",
		"special_name": "Klejnot Eteru #4",
		"special_rarity": "Legendarny"
	})

	_stamp_aether_decor(decorations, cursor_x + 48.0, 18, rng)
	_stamp_aether_decor(decorations, cursor_x + 176.0, 18, rng)

	var finish_pos := Vector2(cursor_x + 216.0, 276.0)
	var wall_right_x: float = cursor_x + goal_floor_w + 16.0
	blocks.append({"name": "WallRight", "pos": Vector2(wall_right_x, 160.0), "size": Vector2(32.0, 384.0), "type": T_WALL})

	# Zadania ze strony internetowej: dokładanie brakujących klejnotów na osiągalnych półkach
	var required_jewels: int = int(challenge_reqs.get("min_jewels", 0))
	var extra_idx: int = 0
	while jewels.size() < required_jewels:
		extra_idx += 1
		var jx: float = _snap16(240.0 + float(extra_idx) * 192.0)
		if jx > finish_pos.x - 96.0:
			jx = _snap16(180.0 + float((extra_idx * 96) % int(max(192.0, finish_pos.x - 280.0))))
		var jy: float = 208.0 if extra_idx % 2 == 1 else 176.0
		blocks.append({
			"name": "ChallengeBonusPad_%d" % extra_idx,
			"pos": Vector2(jx, jy + 32.0),
			"size": Vector2(64.0, 16.0),
			"type": T_PLATFORM
		})
		jewels.append({"pos": Vector2(jx, jy), "cursed_mechanic": "", "jewel_type": 0})

	var level_width: float = wall_right_x + 32.0
	hazards.append({
		"name": "AbyssZone",
		"pos": Vector2(level_width * 0.5, 432.0),
		"size": Vector2(level_width + 640.0, 48.0),
		"is_abyss": true
	})

	var blueprint: Dictionary = {
		"profile_id": 4,
		"biome_id": BIOME_AETHER,
		"respawn_pos": respawn_pos,
		"finish_pos": finish_pos,
		"level_width": level_width,
		"blocks": blocks,
		"hazards": hazards,
		"trampolines": trampolines,
		"checkpoints": checkpoints,
		"enemies": enemies,
		"jewels": jewels,
		"decorations": decorations,
		"labels": labels,
		"first_half_mechanic": fav_move,
		"second_half_mechanic": least_move,
		"challenge_max_time_s": max_time_req,
		"difficulty_tier": tier,
		"chunk_sequence": sequence
	}

	return validate_and_repair_blueprint(blueprint)

static func _pool_for_mechanic(mech: String) -> Array[String]:
	match mech:
		"wall_climb":
			return ["climb_twin_shaft", "climb_staggered_steps", "climb_trampoline_tower"]
		"dash":
			return ["dash_lava_canyon", "dash_slide_combo", "dash_bridge_gauntlet"]
		_:
			return ["dj_ascending_cascade", "dj_split_route", "dj_trampoline_vault"]

static func _pick_chunk_sequence(rng: RandomNumberGenerator, pool: Array[String], count: int) -> Array[String]:
	var result: Array[String] = []
	if pool.is_empty():
		return result
	var prev: String = ""
	for _i in range(count):
		var candidates: Array[String] = []
		for item in pool:
			if item != prev or pool.size() == 1:
				candidates.append(item)
		var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
		result.append(chosen)
		prev = chosen
	return result

static func _snap16(val: float) -> float:
	return round(val / TILE_PX) * TILE_PX

static func _stamp_aether_decor(decorations: Array[Dictionary], world_x: float, row_y: int, rng: RandomNumberGenerator) -> void:
	var gx: int = int(round(world_x / TILE_PX))
	var pool: Array[Vector2i] = []
	pool.append_array(AETHER_MUSHROOMS)
	pool.append_array(AETHER_PROPS)
	var chosen: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
	decorations.append({"cell": Vector2i(gx, row_y), "atlas": chosen})

static func _append_chunk(
	ctx: Dictionary,
	rng: RandomNumberGenerator,
	chunk_id: String,
	seg_num: int,
	x0: float,
	curse_mech: String
) -> float:
	var blocks: Array[Dictionary] = ctx["blocks"]
	var hazards: Array[Dictionary] = ctx["hazards"]
	var trampolines: Array[Dictionary] = ctx["trampolines"]
	var enemies: Array[Dictionary] = ctx["enemies"]
	var jewels: Array[Dictionary] = ctx["jewels"]
	var decorations: Array[Dictionary] = ctx["decorations"]
	var tier: int = int(ctx["tier"])

	var pwr_type: int = 0
	if seg_num == 3:
		pwr_type = 2 # SPEED_JEWEL
	elif seg_num == 5 and rng.randf() < 0.65:
		pwr_type = 3 # IMMUNITY_JEWEL

	match chunk_id:
		"climb_twin_shaft":
			var w: float = 304.0
			blocks.append({"name": "Floor_%d" % seg_num, "pos": Vector2(x0 + w * 0.5, 328.0), "size": Vector2(w, 48.0), "type": T_FLOOR})
			blocks.append({"name": "ShaftL_%d" % seg_num, "pos": Vector2(x0 + 72.0, 168.0), "size": Vector2(16.0, 160.0), "type": T_WALL})
			blocks.append({"name": "ShaftR_%d" % seg_num, "pos": Vector2(x0 + 152.0, 208.0), "size": Vector2(16.0, 192.0), "type": T_WALL})
			var top_y: float = 120.0 if rng.randi_range(0, 1) == 0 else 136.0
			blocks.append({"name": "ShaftTop_%d" % seg_num, "pos": Vector2(x0 + 216.0, top_y), "size": Vector2(80.0, 16.0), "type": T_PLATFORM})
			jewels.append({"pos": Vector2(x0 + 216.0, top_y - 32.0), "cursed_mechanic": curse_mech, "jewel_type": pwr_type})
			enemies.append({
				"name": "Enemy_%d" % seg_num,
				"pos": Vector2(x0 + 224.0, 294.0),
				"archetype": 0 if tier == 1 else 2,
				"patrol_range": 48.0,
				"move_speed": 36.0 + tier * 6.0,
				"detection_radius": 120.0 + tier * 12.0
			})
			_stamp_aether_decor(decorations, x0 + 32.0, 18, rng)
			return x0 + w

		"climb_staggered_steps":
			var gap_w: float = 80.0 if tier == 1 else 96.0
			var b1_w: float = 112.0
			var b2_w: float = 144.0
			blocks.append({"name": "StepBankA_%d" % seg_num, "pos": Vector2(x0 + b1_w * 0.5, 328.0), "size": Vector2(b1_w, 48.0), "type": T_FLOOR})
			hazards.append({"name": "LiqPit_%d" % seg_num, "pos": Vector2(x0 + b1_w + gap_w * 0.5, 336.0), "size": Vector2(gap_w, 32.0), "kind": "liquid"})
			var b2_x0: float = x0 + b1_w + gap_w
			blocks.append({"name": "StepBankB_%d" % seg_num, "pos": Vector2(b2_x0 + b2_w * 0.5, 328.0), "size": Vector2(b2_w, 48.0), "type": T_FLOOR})
			blocks.append({"name": "MidStep_%d" % seg_num, "pos": Vector2(x0 + b1_w + gap_w * 0.5, 240.0), "size": Vector2(48.0, 16.0), "type": T_PLATFORM})
			blocks.append({"name": "TallWall_%d" % seg_num, "pos": Vector2(b2_x0 + 40.0, 184.0), "size": Vector2(16.0, 128.0), "type": T_WALL})
			blocks.append({"name": "WallCap_%d" % seg_num, "pos": Vector2(b2_x0 + 72.0, 128.0), "size": Vector2(64.0, 16.0), "type": T_PLATFORM})
			jewels.append({"pos": Vector2(b2_x0 + 72.0, 92.0), "cursed_mechanic": curse_mech, "jewel_type": pwr_type})
			if tier >= 2:
				enemies.append({
					"name": "EnemyBat_%d" % seg_num,
					"pos": Vector2(x0 + b1_w + gap_w * 0.5, 168.0),
					"archetype": 1,
					"patrol_range": 40.0,
					"move_speed": 38.0 + tier * 5.0,
					"detection_radius": 135.0
				})
			_stamp_aether_decor(decorations, x0 + 32.0, 18, rng)
			return b2_x0 + b2_w

		"climb_trampoline_tower":
			var w: float = 288.0
			blocks.append({"name": "TowerFloor_%d" % seg_num, "pos": Vector2(x0 + w * 0.5, 328.0), "size": Vector2(w, 48.0), "type": T_FLOOR})
			trampolines.append({"name": "Trampoline_%d" % seg_num, "pos": Vector2(x0 + 64.0, 296.0), "bounce_velocity": -475.0})
			blocks.append({"name": "TowerWall_%d" % seg_num, "pos": Vector2(x0 + 136.0, 144.0), "size": Vector2(16.0, 160.0), "type": T_WALL})
			blocks.append({"name": "TowerLedge_%d" % seg_num, "pos": Vector2(x0 + 208.0, 104.0), "size": Vector2(80.0, 16.0), "type": T_PLATFORM})
			jewels.append({"pos": Vector2(x0 + 208.0, 68.0), "cursed_mechanic": curse_mech, "jewel_type": pwr_type})
			enemies.append({
				"name": "Enemy_%d" % seg_num,
				"pos": Vector2(x0 + 208.0, 294.0),
				"archetype": 0,
				"patrol_range": 48.0,
				"move_speed": 35.0 + tier * 5.0,
				"detection_radius": 120.0
			})
			_stamp_aether_decor(decorations, x0 + 256.0, 18, rng)
			return x0 + w

		"dash_lava_canyon":
			var bank1_w: float = 96.0
			var pit_w: float = float(rng.randi_range(6, 8)) * 16.0 # 96..128 px
			var bank2_w: float = 112.0
			blocks.append({"name": "DashBankA_%d" % seg_num, "pos": Vector2(x0 + bank1_w * 0.5, 328.0), "size": Vector2(bank1_w, 48.0), "type": T_FLOOR})
			hazards.append({"name": "DashLava_%d" % seg_num, "pos": Vector2(x0 + bank1_w + pit_w * 0.5, 336.0), "size": Vector2(pit_w, 32.0), "kind": "liquid"})
			var b2_x0: float = x0 + bank1_w + pit_w
			blocks.append({"name": "DashBankB_%d" % seg_num, "pos": Vector2(b2_x0 + bank2_w * 0.5, 328.0), "size": Vector2(bank2_w, 48.0), "type": T_FLOOR})
			jewels.append({"pos": Vector2(x0 + bank1_w + pit_w * 0.5, 252.0), "cursed_mechanic": curse_mech, "jewel_type": pwr_type})
			enemies.append({
				"name": "Enemy_%d" % seg_num,
				"pos": Vector2(b2_x0 + 56.0, 294.0),
				"archetype": 2 if tier >= 2 else 0,
				"patrol_range": 32.0,
				"move_speed": 38.0 + tier * 6.0,
				"detection_radius": 130.0
			})
			_stamp_aether_decor(decorations, x0 + 32.0, 18, rng)
			return b2_x0 + bank2_w

		"dash_slide_combo":
			var tun_w: float = 208.0
			var pit_w: float = 96.0 if tier == 1 else 112.0
			var land_w: float = 96.0
			blocks.append({"name": "TunFloor_%d" % seg_num, "pos": Vector2(x0 + tun_w * 0.5, 328.0), "size": Vector2(tun_w, 48.0), "type": T_FLOOR})
			blocks.append({"name": "TunCeil_%d" % seg_num, "pos": Vector2(x0 + 96.0, 272.0), "size": Vector2(112.0, 16.0), "type": T_TUNNEL_CEILING})
			jewels.append({"pos": Vector2(x0 + 96.0, 288.0), "cursed_mechanic": "", "jewel_type": 0})
			hazards.append({"name": "SlideSpikes_%d" % seg_num, "pos": Vector2(x0 + tun_w + pit_w * 0.5, 324.0), "size": Vector2(pit_w, 24.0), "kind": "spikes"})
			var land_x0: float = x0 + tun_w + pit_w
			blocks.append({"name": "SlideLand_%d" % seg_num, "pos": Vector2(land_x0 + land_w * 0.5, 328.0), "size": Vector2(land_w, 48.0), "type": T_FLOOR})
			jewels.append({"pos": Vector2(x0 + tun_w + pit_w * 0.5, 252.0), "cursed_mechanic": curse_mech, "jewel_type": pwr_type})
			_stamp_aether_decor(decorations, land_x0 + 48.0, 18, rng)
			return land_x0 + land_w

		"dash_bridge_gauntlet":
			var bank_w: float = 80.0
			var sea_w: float = 240.0
			blocks.append({"name": "BridgeBankA_%d" % seg_num, "pos": Vector2(x0 + bank_w * 0.5, 328.0), "size": Vector2(bank_w, 48.0), "type": T_FLOOR})
			var sea_x0: float = x0 + bank_w
			hazards.append({"name": "BridgeSea_%d" % seg_num, "pos": Vector2(sea_x0 + sea_w * 0.5, 336.0), "size": Vector2(sea_w, 32.0), "kind": "liquid"})
			blocks.append({"name": "Bridge1_%d" % seg_num, "pos": Vector2(sea_x0 + 56.0, 296.0), "size": Vector2(64.0, 16.0), "type": T_BRIDGE})
			var b2_y: float = 280.0 if rng.randi_range(0, 1) == 0 else 296.0
			blocks.append({"name": "Bridge2_%d" % seg_num, "pos": Vector2(sea_x0 + 184.0, b2_y), "size": Vector2(64.0, 16.0), "type": T_BRIDGE})
			jewels.append({"pos": Vector2(sea_x0 + 120.0, 244.0), "cursed_mechanic": curse_mech, "jewel_type": pwr_type})
			enemies.append({
				"name": "EnemyBat_%d" % seg_num,
				"pos": Vector2(sea_x0 + 120.0, 200.0),
				"archetype": 1,
				"patrol_range": 48.0,
				"move_speed": 40.0 + tier * 5.0,
				"detection_radius": 140.0
			})
			var bank2_x0: float = sea_x0 + sea_w
			blocks.append({"name": "BridgeBankB_%d" % seg_num, "pos": Vector2(bank2_x0 + bank_w * 0.5, 328.0), "size": Vector2(bank_w, 48.0), "type": T_FLOOR})
			return bank2_x0 + bank_w

		"dj_ascending_cascade":
			var bank1_w: float = 112.0
			var pit_w: float = 96.0
			var bank2_w: float = 128.0
			blocks.append({"name": "CascadeA_%d" % seg_num, "pos": Vector2(x0 + bank1_w * 0.5, 328.0), "size": Vector2(bank1_w, 48.0), "type": T_FLOOR})
			hazards.append({"name": "CascadeSpikes_%d" % seg_num, "pos": Vector2(x0 + bank1_w + pit_w * 0.5, 324.0), "size": Vector2(pit_w, 24.0), "kind": "spikes"})
			var b2_x0: float = x0 + bank1_w + pit_w
			blocks.append({"name": "CascadeB_%d" % seg_num, "pos": Vector2(b2_x0 + bank2_w * 0.5, 328.0), "size": Vector2(bank2_w, 48.0), "type": T_FLOOR})
			blocks.append({"name": "Step1_%d" % seg_num, "pos": Vector2(x0 + 144.0, 248.0), "size": Vector2(64.0, 16.0), "type": T_PLATFORM})
			blocks.append({"name": "Step2_%d" % seg_num, "pos": Vector2(b2_x0 + 32.0, 168.0), "size": Vector2(80.0, 16.0), "type": T_PLATFORM})
			jewels.append({"pos": Vector2(b2_x0 + 32.0, 132.0), "cursed_mechanic": curse_mech, "jewel_type": pwr_type})
			enemies.append({
				"name": "Enemy_%d" % seg_num,
				"pos": Vector2(b2_x0 + 64.0, 294.0),
				"archetype": 0,
				"patrol_range": 40.0,
				"move_speed": 36.0 + tier * 5.0,
				"detection_radius": 120.0
			})
			_stamp_aether_decor(decorations, x0 + 48.0, 18, rng)
			return b2_x0 + bank2_w

		"dj_split_route":
			var w: float = 304.0
			blocks.append({"name": "SplitFloor_%d" % seg_num, "pos": Vector2(x0 + w * 0.5, 328.0), "size": Vector2(w, 48.0), "type": T_FLOOR})
			blocks.append({"name": "SplitLowPlat_%d" % seg_num, "pos": Vector2(x0 + 88.0, 232.0), "size": Vector2(64.0, 16.0), "type": T_PLATFORM})
			blocks.append({"name": "SplitHighPlat_%d" % seg_num, "pos": Vector2(x0 + 200.0, 152.0), "size": Vector2(80.0, 16.0), "type": T_PLATFORM})
			jewels.append({"pos": Vector2(x0 + 200.0, 116.0), "cursed_mechanic": curse_mech, "jewel_type": pwr_type})
			enemies.append({
				"name": "EnemyGround_%d" % seg_num,
				"pos": Vector2(x0 + 160.0, 294.0),
				"archetype": 2,
				"patrol_range": 64.0,
				"move_speed": 40.0 + tier * 6.0,
				"detection_radius": 140.0
			})
			_stamp_aether_decor(decorations, x0 + 32.0, 18, rng)
			_stamp_aether_decor(decorations, x0 + 256.0, 18, rng)
			return x0 + w

		"dj_trampoline_vault":
			var bank1_w: float = 112.0
			var pit_w: float = 112.0
			var bank2_w: float = 112.0
			blocks.append({"name": "VaultA_%d" % seg_num, "pos": Vector2(x0 + bank1_w * 0.5, 328.0), "size": Vector2(bank1_w, 48.0), "type": T_FLOOR})
			trampolines.append({"name": "Trampoline_%d" % seg_num, "pos": Vector2(x0 + 88.0, 296.0), "bounce_velocity": -475.0})
			hazards.append({"name": "VaultLava_%d" % seg_num, "pos": Vector2(x0 + bank1_w + pit_w * 0.5, 336.0), "size": Vector2(pit_w, 32.0), "kind": "liquid"})
			blocks.append({"name": "VaultSky_%d" % seg_num, "pos": Vector2(x0 + bank1_w + pit_w * 0.5, 168.0), "size": Vector2(80.0, 16.0), "type": T_PLATFORM})
			jewels.append({"pos": Vector2(x0 + bank1_w + pit_w * 0.5, 132.0), "cursed_mechanic": curse_mech, "jewel_type": pwr_type})
			var b2_x0: float = x0 + bank1_w + pit_w
			blocks.append({"name": "VaultB_%d" % seg_num, "pos": Vector2(b2_x0 + bank2_w * 0.5, 328.0), "size": Vector2(bank2_w, 48.0), "type": T_FLOOR})
			return b2_x0 + bank2_w

		"trampoline_trick_well":
			var w: float = 288.0
			blocks.append({"name": "WellFloor_%d" % seg_num, "pos": Vector2(x0 + w * 0.5, 328.0), "size": Vector2(w, 48.0), "type": T_FLOOR})
			trampolines.append({"name": "WellTramp_%d" % seg_num, "pos": Vector2(x0 + 56.0, 296.0), "bounce_velocity": -480.0})
			blocks.append({"name": "WellHigh_%d" % seg_num, "pos": Vector2(x0 + 136.0, 168.0), "size": Vector2(64.0, 16.0), "type": T_PLATFORM})
			jewels.append({"pos": Vector2(x0 + 216.0, 196.0), "cursed_mechanic": "", "jewel_type": 0})
			_stamp_aether_decor(decorations, x0 + 240.0, 18, rng)
			return x0 + w

		"high_dive_trick_well":
			var w: float = 288.0
			blocks.append({"name": "DiveFloor_%d" % seg_num, "pos": Vector2(x0 + w * 0.5, 328.0), "size": Vector2(w, 48.0), "type": T_FLOOR})
			blocks.append({"name": "DiveStep_%d" % seg_num, "pos": Vector2(x0 + 56.0, 232.0), "size": Vector2(64.0, 16.0), "type": T_PLATFORM})
			blocks.append({"name": "DivePlat_%d" % seg_num, "pos": Vector2(x0 + 144.0, 152.0), "size": Vector2(80.0, 16.0), "type": T_PLATFORM})
			jewels.append({"pos": Vector2(x0 + 224.0, 200.0), "cursed_mechanic": "", "jewel_type": 0})
			_stamp_aether_decor(decorations, x0 + 160.0, 18, rng)
			return x0 + w

		_:
			# "slide_tunnel_sprint"
			var w: float = 256.0
			blocks.append({"name": "SprintFloor_%d" % seg_num, "pos": Vector2(x0 + w * 0.5, 328.0), "size": Vector2(w, 48.0), "type": T_FLOOR})
			blocks.append({"name": "SprintCeil_%d" % seg_num, "pos": Vector2(x0 + 128.0, 272.0), "size": Vector2(112.0, 16.0), "type": T_TUNNEL_CEILING})
			jewels.append({"pos": Vector2(x0 + 128.0, 288.0), "cursed_mechanic": "", "jewel_type": 2})
			_stamp_aether_decor(decorations, x0 + 32.0, 18, rng)
			return x0 + w

# ==============================================================================
# WALIDATOR PRZECHODNOŚCI I NAPRAWIACZ BLUEPRINTÓW
# ==============================================================================

static func validate_and_repair_blueprint(blueprint: Dictionary) -> Dictionary:
	var blocks: Array[Dictionary] = blueprint.get("blocks", [])
	var hazards: Array[Dictionary] = blueprint.get("hazards", [])
	var trampolines: Array[Dictionary] = blueprint.get("trampolines", [])
	var checkpoints: Array[Dictionary] = blueprint.get("checkpoints", [])
	var enemies: Array[Dictionary] = blueprint.get("enemies", [])
	var jewels: Array[Dictionary] = blueprint.get("jewels", [])
	var decorations: Array[Dictionary] = blueprint.get("decorations", [])

	var repairs: int = 0

	# 1. Usunięcie ewentualnych zakazanych kafelków `?` z dekoracji
	var clean_decor: Array[Dictionary] = []
	for d in decorations:
		var atlas: Vector2i = d.get("atlas", Vector2i(-1, -1))
		if not FORBIDDEN_Q_TILES.has(atlas):
			clean_decor.append(d)
		else:
			repairs += 1
	blueprint["decorations"] = clean_decor

	# 2. Weryfikacja prześwitu pod tunelami do wślizgu (min 24px nad podłogą)
	for b in blocks:
		if int(b.get("type", T_FLOOR)) != T_TUNNEL_CEILING:
			continue
		var c_pos: Vector2 = b["pos"]
		var c_sz: Vector2 = b["size"]
		var c_x0: float = c_pos.x - c_sz.x * 0.5
		var c_x1: float = c_pos.x + c_sz.x * 0.5
		var floor_top_below: float = INF
		for f in blocks:
			var ft: int = int(f.get("type", T_FLOOR))
			if ft != T_FLOOR and ft != T_PLATFORM and ft != T_BRIDGE:
				continue
			var f_pos: Vector2 = f["pos"]
			var f_sz: Vector2 = f["size"]
			var f_x0: float = f_pos.x - f_sz.x * 0.5
			var f_x1: float = f_pos.x + f_sz.x * 0.5
			if min(c_x1, f_x1) > max(c_x0, f_x0):
				var f_top: float = f_pos.y - f_sz.y * 0.5
				if f_top > c_pos.y:
					floor_top_below = min(floor_top_below, f_top)
		if floor_top_below < INF:
			var max_ceil_bottom: float = floor_top_below - 24.0
			var cur_bottom: float = c_pos.y + c_sz.y * 0.5
			if cur_bottom > max_ceil_bottom:
				c_pos.y = max_ceil_bottom - c_sz.y * 0.5
				b["pos"] = c_pos
				repairs += 1

	# 3. Sprawdzenie przechodności od StartFloor do FinishGoal (BFS z naprawą luk)
	var respawn_pos: Vector2 = blueprint.get("respawn_pos", Vector2(72, 272))
	var finish_pos: Vector2 = blueprint.get("finish_pos", Vector2(1600, 276))

	for _attempt in range(12):
		var surfaces: Array[Dictionary] = _extract_walkable_surfaces(blocks)
		if surfaces.is_empty():
			break

		var start_idx: int = _find_surface_near_x(surfaces, respawn_pos.x)
		var goal_idx: int = _find_surface_near_x(surfaces, finish_pos.x)
		if start_idx == -1 or goal_idx == -1:
			break

		var reachable: Array[bool] = _compute_reachable_surfaces(surfaces, blocks, trampolines, start_idx)
		if reachable[goal_idx]:
			break

		# Naprawa najbliższej luki blokującej postęp w prawo
		var best_r: int = start_idx
		for idx in range(surfaces.size()):
			if reachable[idx] and float(surfaces[idx]["x1"]) > float(surfaces[best_r]["x1"]):
				best_r = idx

		var next_u: int = -1
		var best_dist: float = INF
		for idx in range(surfaces.size()):
			if reachable[idx]:
				continue
			var s_u: Dictionary = surfaces[idx]
			if float(s_u["x1"]) <= float(surfaces[best_r]["x0"]):
				continue
			var d: float = max(0.0, float(s_u["x0"]) - float(surfaces[best_r]["x1"]))
			if d < best_dist:
				best_dist = d
				next_u = idx

		if next_u == -1:
			break

		var surf_r: Dictionary = surfaces[best_r]
		var surf_u: Dictionary = surfaces[next_u]
		var gap_x: float = max(0.0, float(surf_u["x0"]) - float(surf_r["x1"]))
		var rise_y: float = float(surf_r["y_top"]) - float(surf_u["y_top"])

		repairs += 1
		if gap_x > 144.0:
			var mid_x: float = _snap16((float(surf_r["x1"]) + float(surf_u["x0"])) * 0.5)
			var mid_y: float = _snap16(clampf(min(float(surf_r["y_top"]), float(surf_u["y_top"])) + 8.0, 128.0, 296.0))
			blocks.append({
				"name": "ValidatorBridge_%d" % repairs,
				"pos": Vector2(mid_x, mid_y),
				"size": Vector2(64.0, 16.0),
				"type": T_BRIDGE
			})
		elif rise_y > 80.0:
			var step_x: float = _snap16(clampf((float(surf_r["x1"]) + float(surf_u["x0"])) * 0.5, float(surf_r["x0"]) + 32.0, float(surf_u["x1"]) - 32.0))
			var step_y: float = _snap16((float(surf_r["y_top"]) + float(surf_u["y_top"])) * 0.5)
			blocks.append({
				"name": "ValidatorStep_%d" % repairs,
				"pos": Vector2(step_x, step_y),
				"size": Vector2(64.0, 16.0),
				"type": T_PLATFORM
			})
		else:
			var fallback_x: float = _snap16(float(surf_r["x1"]) + 48.0)
			var fallback_y: float = _snap16(min(float(surf_r["y_top"]), float(surf_u["y_top"])))
			blocks.append({
				"name": "ValidatorPad_%d" % repairs,
				"pos": Vector2(fallback_x, fallback_y),
				"size": Vector2(64.0, 16.0),
				"type": T_PLATFORM
			})

	# 4. Odsunięcie klejnotów, checkpointów i wrogów kolidujących z pełnymi blokami
	var solid_rects: Array[Rect2] = []
	for b in blocks:
		var bp: Vector2 = b["pos"]
		var bs: Vector2 = b["size"]
		solid_rects.append(Rect2(bp - bs * 0.5, bs))

	for j in jewels:
		var jp: Vector2 = j["pos"]
		for r in solid_rects:
			if r.grow(4.0).has_point(jp):
				jp.y = r.position.y - 20.0
				j["pos"] = jp
				repairs += 1

	for cp in checkpoints:
		var cp_p: Vector2 = cp["pos"]
		for r in solid_rects:
			if r.has_point(cp_p):
				cp_p.y = r.position.y - 24.0
				cp["pos"] = cp_p
				repairs += 1

	for en in enemies:
		var ep: Vector2 = en["pos"]
		for r in solid_rects:
			if r.has_point(ep):
				ep.y = r.position.y - 10.0
				en["pos"] = ep
				repairs += 1

	# 5. Gwarancja strefy przepaści na całej szerokości mapy
	var max_x: float = float(blueprint.get("level_width", finish_pos.x + 256.0))
	var has_abyss: bool = false
	for h in hazards:
		if bool(h.get("is_abyss", false)):
			h["pos"] = Vector2(max_x * 0.5, 432.0)
			h["size"] = Vector2(max_x + 640.0, 48.0)
			has_abyss = true
			break
	if not has_abyss:
		hazards.append({
			"name": "AbyssZone",
			"pos": Vector2(max_x * 0.5, 432.0),
			"size": Vector2(max_x + 640.0, 48.0),
			"is_abyss": true
		})

	var final_surfaces: Array[Dictionary] = _extract_walkable_surfaces(blocks)
	var final_start: int = _find_surface_near_x(final_surfaces, respawn_pos.x)
	var final_goal: int = _find_surface_near_x(final_surfaces, finish_pos.x)
	var goal_reached: bool = false
	if final_start != -1 and final_goal != -1:
		var final_reach: Array[bool] = _compute_reachable_surfaces(final_surfaces, blocks, trampolines, final_start)
		goal_reached = final_reach[final_goal]

	blueprint["validation"] = {
		"passed": goal_reached,
		"repairs": repairs,
		"difficulty_tier": int(blueprint.get("difficulty_tier", 1)),
		"chunk_sequence": blueprint.get("chunk_sequence", [])
	}
	return blueprint

static func _extract_walkable_surfaces(blocks: Array[Dictionary]) -> Array[Dictionary]:
	var surfaces: Array[Dictionary] = []
	for b in blocks:
		var bname: String = String(b.get("name", ""))
		if bname == "WallLeft" or bname == "WallRight":
			continue
		var bt: int = int(b.get("type", T_FLOOR))
		if bt == T_TUNNEL_CEILING:
			continue
		var pos: Vector2 = b["pos"]
		var sz: Vector2 = b["size"]
		var x0: float = pos.x - sz.x * 0.5
		var x1: float = pos.x + sz.x * 0.5
		var y_top: float = pos.y - sz.y * 0.5
		if bt == T_WALL and y_top < 80.0:
			continue
		surfaces.append({
			"x0": x0,
			"x1": x1,
			"y_top": y_top,
			"is_wall": (bt == T_WALL)
		})
	surfaces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["x0"]) < float(b["x0"])
	)
	return surfaces

static func _find_surface_near_x(surfaces: Array[Dictionary], x_pos: float) -> int:
	var best_idx: int = -1
	var best_score: float = INF
	for i in range(surfaces.size()):
		var s: Dictionary = surfaces[i]
		var dist: float = 0.0
		if x_pos < float(s["x0"]):
			dist = float(s["x0"]) - x_pos
		elif x_pos > float(s["x1"]):
			dist = x_pos - float(s["x1"])
		var score: float = dist + (0.0 if not bool(s["is_wall"]) else 100.0)
		if score < best_score:
			best_score = score
			best_idx = i
	return best_idx

static func _compute_reachable_surfaces(
	surfaces: Array[Dictionary],
	blocks: Array[Dictionary],
	trampolines: Array[Dictionary],
	start_idx: int
) -> Array[bool]:
	var n: int = surfaces.size()
	var visited: Array[bool] = []
	visited.resize(n)
	visited.fill(false)
	if start_idx < 0 or start_idx >= n:
		return visited

	var climb_walls: Array[Dictionary] = []
	for b in blocks:
		if int(b.get("type", T_FLOOR)) == T_WALL:
			var sz: Vector2 = b["size"]
			if sz.y >= 80.0:
				var p: Vector2 = b["pos"]
				climb_walls.append({"x": p.x, "y_top": p.y - sz.y * 0.5, "y_bot": p.y + sz.y * 0.5})

	var queue: Array[int] = [start_idx]
	visited[start_idx] = true

	while not queue.is_empty():
		var cur_i: int = queue.pop_front()
		var a: Dictionary = surfaces[cur_i]
		var a_x0: float = float(a["x0"])
		var a_x1: float = float(a["x1"])
		var a_y: float = float(a["y_top"])

		var has_tramp: bool = false
		for t in trampolines:
			var tp: Vector2 = t["pos"]
			if tp.x >= a_x0 - 16.0 and tp.x <= a_x1 + 16.0 and abs(tp.y - (a_y - 8.0)) <= 24.0:
				has_tramp = true
				break

		var has_climb: bool = bool(a["is_wall"])
		if not has_climb:
			for cw in climb_walls:
				if float(cw["x"]) >= a_x0 - 88.0 and float(cw["x"]) <= a_x1 + 88.0 and float(cw["y_bot"]) >= a_y - 64.0:
					has_climb = true
					break

		for nxt_i in range(n):
			if visited[nxt_i]:
				continue
			var b: Dictionary = surfaces[nxt_i]
			var b_x0: float = float(b["x0"])
			var b_x1: float = float(b["x1"])
			var b_y: float = float(b["y_top"])

			var gap_x: float = max(0.0, max(b_x0 - a_x1, a_x0 - b_x1))
			var rise_y: float = a_y - b_y

			var max_gap: float = 192.0 if not has_tramp else 224.0
			if rise_y <= 0.0:
				max_gap = 216.0 # Zeskok w dół daje większy zasięg poziomy

			var max_rise: float = 96.0
			if has_tramp:
				max_rise = max(max_rise, 160.0)
			if has_climb:
				max_rise = max(max_rise, 192.0)
				max_gap = max(max_gap, 176.0)

			if gap_x <= max_gap and rise_y <= max_rise:
				visited[nxt_i] = true
				queue.append(nxt_i)

	return visited
