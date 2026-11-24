extends RefCounted
class_name GridLevel

## Poziom zbudowany na siatce 16px z modułów biblioteki LevelModules (poziomy 2, 3 i poziom AI).
## Te same zasady co ręcznie zaprojektowany Level 1:
##  - kolizje to scalone prostokąty StaticBody2D (mosty '=' są jednostronne),
##  - kafelki są tylko wizualne (grupa "visual_only"), tło to obraz z paralaksą / animacja,
##  - kolce podłogowe i sufitowe, ciecze, przepaść z respawnem na checkpoincie, trampoliny w podłodze,
##  - SkillZone'y raportują profilerowi stylu gry, gdzie gracz ma problemy i które trasy wybiera.

const LevelModulesLib = preload("res://scripts/core/level_modules.gd")
const HazardScript = preload("res://scripts/core/hazard_area.gd")
const CheckpointScript = preload("res://scripts/core/checkpoint.gd")
const TrampolineScript = preload("res://scripts/core/trampoline_pad.gd")
const SkillZoneScript = preload("res://scripts/core/skill_zone.gd")
const BackgroundScript = preload("res://scripts/core/level_background.gd")
const JewelScene = preload("res://scenes/Jewel.tscn")
const EnemyScene = preload("res://scenes/enemies/enemy_mockup.tscn")

const T: int = 16
const TOP: int = LevelModulesLib.TOP_ROW
const BOT: int = LevelModulesLib.BOTTOM_ROW
const GROUND: int = LevelModulesLib.GROUND_ROW
const SOLID := "#B"
const STAND := "#B=T"

# Tło per biom (FOREST=1, WINTER=2, AUTUMN=3, AETHER=4)
const BACKGROUNDS: Dictionary = {
	1: {"path": "res://assets/Background-export.png", "scale": 1.0, "scroll": 0.4, "frames": 1},
	2: {"path": "res://assets/IceflowRidgeBackgroundt.png", "scale": 2.0, "scroll": 0.25, "frames": 1},
	3: {"path": "res://assets/BlazingTrenchBackground.png", "scale": 2.0, "scroll": 0.25, "frames": 1},
	4: {"path": "res://assets/CyberMatrixBackgroundSpriteSheet.png", "scale": 1.0, "scroll": 0.0, "frames": 9}
}

# Dekoracje per biom: litera -> lista kafelków od góry do dołu (paleta 'p' to palma 3x4)
const DECOR_SETS: Dictionary = {
	1: {"t": [Vector2i(0, 3), Vector2i(0, 4), Vector2i(0, 5)], "g": [Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6)],
		"b": [Vector2i(8, 7)], "s": [Vector2i(1, 4)], "f": [Vector2i(1, 6)], "i": [Vector2i(4, 3)], "n": [Vector2i(0, 6)],
		"r": [Vector2i(5, 7)], "m": [Vector2i(10, 1)], "k": [Vector2i(6, 6)]},
	2: {"t": [Vector2i(7, 5)], "g": [Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6)], "b": [Vector2i(8, 8)],
		"s": [Vector2i(8, 9)], "f": [Vector2i(8, 8)], "i": [Vector2i(7, 6)], "n": [Vector2i(0, 6)], "r": [Vector2i(5, 8)],
		"m": [Vector2i(10, 0)], "k": [Vector2i(7, 5)]},
	3: {"t": [Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5)], "g": [Vector2i(5, 3), Vector2i(5, 4), Vector2i(5, 5)],
		"b": [Vector2i(5, 6)], "s": [Vector2i(5, 7)], "f": [Vector2i(7, 7)], "i": [Vector2i(4, 3)], "n": [Vector2i(0, 6)],
		"r": [Vector2i(5, 8)], "m": [Vector2i(9, 1)], "k": [Vector2i(6, 6)]},
	4: {"t": [Vector2i(9, 0), Vector2i(9, 1)], "g": [Vector2i(9, 2), Vector2i(9, 3)], "b": [Vector2i(10, 3)],
		"s": [Vector2i(10, 2)], "f": [Vector2i(6, 7)], "i": [Vector2i(4, 3)], "n": [Vector2i(6, 4)], "r": [Vector2i(7, 8)],
		"m": [Vector2i(10, 1)], "k": [Vector2i(7, 7)]}
}

