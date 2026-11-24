extends RefCounted
class_name AILevelComposer

## Kompozytor poziomu IV (Cyber Matrix / Szachownica AI) z modułów LevelModules sterowany profilem stylu gry
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

const GridLevelScript = preload("res://scripts/core/grid_level.gd")

## Pule modułów biblioteki LevelModules per mechanika: [id_modułu, poziom trudności]
const MODULE_POOLS: Dictionary = {
	"double_jump": [["dj_ledges", 1], ["trampoline_tower", 1], ["dj_islands", 2], ["dash_leap", 2]],
	"dash": [["dash_corridor", 1], ["dash_leap_short", 1], ["dash_leap", 2]],
	"wall_climb": [["climb_wall", 1], ["climb_wall_high", 2], ["chimney", 2]],
	"wall_jump": [["chimney", 2]],
	"slide": [["slide_crawl", 1]],
	"trick": [["trick_well", 1]],
	"trampoline": [["trampoline_tower", 1], ["trick_well", 1]]
}
## Rozwidlenia: mechaniki sprawdzane na obu trasach
const FORKS: Dictionary = {
	"fork_hill": {"tier": 2, "mech": ["wall_climb", "slide", "dash", "double_jump"]},
	"fork_glacier": {"tier": 2, "mech": ["wall_climb", "slide", "dash", "double_jump", "trampoline"]},
	"fork_furnace": {"tier": 2, "mech": ["wall_climb", "trampoline", "slide", "dash", "double_jump"]},
	"fork_sky": {"tier": 3, "mech": ["wall_jump", "wall_climb", "slide", "dash", "double_jump"]},
	"fork_canopy": {"tier": 3, "mech": ["trampoline", "slide", "dash", "double_jump", "wall_climb"]}
}
const MECH_LABELS: Dictionary = {
	"double_jump": "PODWÓJNY SKOK", "dash": "DASH", "wall_climb": "WSPINACZKA", "wall_jump": "WALL JUMP",
	"slide": "WŚLIZG", "trick": "TRICKI", "trampoline": "TRAMPOLINY"
}

## Profil stylu gry z PlayStyleProfiler (pusty słownik, gdy brak danych).
static func get_player_profile() -> Dictionary:
	if is_instance_valid(Events) and "playstyle_profiler" in Events and is_instance_valid(Events.playstyle_profiler):
		return Events.playstyle_profiler.get_profile()
	return {}

static func compute_difficulty_tier(challenge_reqs: Dictionary = {}, profile: Dictionary = {}) -> int:
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
	# Umiejętności z profilu: wysoka skuteczność podnosi, częste błędy obniżają poziom
	if bool(profile.get("has_data", false)):
		var skill: float = float(profile.get("skill", 0.5))
		if skill >= 0.72:
			tier += 1
		elif skill <= 0.35:
			tier -= 1
	if int(challenge_reqs.get("min_jewels", 0)) >= 8 or (float(challenge_reqs.get("max_time_s", -1.0)) > 0.0 and float(challenge_reqs.get("max_time_s", -1.0)) <= 50.0):
		tier = maxi(tier, 2)
	return clampi(tier, 1, 3)

static func _pick_module(rng: RandomNumberGenerator, mech: String, max_tier: int, avoid: Array) -> String:
	var pool: Array = MODULE_POOLS.get(mech, MODULE_POOLS["double_jump"])
	var cands: Array[String] = []
	for entry in pool:
		if int(entry[1]) <= max_tier and not avoid.has(String(entry[0])):
			cands.append(String(entry[0]))
	if cands.is_empty():
		for entry in pool:
			if int(entry[1]) <= max_tier:
				cands.append(String(entry[0]))
	if cands.is_empty():
		cands.append(String(pool[0][0]))
	return cands[rng.randi_range(0, cands.size() - 1)]

static func _pick_fork(rng: RandomNumberGenerator, train: Array, max_tier: int, avoid: Array) -> String:
	var best: Array[String] = []
	var best_score: float = -1.0
	var ids: Array = FORKS.keys()
	ids.sort()
	for fid in ids:
		var f: Dictionary = FORKS[fid]
		if int(f["tier"]) > max_tier or avoid.has(fid):
			continue
		var score: float = 0.0
		for i in range(train.size()):
			if (f["mech"] as Array).has(train[i]):
				score += float(train.size() - i)
		if score > best_score + 0.01:
			best_score = score
			best = [String(fid)]
		elif absf(score - best_score) <= 0.01:
			best.append(String(fid))
	if best.is_empty():
		return "fork_hill"
	return best[rng.randi_range(0, best.size() - 1)]