var cells: Dictionary = {}          # Vector2i -> String (1 znak)
var width: int = 0
var layout: Array[Dictionary] = []  # [{id, c0, w, uid}]
var labels: Array[Dictionary] = []  # [{text, pos}]
var zones: Array[Dictionary] = []   # [{tag, uid, rect: Rect2i (kolumny/wiersze)}]
var checks: Array[Dictionary] = []  # metadane testów zręczności (dla harnessu)
var bounces: Dictionary = {}        # Vector2i -> float (trampoliny)
var jewel_meta: Dictionary = {}     # Vector2i -> {cursed, secret...}
var secret_cfg: Dictionary = {}     # {module_uid, id, name}
var enemy_tuning: Dictionary = {"patrol_range": 48.0, "move_speed": 40.0, "detection_radius": 135.0}

# ------------------------------------------------------------------ składanie z modułów
static func from_sequence(sequence: Array, secret: Dictionary = {}) -> GridLevel:
	var g := GridLevel.new()
	g.secret_cfg = secret
	g._wall(0)
	var c0: int = 2
	var idx: int = 0
	for mid in sequence:
		idx += 1
		c0 = g.append_module(String(mid), c0, "%s#%d" % [mid, idx])
	g._wall(c0)
	g.width = c0 + 2
	g._resolve_secret()
	return g

func _wall(c0: int) -> void:
	for c in range(c0, c0 + 2):
		for r in range(TOP - 1, BOT + 1):
			cells[Vector2i(c, r)] = "B"

func append_module(mid: String, c0: int, uid: String) -> int:
	var mod: Dictionary = LevelModulesLib.MODULES[mid]
	var rows: Array = mod["map"]
	var w: int = int(mod["w"])
	var t_idx: int = 0
	var bounce_list: Array = mod.get("bounce", [])
	for i in range(rows.size()):
		var row: String = rows[i]
		var r: int = TOP + i
		for c in range(w):
			var ch: String = row[c]
			if ch == ".":
				continue
			var cell := Vector2i(c0 + c, r)
			cells[cell] = ch
			if ch == "T":
				bounces[cell] = float(bounce_list[t_idx]) if t_idx < bounce_list.size() else -620.0
				t_idx += 1
			elif ch == "X":
				jewel_meta[cell] = {"module_uid": uid}
	for lb in mod.get("labels", []):
		labels.append({"text": String(lb["text"]), "pos": Vector2(c0 * T + float(lb["x"]), float(lb["y"]))})
	for z in mod.get("zones", []):
		var rc: Array = z["rect"]
		zones.append({"tag": String(z["tag"]), "uid": uid,
			"rect": Rect2i(c0 + int(rc[0]), int(rc[1]), int(rc[2]) - int(rc[0]) + 1, int(rc[3]) - int(rc[1]) + 1)})
	for ck in mod.get("checks", []):
		var d: Dictionary = (ck as Dictionary).duplicate(true)
		d["module"] = mid
		d["uid"] = uid
		d["c0"] = c0
		checks.append(d)
	layout.append({"id": mid, "c0": c0, "w": w, "uid": uid, "tags": mod.get("tags", [])})
	return c0 + w

## Pierwszy slot 'X' w module wskazanym w konfiguracji staje się sekretnym klejnotem, pozostałe zwykłymi.
func _resolve_secret() -> void:
	var chosen: Vector2i = Vector2i(-99999, 0)
	var want_mod: String = String(secret_cfg.get("module", ""))
	for cell in jewel_meta.keys():
		var uid: String = String(jewel_meta[cell].get("module_uid", ""))
		if not want_mod.is_empty() and uid.begins_with(want_mod + "#") and (chosen.x == -99999 or cell.x < chosen.x):
			chosen = cell
	for cell in jewel_meta.keys():
		if cell == chosen:
			jewel_meta[cell]["secret"] = true
		else:
			cells[cell] = "J"

func ch(c: int, r: int) -> String:
	return String(cells.get(Vector2i(c, r), "."))

func is_solid(c: int, r: int) -> bool:
	return SOLID.contains(ch(c, r)) and ch(c, r) != ""

func find_char(target: String) -> Vector2i:
	for cell in cells.keys():
		if cells[cell] == target:
			return cell
	return Vector2i(-1, -1)

## Dokłada bonusowe klejnoty (zadania z portalu) nad podłogą w modułach hub/start.
func add_bonus_jewels(count: int) -> int:
	var added: int = 0
	var spots: Array[Vector2i] = []
	for m in layout:
		if String(m["id"]) in ["hub", "start", "enemy_run", "spike_bridges"]:
			for dc in range(2, int(m["w"]) - 1, 2):
				for r in [15, 13]:
					spots.append(Vector2i(int(m["c0"]) + dc, r))
	for s in spots:
		if added >= count:
			break
		if ch(s.x, s.y) == "." and ch(s.x, s.y + 1) == "." and ch(s.x, s.y - 1) == ".":
			cells[s] = "J"
			added += 1
	return added

func jewel_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in cells.keys():
		if "J123X".contains(String(cells[cell])):
			out.append(cell)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out

# ------------------------------------------------------------------ geometria (scalone prostokąty)
func merge_rects(pred: Callable) -> Array[Rect2i]:
	var used: Dictionary = {}
	var out: Array[Rect2i] = []
	for r in range(TOP - 1, BOT + 1):
		var c: int = 0
		while c < width:
			if pred.call(c, r) and not used.has(Vector2i(c, r)):
				var ce: int = c
				while ce + 1 < width and pred.call(ce + 1, r) and not used.has(Vector2i(ce + 1, r)):
					ce += 1
				var re: int = r
				var can_grow: bool = true
				while can_grow and re + 1 <= BOT:
					for x in range(c, ce + 1):
						if not pred.call(x, re + 1) or used.has(Vector2i(x, re + 1)):
							can_grow = false
							break
					if can_grow:
						re += 1
				for x in range(c, ce + 1):
					for y in range(r, re + 1):
						used[Vector2i(x, y)] = true
				out.append(Rect2i(c, r, ce - c + 1, re - r + 1))
				c = ce + 1
			else:
				c += 1
	return out

func _is(chars: String) -> Callable:
	return func(c: int, r: int) -> bool: return chars.contains(ch(c, r)) and ch(c, r) != "."

func spawn_pos() -> Vector2:
	var s: Vector2i = find_char("@")
	return Vector2(s.x * T + 8, (s.y + 1) * T - 15)

func finish_pos() -> Vector2:
	var f: Vector2i = find_char("$")
	return Vector2(f.x * T + 8, (f.y + 1) * T - 28)

func logical_grid() -> Dictionary:
	var lg: Dictionary = {}
	for cell in cells.keys():
		match String(cells[cell]):
			"#": lg[cell] = 1
			"B": lg[cell] = 2
			"=": lg[cell] = 6
			"T": lg[cell] = 7
			"~": lg[cell] = 8
			"^", "v": lg[cell] = 5
	return lg

# ------------------------------------------------------------------ walidator przechodności (fizyka zmierzona w Godot)
func _surfaces() -> Array[Dictionary]:
	var segs: Array[Dictionary] = []
	for r in range(TOP, BOT + 1):
		var c: int = 0
		while c < width:
			var ok: bool = STAND.contains(ch(c, r)) and ch(c, r) != "." and not SOLID.contains(ch(c, r - 1)) and not "^~v".contains(ch(c, r - 1)) and not SOLID.contains(ch(c, r - 2))
			if ok:
				var ce: int = c
				var tramp: float = 0.0
				while ce < width:
					var ok2: bool = STAND.contains(ch(ce, r)) and ch(ce, r) != "." and not SOLID.contains(ch(ce, r - 1)) and not "^~v".contains(ch(ce, r - 1)) and not SOLID.contains(ch(ce, r - 2))
					if not ok2:
						break
					if ch(ce, r) == "T":
						tramp = min(tramp, float(bounces.get(Vector2i(ce, r), -620.0)))
					ce += 1
				segs.append({"c0": c, "c1": ce - 1, "r": r, "tramp": tramp})
				c = ce
			else:
				c += 1
	return segs