## IV. Cyber Matrix / Szachownica AI: poziom składany z tych samych modułów co poziomy 2–3,
## dobranych na podstawie analizy stylu gry (PlayStyleProfiler + historia Reżysera AI):
##  1. rozgrzewka na ULUBIONYM ruchu (1. połowa – first_half_mechanic),
##  2. rozwidlenie dobrane pod mechaniki, które gracz zaniedbuje lub z którymi ma kłopot,
##  3. blok treningowy UNIKANEGO ruchu z rosnącą trudnością (2. połowa – second_half_mechanic),
##     poprzedzony tarczą w hubie, gdy profil pokazuje dużo błędów w tej mechanice,
##  4. moduł na mechanikę z najwyższym wskaźnikiem błędów spoza trójki (wślizg, wall jump...),
##  5. finał: drugie, trudniejsze rozwidlenie dla wprawnych graczy albo spokojniejsze domknięcie.
static func compose_chessboard_level(
	rng: RandomNumberGenerator,
	fav_move: String,
	least_move: String,
	challenge_reqs: Dictionary = {},
	use_cursed: bool = false,
	difficulty_tier: int = -1
) -> Dictionary:
	var profile: Dictionary = get_player_profile()
	var has_profile: bool = bool(profile.get("has_data", false))
	var tier: int = difficulty_tier if difficulty_tier >= 1 else compute_difficulty_tier(challenge_reqs, profile)
	var reasons: Array[String] = []
	var plan: Array[String] = ["start"]
	var used: Array = []

	# 1. Rozgrzewka – ulubiony ruch
	var warm_count: int = 2 if tier >= 2 else 1
	for _i in range(warm_count):
		var m1: String = _pick_module(rng, fav_move, mini(tier, 2), used)
		plan.append(m1)
		used.append(m1)
	reasons.append("Rozgrzewka: %s (Twój ulubiony ruch)" % MECH_LABELS.get(fav_move, fav_move))
	plan.append("hub")

	# 2. Rozwidlenie dobrane pod zaniedbane / problematyczne mechaniki
	var train: Array = [least_move]
	var weakest: String = String(profile.get("weakest", ""))
	if not weakest.is_empty() and not train.has(weakest):
		train.append(weakest)
	var ranked: Array = profile.get("ranked_mechanics", [])
	for i in range(ranked.size() - 1, -1, -1):
		if not train.has(ranked[i]):
			train.append(ranked[i])
		if train.size() >= 4:
			break
	var fork1: String = _pick_fork(rng, train, mini(tier + 1, 3), [])
	plan.append(fork1)
	var risk: float = float(profile.get("risk_appetite", 0.5))
	if has_profile and risk < 0.4:
		reasons.append("Rozwidlenie: sekretny klejnot czeka na górnej trasie, którą zwykle omijasz")
	elif has_profile and risk > 0.65:
		reasons.append("Rozwidlenie: lubisz ryzykowne trasy - dolna też kryje nagrody")
	else:
		reasons.append("Rozwidlenie: obie trasy sprawdzają %s" % MECH_LABELS.get(least_move, least_move))

	# 3. Oddech + regeneracja staminy (tricki), jeśli gracz rzadko trickuje
	var shares: Dictionary = profile.get("usage_shares", {})
	if not has_profile or float(shares.get("trick", 0.0)) < 0.08:
		plan.append("trick_well")
		var trick_txt: String = Events.format_keybind_text("Studnia tricków: trzymaj [{trick}] w locie, by odzyskać staminę", "pl") if is_instance_valid(Events) else "Studnia tricków: trzymaj [Ctrl] w locie, by odzyskać staminę"
		reasons.append(trick_txt)
	else:
		plan.append(_pick_module(rng, "trampoline", 1, used))

	# Wyzwanie czasowe z portalu: dodatkowy sprinterski tunel
	var max_time_req: float = float(challenge_reqs.get("max_time_s", -1.0))
	if max_time_req > 0.0 and max_time_req <= 65.0:
		plan.append("slide_crawl")

	# 4. Blok treningowy unikanego ruchu (2. połowa)
	var struggle: Dictionary = profile.get("struggle", {})
	var struggle_least: float = float(struggle.get(least_move, 0.0))
	plan.append("hub")
	var shield_hub_index: int = -1
	if has_profile and struggle_least >= 0.5:
		shield_hub_index = plan.size() - 1
		reasons.append("Trening %s z tarczą - tu popełniasz najwięcej błędów" % MECH_LABELS.get(least_move, least_move))
	else:
		reasons.append("Trening: %s (ruch, którego używasz najrzadziej)" % MECH_LABELS.get(least_move, least_move))
	var train_count: int = 2 if tier <= 1 else 3
	var train_used: Array = []
	for i in range(train_count):
		var cap: int = 1 if i == 0 or struggle_least >= 0.5 else mini(tier, 2)
		var m2: String = _pick_module(rng, least_move, cap, train_used)
		plan.append(m2)
		train_used.append(m2)
	var training_last_index: int = plan.size() - 1

	# 5. Mechanika z największą liczbą błędów spoza trójki (wślizg, wall jump, trampoliny...)
	if not weakest.is_empty() and weakest != least_move and MODULE_POOLS.has(weakest):
		plan.append(_pick_module(rng, weakest, mini(tier, 2), []))
		reasons.append("Dodatkowo: %s (najwięcej błędów w Twoim profilu)" % MECH_LABELS.get(weakest, weakest))
	elif has_profile and not ranked.is_empty():
		var rarest: String = String(ranked[ranked.size() - 1])
		if rarest != least_move and MODULE_POOLS.has(rarest):
			plan.append(_pick_module(rng, rarest, 1, []))
			reasons.append("Dodatkowo: %s (prawie go nie używasz)" % MECH_LABELS.get(rarest, rarest))

	# 6. Finał
	plan.append("hub")
	if tier >= 3:
		plan.append(_pick_fork(rng, train, 3, [fork1]))
	else:
		plan.append("enemy_run")
	plan.append("finish")

	# --- składanie siatki z modułów
	var grid: GridLevel = GridLevelScript.from_sequence(plan, {"module": fork1, "id": "SEC-LVL-4", "name": "Klejnot Eteru #4"})
	if shield_hub_index >= 0:
		var hub_m: Dictionary = grid.layout[shield_hub_index]
		for cell in grid.jewel_cells():
			if cell.x >= int(hub_m["c0"]) and cell.x < int(hub_m["c0"]) + int(hub_m["w"]):
				grid.cells[cell] = "3"
				break
	if has_profile and float(profile.get("explorer", 0.5)) >= 0.7:
		grid.add_bonus_jewels(4)
		reasons.append("Zbierasz prawie wszystko - w hubach czeka więcej klejnotów")
	if use_cursed:
		for idx in [1, training_last_index]:
			var mm: Dictionary = grid.layout[idx]
			var target: String = fav_move if idx == 1 else least_move
			if not ["double_jump", "wall_climb", "dash"].has(target):
				target = "dash"
			for cell in grid.jewel_cells():
				if cell.x >= int(mm["c0"]) and cell.x < int(mm["c0"]) + int(mm["w"]) and String(grid.cells[cell]) == "J":
					grid.jewel_meta[cell] = {"cursed": target}
					break
	var required_jewels: int = int(challenge_reqs.get("min_jewels", 0))
	var have: int = grid.jewel_cells().size()
	if have < required_jewels:
		grid.add_bonus_jewels(required_jewels - have)

	# Tablica z analizą na starcie poziomu
	var title: String = "CYBER MATRIX AI  [poziom trudności %d]" % tier
	if has_profile:
		title += "  |  profil z %d prób" % int(profile.get("runs", 0))
	grid.labels.append({"text": title, "pos": Vector2(40, 100)})
	for i in range(reasons.size()):
		grid.labels.append({"text": "- " + reasons[i], "pos": Vector2(40, 120 + i * 16)})

	var blueprint: Dictionary = grid.to_blueprint(4, BIOME_AETHER)
	blueprint["first_half_mechanic"] = fav_move
	blueprint["second_half_mechanic"] = least_move
	blueprint["challenge_max_time_s"] = max_time_req
	blueprint["difficulty_tier"] = tier
	blueprint["chunk_sequence"] = plan
	blueprint["playstyle_report"] = {"reasons": reasons, "profile": profile, "tier": tier}
	var validation: Dictionary = grid.validate()
	validation["chunk_sequence"] = plan
	validation["difficulty_tier"] = tier
	blueprint["validation"] = validation
	return blueprint

static func _snap16(val: float) -> float:
	return round(val / TILE_PX) * TILE_PX

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