func _wall_face(col: int, top_r: int, bottom_r: int) -> bool:
	for rr in range(top_r, bottom_r + 1):
		if not is_solid(col, rr):
			return false
	return true

func _can_reach(a: Dictionary, b: Dictionary) -> bool:
	var dh: float = float(int(a["r"]) - int(b["r"])) * T   # >0: cel wyżej
	var gap_c: int = max(0, max(int(b["c0"]) - int(a["c1"]) - 1, int(a["c0"]) - int(b["c1"]) - 1))
	var gap: float = gap_c * T
	# skok + podwójny skok + dash (zmierzone: 18 kratek na tej samej wysokości, 5 kratek w górę)
	if dh <= 0.0:
		if gap <= 300.0 + min(-dh, 200.0) * 0.5:
			return true
	elif dh <= 100.0 and gap <= 300.0 - dh * 1.2:
		return true
	# trampolina na powierzchni startowej
	var tr: float = float(a["tramp"])
	if tr < 0.0 and dh <= tr * tr / 1760.0 + 40.0 and gap <= 220.0:
		return true
	# wspinaczka: ściana celu musi schodzić do zasięgu skoku (4 kratki nad startem)
	if dh > 0.0 and dh <= 320.0 and gap_c <= 8:
		var face_col: int = int(b["c0"]) if int(b["c0"]) > int(a["c1"]) else int(b["c1"])
		if int(b["c0"]) <= int(a["c1"]) and int(b["c1"]) >= int(a["c0"]):
			face_col = int(b["c0"])
		var bottom_needed: int = int(a["r"]) - 4
		if _wall_face(face_col, int(b["r"]), max(int(b["r"]), bottom_needed)):
			return true
		# komin: dwie ściany naprzeciw siebie
		for dc in range(2, 7):
			var other: int = face_col - dc if int(b["c0"]) > int(a["c1"]) else face_col + dc
			if _wall_face(other, int(b["r"]) + 2, max(int(b["r"]) + 2, bottom_needed)) and _wall_face(face_col, int(b["r"]), int(b["r"]) + 2):
				return true
	return false

func validate() -> Dictionary:
	var segs: Array[Dictionary] = _surfaces()
	var s_cell: Vector2i = find_char("@")
	var f_cell: Vector2i = find_char("$")
	var start_i: int = -1
	var goal_i: int = -1
	for i in range(segs.size()):
		var sg: Dictionary = segs[i]
		if int(sg["r"]) == s_cell.y + 1 and s_cell.x >= int(sg["c0"]) and s_cell.x <= int(sg["c1"]):
			start_i = i
		if int(sg["r"]) == f_cell.y + 1 and f_cell.x >= int(sg["c0"]) and f_cell.x <= int(sg["c1"]):
			goal_i = i
	var seen: Dictionary = {}
	if start_i >= 0:
		var queue: Array[int] = [start_i]
		seen[start_i] = true
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			for j in range(segs.size()):
				if not seen.has(j) and _can_reach(segs[cur], segs[j]):
					seen[j] = true
					queue.append(j)
	return {"passed": start_i >= 0 and goal_i >= 0 and seen.has(goal_i), "repairs": 0,
		"surfaces": segs.size(), "reachable_surfaces": seen.size()}

# ------------------------------------------------------------------ blueprint (dla testów / analizatora / kompozytora)
func to_blueprint(profile_id: int, biome_id: int) -> Dictionary:
	var blocks: Array[Dictionary] = []
	var n: int = 0
	for rc in merge_rects(_is(SOLID)):
		n += 1
		blocks.append({"name": "Block%d" % n, "pos": Vector2(rc.position.x * T + rc.size.x * T * 0.5, rc.position.y * T + rc.size.y * T * 0.5),
			"size": Vector2(rc.size.x * T, rc.size.y * T), "type": 2 if ch(rc.position.x, rc.position.y) == "B" and rc.size.y > rc.size.x else 1})
	for rc in merge_rects(_is("=")):
		n += 1
		blocks.append({"name": "Bridge%d" % n, "pos": Vector2(rc.position.x * T + rc.size.x * T * 0.5, rc.position.y * T + 4),
			"size": Vector2(rc.size.x * T, 8), "type": 6})
	var jewels: Array[Dictionary] = []
	for cell in jewel_cells():
		var k: String = String(cells[cell])
		var d: Dictionary = {"pos": Vector2(cell.x * T + 8, cell.y * T + 8), "jewel_type": int(k) if k in ["1", "2", "3"] else 0, "cursed_mechanic": String(jewel_meta.get(cell, {}).get("cursed", ""))}
		if k == "X" and bool(jewel_meta.get(cell, {}).get("secret", false)):
			d["is_secret_special"] = true
			d["special_id"] = String(secret_cfg.get("id", "SEC-GRID"))
			d["special_name"] = String(secret_cfg.get("name", "Klejnot Eteru"))
			d["special_rarity"] = "Legendarny"
		jewels.append(d)
	var tramps: Array[Dictionary] = []
	var cps: Array[Dictionary] = []
	var ens: Array[Dictionary] = []
	for cell in cells.keys():
		var k: String = String(cells[cell])
		if k == "T":
			tramps.append({"pos": Vector2(cell.x * T + 8, cell.y * T + 8), "bounce_velocity": float(bounces.get(cell, -620.0))})
		elif k == "K":
			cps.append({"pos": Vector2(cell.x * T + 8, (cell.y + 1) * T - 24)})
		elif "EAR".contains(k):
			ens.append({"pos": _enemy_pos(cell, k), "archetype": "EAR".find(k)})
	var w_px: float = width * T
	return {
		"profile_id": profile_id, "biome_id": biome_id, "grid": self,
		"respawn_pos": spawn_pos(), "finish_pos": finish_pos(), "level_width": w_px,
		"blocks": blocks, "jewels": jewels, "trampolines": tramps, "checkpoints": cps, "enemies": ens,
		"hazards": [{"name": "AbyssZone", "pos": Vector2(w_px * 0.5, 420.0), "size": Vector2(w_px + 400.0, 64.0), "is_abyss": true}],
		"decorations": [], "labels": labels.duplicate(), "module_layout": layout.duplicate(true),
		"chunk_sequence": layout.map(func(m): return String(m["id"])),
		"logical_grid": logical_grid()
	}

func _enemy_pos(cell: Vector2i, k: String) -> Vector2:
	if k == "A":
		return Vector2(cell.x * T + 8, cell.y * T + 8)
	return Vector2(cell.x * T + 8, (cell.y + 1) * T - 9)

# ------------------------------------------------------------------ budowa węzłów w arenie
static func _container(arena: Node2D, node_name: String, z: int) -> Node2D:
	var cont: Node2D = arena.get_node_or_null(node_name) as Node2D
	if not cont:
		cont = Node2D.new()
		cont.name = node_name
		arena.add_child(cont)
	cont.z_index = z
	for child in cont.get_children():
		cont.remove_child(child)
		child.queue_free()
	return cont

func build(arena: Node2D, tile_layer: TileMapLayer, tileset: TileSet, blueprint: Dictionary, palette: Dictionary) -> void:
	var biome: int = int(blueprint.get("biome_id", 1))
	var geom: Node2D = _container(arena, "Geometry", 0)
	var haz: Node2D = _container(arena, "Hazards", 2)
	var cp_root: Node2D = _container(arena, "Checkpoints", 2)
	var tr_root: Node2D = _container(arena, "Trampolines", 1)
	var en_root: Node2D = _container(arena, "Enemies", 3)
	var zone_root: Node2D = _container(arena, "Zones", 0)
	var labels_root: Node2D = arena.get_node_or_null("Labels") as Node2D
	if labels_root:
		labels_root.z_index = 6
		for child in labels_root.get_children():
			labels_root.remove_child(child)
			child.queue_free()
	for child in arena.get_children():
		var scr: Script = child.get_script()
		var sp: String = scr.resource_path if scr else ""
		if child.is_in_group("jewels") or sp.ends_with("jewel.gd") or child.name.begins_with("Jewel") \
				or child.is_in_group("enemies") or sp.ends_with("enemy_mockup.gd") or child.name.begins_with("EnemyMockup") \
				or child.name == "Decor":
			arena.remove_child(child)
			child.queue_free()

	# --- kolizje
	var n: int = 0
	for rc in merge_rects(_is(SOLID)):
		n += 1
		_body(geom, "Block%d" % n, Rect2(rc.position.x * T, rc.position.y * T, rc.size.x * T, rc.size.y * T), false)
	for rc in merge_rects(_is("=")):
		n += 1
		_body(geom, "Bridge%d" % n, Rect2(rc.position.x * T, rc.position.y * T, rc.size.x * T, 8), true)

	# --- tło (obraz/animacja w CanvasLayer) i wyłączenie płaskiego tła areny
	var bg_cfg: Dictionary = BACKGROUNDS.get(biome, BACKGROUNDS[1])
	var bg := CanvasLayer.new()
	bg.name = "LevelBackground"
	bg.set_script(BackgroundScript)
	bg.set("texture_path", String(bg_cfg["path"]))
	bg.set("pixel_scale", float(bg_cfg["scale"]))
	bg.set("scroll_factor", float(bg_cfg["scroll"]))
	bg.set("frame_count", int(bg_cfg["frames"]))
	geom.add_child(bg)
	var flat_bg: CanvasItem = arena.get_node_or_null("Background") as CanvasItem
	if flat_bg:
		flat_bg.visible = false

	# --- kafelki (teren, ciecze) – czysto wizualne
	tile_layer.clear()
	tile_layer.z_index = -1
	tile_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not tile_layer.is_in_group("visual_only"):
		tile_layer.add_to_group("visual_only")
	tile_layer.set_meta("logical_tile_grid", blueprint.get("logical_grid", {}))
	var src: int = tileset.get_source_id(0) if tileset and tileset.get_source_count() > 0 else -1
	var bridge_tiles: Array = palette.get("bridge", [Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3)])
	if src >= 0:
		for cell in cells.keys():
			var k: String = String(cells[cell])
			var above: String = ch(cell.x, cell.y - 1)
			var atlas := Vector2i(-1, -1)
			match k:
				"#":
					atlas = palette["floor_top"] if not SOLID.contains(above) or above == "." else palette["floor_fill"]
				"B":
					atlas = palette["wall_top"] if above != "B" else palette["wall_fill"]
				"=":
					atlas = bridge_tiles[cell.x % bridge_tiles.size()]
				"~":
					atlas = palette["liquid_top"] if above != "~" else palette["liquid_fill"]
			if atlas.x >= 0:
				tile_layer.set_cell(cell, src, atlas)
		# ziemia pod poziomem (aż do dołu ekranu) pod kolumnami z gruntem
		for c in range(width):
			if is_solid(c, BOT):
				for r in range(BOT + 1, BOT + 4):
					tile_layer.set_cell(Vector2i(c, r), src, palette["floor_fill"])

	# --- dekoracje (DecorTileMapLayer)
	var decor_layer: TileMapLayer = _tilemap(arena, "DecorTileMapLayer", -2, tileset)
	for old_layer_name in ["BgTileMapLayer", "CeilingTileMapLayer"]:
		var old_layer: TileMapLayer = arena.get_node_or_null(old_layer_name) as TileMapLayer
		if old_layer:
			old_layer.clear()
	var dset: Dictionary = DECOR_SETS.get(biome, DECOR_SETS[1])
	if src >= 0:
		for cell in cells.keys():
			var k: String = String(cells[cell])
			if k == "p" and biome != 1:
				k = "g"   # palma tylko w lesie – w innych biomach duże drzewo biomu
			if k == "p":
				# palma: korona 3x1 + pień 1x3
				for i in range(3):
					decor_layer.set_cell(Vector2i(cell.x + i, cell.y - 3), src, Vector2i(2 + i, 5))
				for i in range(3):
					decor_layer.set_cell(Vector2i(cell.x + 1, cell.y - 2 + i), src, Vector2i(3, 6 + i))
			elif dset.has(k):
				var stack: Array = dset[k]
				for i in range(stack.size()):
					decor_layer.set_cell(Vector2i(cell.x, cell.y - stack.size() + 1 + i), src, stack[i])

	# --- zagrożenia
	var hn: int = 0
	for rc in merge_rects(_is("^")):
		hn += 1
		_spikes(haz, "SpikesFloor%d" % hn, rc, false)
	for rc in merge_rects(_is("v")):
		hn += 1
		_spikes(haz, "SpikesCeiling%d" % hn, rc, true)
	for rc in merge_rects(_is("~")):
		hn += 1
		var liquid := _make_area("Liquid%d" % hn, Rect2(rc.position.x * T + 2, rc.position.y * T + 5, rc.size.x * T - 4, rc.size.y * T - 5))
		liquid.set_script(HazardScript)
		liquid.set("is_abyss", true)
		liquid.collision_layer = 16
		liquid.collision_mask = 2
		haz.add_child(liquid)
	var w_px: float = width * T
	var abyss := _make_area("AbyssZone", Rect2(-200, 388, w_px + 400, 64))
	abyss.set_script(HazardScript)
	abyss.set("is_abyss", true)
	abyss.collision_layer = 16
	abyss.collision_mask = 2
	haz.add_child(abyss)

	# --- byty: checkpointy, trampoliny, wrogowie, klejnoty, strefy
	var cp_i: int = 0
	var cells_sorted: Array = cells.keys()
	cells_sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	var en_i: int = 0
	for cell in cells_sorted:
		var k: String = String(cells[cell])
		if k == "K":
			cp_i += 1
			var cp := Area2D.new()
			cp.name = "Checkpoint%d" % cp_i
			cp.position = Vector2(cell.x * T + 8, (cell.y + 1) * T - 24)
			cp.collision_layer = 0
			cp.collision_mask = 2
			cp.set_script(CheckpointScript)
			cp.set("checkpoint_id", "CP-%d" % cp_i)
			var col := CollisionShape2D.new()
			var sh := RectangleShape2D.new()
			sh.size = Vector2(36, 64)
			col.position = Vector2(0, -8)
			col.shape = sh
			cp.add_child(col)
			cp_root.add_child(cp)
		elif k == "T":
			var pad := Area2D.new()
			pad.name = "Trampoline%d" % (tr_root.get_child_count() + 1)
			pad.position = Vector2(cell.x * T + 8, cell.y * T + 8)
			pad.set_script(TrampolineScript)
			pad.call("configure", palette.get("trampoline", Vector2i(1, 2)), float(bounces.get(cell, -620.0)))
			tr_root.add_child(pad)
		elif "EAR".contains(k):
			en_i += 1
			var e: Area2D = EnemyScene.instantiate() as Area2D
			e.name = ["Slime", "Bat", "Spider"]["EAR".find(k)] + str(en_i)
			e.position = _enemy_pos(cell, k)
			if e.has_method("configure"):
				e.call("configure", "EAR".find(k), int(palette.get("enemy_color", 0)), float(enemy_tuning["patrol_range"]),
					float(enemy_tuning["move_speed"]), float(enemy_tuning["detection_radius"]))
			en_root.add_child(e)
	var j_i: int = 0
	for jd in blueprint.get("jewels", []):
		j_i += 1
		var j: Area2D = JewelScene.instantiate() as Area2D
		j.name = "Jewel%d" % j_i
		j.z_index = 4
		j.position = jd["pos"]
		var jt: int = int(jd.get("jewel_type", 0))
		if jt != 0:
			j.set("jewel_type", jt)
		var cursed: String = String(jd.get("cursed_mechanic", ""))
		if not cursed.is_empty():
			j.set("is_cursed", true)
			j.set("cursed_mechanic", cursed)
		if bool(jd.get("is_secret_special", false)):
			j.set("is_secret_special", true)
			j.set("special_id", String(jd.get("special_id", "")))
			j.set("special_name", String(jd.get("special_name", "")))
			j.set("special_rarity", String(jd.get("special_rarity", "Legendarny")))
		arena.add_child(j)
	for z in zones:
		var rc: Rect2i = z["rect"]
		var za := _make_area("Zone_%s_%s" % [String(z["tag"]).replace(":", "_"), String(z["uid"]).replace("#", "_")],
			Rect2(rc.position.x * T, rc.position.y * T, rc.size.x * T, rc.size.y * T))
		za.set_script(SkillZoneScript)
		za.set("tag", String(z["tag"]))
		za.set("module_uid", String(z["uid"]))
		zone_root.add_child(za)

	# --- napisy
	if labels_root:
		for lb in labels:
			var lbl := Label.new()
			lbl.position = lb["pos"]
			lbl.text = String(lb["text"])
			lbl.add_theme_constant_override("outline_size", 3)
			lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.12, 0.95))
			labels_root.add_child(lbl)

	# --- gracz, kamera, meta
	var spawn: Vector2 = spawn_pos()
	var respawn: Marker2D = arena.get_node_or_null("RespawnPoint") as Marker2D
	if respawn:
		respawn.position = spawn
	var player: Node2D = arena.get_node_or_null("Player") as Node2D
	if player:
		player.position = spawn
		if player.has_method("set_checkpoint"):
			player.call("set_checkpoint", spawn, "START")
		var cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.limit_left = 0
			cam.limit_top = (TOP) * T
			cam.limit_right = int(w_px)
			cam.limit_bottom = 352
	var goal: Area2D = arena.get_node_or_null("FinishGoal") as Area2D
	if goal:
		goal.position = finish_pos()
		goal.z_index = 2

func _body(parent: Node, nm: String, r: Rect2, one_way: bool) -> void:
	var sb := StaticBody2D.new()
	sb.name = nm
	sb.collision_mask = 0
	sb.position = r.position + r.size * 0.5
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	col.shape = sh
	col.one_way_collision = one_way
	sb.add_child(col)
	parent.add_child(sb)

func _make_area(nm: String, r: Rect2) -> Area2D:
	var a := Area2D.new()
	a.name = nm
	a.position = r.position + r.size * 0.5
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	col.shape = sh
	a.add_child(col)
	return a

func _spikes(parent: Node, nm: String, rc: Rect2i, ceiling: bool) -> void:
	var w: float = rc.size.x * T
	var a := Area2D.new()
	a.name = nm
	a.collision_layer = 16
	a.collision_mask = 2
	a.set_script(HazardScript)
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	var tex: Texture2D = load("res://assets/Kolce.png")
	var trect := TextureRect.new()
	trect.name = "TextureRect"
	trect.texture = tex
	trect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trect.stretch_mode = TextureRect.STRETCH_TILE
	trect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if ceiling:
		a.position = Vector2(rc.position.x * T + w * 0.5, rc.position.y * T + 6)
		sh.size = Vector2(w - 4, 12)
		trect.position = Vector2(-w * 0.5, -6)
		trect.size = Vector2(w, 16)
		trect.flip_v = true
	else:
		a.position = Vector2(rc.position.x * T + w * 0.5, (rc.position.y + 1) * T - 12)
		sh.size = Vector2(w - 4, 18)
		col.position = Vector2(0, 3)
		trect.scale = Vector2(1.5, 1.5)
		trect.position = Vector2(-w * 0.5, -12)
		trect.size = Vector2(w / 1.5, 16)
	col.shape = sh
	a.add_child(col)
	a.add_child(trect)
	parent.add_child(a)

static func _tilemap(arena: Node2D, nm: String, z: int, tileset: TileSet) -> TileMapLayer:
	var layer: TileMapLayer = arena.get_node_or_null(nm) as TileMapLayer
	if not layer:
		layer = TileMapLayer.new()
		layer.name = nm
		arena.add_child(layer)
	layer.z_index = z
	layer.scale = Vector2.ONE
	layer.position = Vector2.ZERO
	layer.modulate = Color.WHITE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tileset:
		layer.tile_set = tileset
	layer.clear()
	if not layer.is_in_group("visual_only"):
		layer.add_to_group("visual_only")
	return layer
