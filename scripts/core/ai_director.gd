extends Node
class_name AdaptiveAIDirector

## Adaptacyjny Reżyser AI (AI Director) - Patryk (Prywatny Asystent Technologiczny, Reagujący i Kreatywny) oraz Analizator Poziomu dla JewelRunner.
## Odpowiada za:
## 1. Zliczanie częstotliwości wykonywania ruchów specjalnych (double_jump, wall_climb, dash) oraz historię stylu gracza.
## 2. Dynamiczne zarządzanie mnożnikami kosztu staminy przy zachowaniu STAŁEJ SUMY mnożników (z uwzględnieniem wag).
## 3. Obsługę Kontraktów AI:
##    - OVERLOAD_CLASSIC: Przeciążenie przy spamowaniu jednego ruchu.
##    - RELAY_LOCK (Sztafeta): Użycie ruchu blokuje go do czasu użycia innego ruchu lub wykonania Tricku w powietrzu.
##    - CURSED_JEWELS (Niestabilne Klejnoty): Wybrane klejnoty czasowo wyłączają przypisaną mechanikę po zebraniu.
## 4. Analizę geometrii poziomu i wyliczanie Radaru DNA Mechanik (% Wspinaczki | % Dasha | % Skoków).

const TRACKED_MOVES: Array[String] = ["double_jump", "wall_climb", "dash"]

enum ContractMode {
	OVERLOAD_CLASSIC = 0, ## Klasyczne przeciążenie przy monotonnym powtarzaniu jednego ruchu
	RELAY_LOCK = 1,       ## Sztafeta Ruchu: użyty ruch blokuje się do momentu wykonania innego ruchu / Tricku
	CURSED_JEWELS = 2     ## Niestabilne Klejnoty: zebranie przeklętego klejnotu wyłącza główną mechanikę sekcji
}

@export_group("Balans Mnożników (Stała Suma)")
@export var target_multiplier_sum: float = 3.0
@export var min_multiplier: float = 0.50
@export var max_multiplier: float = 2.00
@export var adaptation_sensitivity: float = 0.45
@export var frequency_decay_per_sec: float = 0.05

@export_group("Kontrakty AI i Utrata Mechanik")
@export var active_contract: ContractMode = ContractMode.OVERLOAD_CLASSIC
@export var enable_mechanic_lockout: bool = true
@export var overload_per_discrete_use: float = 0.30
@export var overload_per_climb_sec: float = 0.35
@export var overload_relief_on_other_move: float = 0.18
@export var overload_relief_per_trick_sec: float = 0.35
@export var overload_passive_decay_per_sec: float = 0.06
@export var default_lockout_duration: float = 3.0

# Aktualne mnożniki kosztu staminy (suma ZAWSZE == target_multiplier_sum)
var multipliers: Dictionary = {
	"double_jump": 1.0,
	"wall_climb": 1.0,
	"dash": 1.0
}

# Wagi poszczególnych ruchów (mogą być modyfikowane ręcznie lub przez projektanta)
var move_weights: Dictionary = {
	"double_jump": 1.0,
	"wall_climb": 1.0,
	"dash": 1.0
}

# Współczynniki czułości wynikające z analizy geometrii poziomu
var level_mechanic_sensitivity: Dictionary = {
	"double_jump": 1.0,
	"wall_climb": 1.0,
	"dash": 1.0
}

# Punktowa częstotliwość używania ruchów w bieżącym przelocie
var move_frequency_scores: Dictionary = {
	"double_jump": 0.0,
	"wall_climb": 0.0,
	"dash": 0.0
}

# Całkowite statystyki użyć w bieżącym przelocie poziomu
var move_total_uses: Dictionary = {
	"double_jump": 0.0,
	"wall_climb": 0.0,
	"dash": 0.0
}

# Długoterminowa historia użyć z wielu przelotów (dla generatora "Szachownica Stylu Gracza")
var historical_move_uses: Dictionary = {
	"double_jump": 0.0,
	"wall_climb": 0.0,
	"dash": 0.0
}

# Poziom przeciążenia (0.0 .. 1.0)
var move_overload: Dictionary = {
	"double_jump": 0.0,
	"wall_climb": 0.0,
	"dash": 0.0
}

# Timery czasowej utraty elementu (w sekundach, > 0.0 oznacza zablokowany ruch)
var locked_timers: Dictionary = {
	"double_jump": 0.0,
	"wall_climb": 0.0,
	"dash": 0.0
}

# W Trybie Sztafety (RELAY_LOCK): ostatnio wykonany ruch, który czeka na zmianę innym ruchem
var relay_locked_move: String = ""
var _relay_climb_grace_timer: float = 0.0

# Wynik ostatniej analizy poziomu
var current_level_analysis: Dictionary = {
	"dominant_mechanic": "balanced",
	"primary_move": "double_jump",
	"secondary_mechanic": "dash",
	"scores": {
		"double_jump": 1.0,
		"wall_climb": 1.0,
		"dash": 1.0,
		"slide": 0.0
	},
	"dna_shares": {
		"double_jump": 34,
		"wall_climb": 33,
		"dash": 33
	},
	"jewel_count": 0
}

func _ready() -> void:
	reset_session_state()

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	update_timers_and_decay(delta)

## Resetuje liczniki częstotliwości, przeciążenia i blokady (np. przy starcie/restarcie poziomu).
func reset_session_state(reset_weights: bool = false) -> void:
	relay_locked_move = ""
	_relay_climb_grace_timer = 0.0
	for move in TRACKED_MOVES:
		move_frequency_scores[move] = 0.0
		move_total_uses[move] = 0.0
		move_overload[move] = 0.0
		var was_locked: bool = locked_timers.get(move, 0.0) > 0.0
		locked_timers[move] = 0.0
		if was_locked and is_instance_valid(Events):
			Events.mechanic_lockout_changed.emit(move, false, 0.0)
		if reset_weights:
			move_weights[move] = 1.0
			level_mechanic_sensitivity[move] = 1.0
	_recalculate_multipliers()

## Чиści długoterminową historię stylu gracza.
func clear_historical_profile() -> void:
	for move in TRACKED_MOVES:
		historical_move_uses[move] = 0.0

## Ustawia aktywny Kontrakt Reżysera AI (OVERLOAD_CLASSIC, RELAY_LOCK, CURSED_JEWELS).
func set_contract_mode(mode: ContractMode) -> void:
	active_contract = mode
	relay_locked_move = ""

func get_contract_name() -> String:
	match active_contract:
		ContractMode.RELAY_LOCK:
			return "SZTAFETA RUCHU (Relay Lock)"
		ContractMode.CURSED_JEWELS:
			return "NIESTABILNE KLEJNOTY (Cursed Jewels)"
		_:
			return "PRZECIĄŻENIE STAMINY (Overload)"

## Ustawia wagi ruchów i natychmiast przelicza mnożniki tak, by zachować stałą sumę.
func set_move_weights(new_weights: Dictionary) -> void:
	for move in TRACKED_MOVES:
		if new_weights.has(move):
			move_weights[move] = max(0.1, float(new_weights[move]))
	_recalculate_multipliers()

## Zwraca aktualny mnożnik kosztu staminy dla podanego ruchu.
func get_multiplier(move_name: String) -> float:
	return float(multipliers.get(move_name, 1.0))

## Zwraca sumę wszystkich aktualnych mnożników.
func get_multiplier_sum() -> float:
	var total: float = 0.0
	for move in TRACKED_MOVES:
		total += float(multipliers.get(move, 1.0))
	return total

## Sprawdza, czy dany ruch specjalny jest aktualnie utracony/zablokowany przez AI (Overload, Cursed Jewel lub Sztafetę).
func is_move_locked(move_name: String) -> bool:
	if float(locked_timers.get(move_name, 0.0)) > 0.0:
		return true
	if active_contract == ContractMode.RELAY_LOCK and relay_locked_move == move_name:
		if move_name == "wall_climb" and _relay_climb_grace_timer > 0.0:
			return false
		return true
	return false

## Zwraca pozostały czas blokady ruchu (w sekundach).
func get_lockout_remaining(move_name: String) -> float:
	if float(locked_timers.get(move_name, 0.0)) > 0.0:
		return max(0.0, float(locked_timers.get(move_name, 0.0)))
	if active_contract == ContractMode.RELAY_LOCK and relay_locked_move == move_name:
		return 9.9
	return 0.0

## Nakłada czasową blokadę mechaniki po zebraniu Niestabilnego/Przeklętego Klejnotu (Cursed Jewel).
func apply_cursed_jewel_lock(move_name: String, duration: float = 4.0) -> void:
	if not TRACKED_MOVES.has(move_name) or duration <= 0.0:
		return
	locked_timers[move_name] = max(float(locked_timers.get(move_name, 0.0)), duration)
	move_overload[move_name] = 0.0
	if is_instance_valid(Events):
		Events.mechanic_lockout_changed.emit(move_name, true, duration)

## Zwraca ulubiony (najczęściej używany) ruch gracza na podstawie historii (dla "Szachownicy Stylu Gracza").
func get_favorite_move() -> String:
	var best_move: String = "double_jump"
	var best_val: float = -1.0
	for move in TRACKED_MOVES:
		var total: float = float(historical_move_uses.get(move, 0.0)) + float(move_total_uses.get(move, 0.0))
		if total > best_val:
			best_val = total
			best_move = move
	return best_move

## Zwraca najrzadziej używany ruch gracza (dla drugiej połowy mapy w "Szachownicy Stylu Gracza").
func get_least_used_move() -> String:
	var fav: String = get_favorite_move()
	var least_move: String = "wall_climb" if fav != "wall_climb" else "dash"
	var least_val: float = INF
	for move in TRACKED_MOVES:
		var total: float = float(historical_move_uses.get(move, 0.0)) + float(move_total_uses.get(move, 0.0))
		if total < least_val or (is_equal_approx(total, least_val) and move != fav):
			least_val = total
			least_move = move
	return least_move

## Rejestruje wykonanie ruchu specjalnego przez gracza i aktualizuje mnożniki, przeciążenie oraz Sztafetę.
func record_move_use(move_name: String, amount: float = 1.0) -> void:
	if not TRACKED_MOVES.has(move_name) or amount <= 0.0:
		return
		
	move_frequency_scores[move_name] = float(move_frequency_scores.get(move_name, 0.0)) + amount
	move_total_uses[move_name] = float(move_total_uses.get(move_name, 0.0)) + amount
	historical_move_uses[move_name] = float(historical_move_uses.get(move_name, 0.0)) + amount
	
	# Obsługa Trybu Sztafety (RELAY_LOCK): użycie ruchu odblokowuje poprzedni i blokuje bieżący
	if active_contract == ContractMode.RELAY_LOCK:
		var prev_relay: String = relay_locked_move
		relay_locked_move = move_name
		if move_name == "wall_climb":
			# Ciągła wspinaczka w jednym chwycie ma okienko 0.35s, po puszczeniu ściany wymaga innego ruchu
			_relay_climb_grace_timer = 0.35
		if prev_relay != move_name and is_instance_valid(Events):
			if not prev_relay.is_empty():
				Events.mechanic_lockout_changed.emit(prev_relay, false, 0.0)
			Events.mechanic_lockout_changed.emit(move_name, true, 9.9)
	
	# Aktualizacja przeciążenia (Overload): używany ruch się nagrzewa, a pozostałe stygną (nagroda za dywersyfikację)
	var dominant: String = String(current_level_analysis.get("dominant_mechanic", "balanced"))
	var dominant_resistance: float = 0.72 if move_name == dominant else 1.0
	var base_strain: float = overload_per_climb_sec if move_name == "wall_climb" else overload_per_discrete_use
	
	move_overload[move_name] = clampf(
		float(move_overload.get(move_name, 0.0)) + amount * base_strain * dominant_resistance,
		0.0,
		1.0
	)
	
	for other_move in TRACKED_MOVES:
		if other_move != move_name:
			move_overload[other_move] = max(0.0, float(move_overload.get(other_move, 0.0)) - amount * overload_relief_on_other_move)
			
	if enable_mechanic_lockout and float(move_overload[move_name]) >= 1.0:
		_trigger_move_lockout(move_name)
		
	_recalculate_multipliers()
	if is_instance_valid(Events):
		Events.playstyle_metric_recorded.emit(move_name, float(move_total_uses[move_name]))

## Wywoływane podczas wykonywania tricku w powietrzu - chłodzi przeciążenie ruchów, skraca blokady i resetuje Sztafetę.
func record_air_trick(delta: float) -> void:
	if delta <= 0.0:
		return
	if active_contract == ContractMode.RELAY_LOCK and not relay_locked_move.is_empty() and delta >= 0.20:
		var unlocked_m: String = relay_locked_move
		relay_locked_move = ""
		if is_instance_valid(Events):
			Events.mechanic_lockout_changed.emit(unlocked_m, false, 0.0)
			
	for move in TRACKED_MOVES:
		move_overload[move] = max(0.0, float(move_overload.get(move, 0.0)) - delta * overload_relief_per_trick_sec)
		if float(locked_timers.get(move, 0.0)) > 0.0:
			locked_timers[move] = max(0.0, float(locked_timers[move]) - delta * 1.5)
			if float(locked_timers[move]) <= 0.0 and is_instance_valid(Events):
				Events.mechanic_lockout_changed.emit(move, false, 0.0)

func _trigger_move_lockout(move_name: String) -> void:
	var dominant: String = String(current_level_analysis.get("dominant_mechanic", "balanced"))
	var duration: float = default_lockout_duration * (0.65 if move_name == dominant else 1.0)
	locked_timers[move_name] = duration
	move_overload[move_name] = 0.0
	if is_instance_valid(Events):
		Events.mechanic_lockout_changed.emit(move_name, true, duration)

## Aktualizuje timery blokad oraz delikatne wygaszanie częstotliwości w czasie.
func update_timers_and_decay(delta: float) -> void:
	if _relay_climb_grace_timer > 0.0:
		_relay_climb_grace_timer = max(0.0, _relay_climb_grace_timer - delta)
		
	var needs_recalc: bool = false
	for move in TRACKED_MOVES:
		if float(locked_timers.get(move, 0.0)) > 0.0:
			locked_timers[move] = max(0.0, float(locked_timers[move]) - delta)
			if float(locked_timers[move]) <= 0.0 and is_instance_valid(Events):
				Events.mechanic_lockout_changed.emit(move, false, 0.0)
				
		if float(move_overload.get(move, 0.0)) > 0.0:
			move_overload[move] = max(0.0, float(move_overload[move]) - overload_passive_decay_per_sec * delta)
			
		if frequency_decay_per_sec > 0.0 and float(move_frequency_scores.get(move, 0.0)) > 0.0:
			move_frequency_scores[move] = max(0.0, float(move_frequency_scores[move]) - frequency_decay_per_sec * delta)
			needs_recalc = true
			
	if needs_recalc:
		_recalculate_multipliers()

## Kluczowy algorytm: przelicza mnożniki na podstawie wag i częstotliwości użycia,
## gwarantując, że suma mnożników ZAWSZE wynosi dokładnie `target_multiplier_sum`.
func _recalculate_multipliers() -> void:
	var count: int = TRACKED_MOVES.size()
	if count == 0:
		return
		
	var raw_pressures: Dictionary = {}
	var raw_sum: float = 0.0
	
	for move in TRACKED_MOVES:
		var w: float = max(0.05, float(move_weights.get(move, 1.0)))
		var sens: float = max(0.2, float(level_mechanic_sensitivity.get(move, 1.0)))
		var freq: float = max(0.0, float(move_frequency_scores.get(move, 0.0)))
		var pressure: float = w * (1.0 + adaptation_sensitivity * sens * freq)
		raw_pressures[move] = pressure
		raw_sum += pressure
		
	if raw_sum <= 0.0001:
		var eq: float = target_multiplier_sum / float(count)
		for move in TRACKED_MOVES:
			multipliers[move] = eq
		return
		
	var eff_min: float = min(min_multiplier, target_multiplier_sum / float(count))
	var eff_max: float = max(max_multiplier, target_multiplier_sum / float(count))
	
	var locked_set: Dictionary = {}
	var remaining_sum: float = target_multiplier_sum
	
	for _iter in range(count + 1):
		var free_pressure_sum: float = 0.0
		var free_moves: Array[String] = []
		for move in TRACKED_MOVES:
			if not locked_set.has(move):
				free_moves.append(move)
				free_pressure_sum += float(raw_pressures[move])
				
		if free_moves.is_empty():
			break
			
		var any_clamped: bool = false
		for move in free_moves:
			var share: float = (float(raw_pressures[move]) / free_pressure_sum) if free_pressure_sum > 0.0 else (1.0 / float(free_moves.size()))
			var candidate: float = remaining_sum * share
			if candidate < eff_min - 0.0001:
				multipliers[move] = eff_min
				locked_set[move] = true
				remaining_sum -= eff_min
				any_clamped = true
			elif candidate > eff_max + 0.0001:
				multipliers[move] = eff_max
				locked_set[move] = true
				remaining_sum -= eff_max
				any_clamped = true
			else:
				multipliers[move] = candidate
				
		if not any_clamped:
			break
			
	var current_sum: float = 0.0
	var adjust_move: String = TRACKED_MOVES[0]
	for move in TRACKED_MOVES:
		current_sum += float(multipliers[move])
		if not locked_set.has(move):
			adjust_move = move
	var diff: float = target_multiplier_sum - current_sum
	multipliers[adjust_move] = float(multipliers[adjust_move]) + diff
	
	if is_instance_valid(Events):
		Events.stamina_multipliers_updated.emit(multipliers.duplicate())
		Events.multiplier_changed.emit(float(multipliers.get("double_jump", 1.0)))

# ==============================================================================
# ANALIZATOR POZIOMU I RADAR DNA MECHANIK (Level Analyzer AI)
# ==============================================================================

func analyze_level(level_root: Node) -> Dictionary:
	var climb_score: float = 0.0
	var dash_score: float = 0.0
	var double_jump_score: float = 0.0
	var slide_score: float = 0.0
	var jewel_positions: Array[Vector2] = []
	var platform_rects: Array[Rect2] = []
	var hazard_rects: Array[Rect2] = []
	
	if level_root:
		_collect_level_features(level_root, platform_rects, hazard_rects, jewel_positions)
		
	for rect in platform_rects:
		if rect.size.y >= 90.0 and rect.size.x <= 48.0:
			climb_score += (rect.size.y / 90.0) * 1.4
		if rect.size.x >= 90.0 and rect.size.y <= 28.0 and rect.position.y > 200.0 and rect.position.y < 290.0:
			slide_score += 1.5
			dash_score += 0.5
			
	for i in range(platform_rects.size()):
		var a: Rect2 = platform_rects[i]
		for j in range(i + 1, platform_rects.size()):
			var b: Rect2 = platform_rects[j]
			var horiz_gap: float = max(0.0, max(a.position.x - b.end.x, b.position.x - a.end.x))
			var vert_diff: float = abs(a.position.y - b.position.y)
			
			if vert_diff < 35.0 and horiz_gap >= 75.0 and horiz_gap <= 260.0:
				dash_score += (horiz_gap / 100.0) * 1.2
			if horiz_gap < 180.0 and vert_diff >= 58.0 and vert_diff <= 145.0:
				double_jump_score += (vert_diff / 75.0) * 1.1
				
	for h_rect in hazard_rects:
		dash_score += max(0.8, h_rect.size.x / 85.0)
		double_jump_score += 0.4
		
	for j_pos in jewel_positions:
		if j_pos.y < 160.0:
			double_jump_score += 0.8
			climb_score += 0.4
		elif j_pos.y > 275.0:
			slide_score += 0.6
			
	climb_score = max(0.5, climb_score)
	dash_score = max(0.5, dash_score)
	double_jump_score = max(0.5, double_jump_score)
	
	var scores_map: Dictionary = {
		"double_jump": double_jump_score,
		"wall_climb": climb_score,
		"dash": dash_score
	}
	
	var total_score_sum: float = double_jump_score + climb_score + dash_score
	var share_dj: int = int(round((double_jump_score / total_score_sum) * 100.0))
	var share_wc: int = int(round((climb_score / total_score_sum) * 100.0))
	var share_da: int = 100 - share_dj - share_wc
	
	var sorted_moves: Array[String] = ["double_jump", "wall_climb", "dash"]
	sorted_moves.sort_custom(func(m1: String, m2: String) -> bool:
		return float(scores_map[m1]) > float(scores_map[m2])
	)
	
	var top_move: String = sorted_moves[0]
	var second_move: String = sorted_moves[1]
	var top_val: float = float(scores_map[top_move])
	var second_val: float = float(scores_map[second_move])
	
	var dominant: String = top_move
	if top_val <= second_val * 1.18:
		dominant = "balanced"
		
	current_level_analysis = {
		"dominant_mechanic": dominant,
		"primary_move": top_move,
		"secondary_mechanic": second_move,
		"scores": {
			"double_jump": snappedf(double_jump_score, 0.01),
			"wall_climb": snappedf(climb_score, 0.01),
			"dash": snappedf(dash_score, 0.01),
			"slide": snappedf(slide_score, 0.01)
		},
		"dna_shares": {
			"double_jump": share_dj,
			"wall_climb": share_wc,
			"dash": share_da
		},
		"jewel_count": jewel_positions.size()
	}
	
	if total_score_sum > 0.0:
		for move in TRACKED_MOVES:
			var move_share: float = float(scores_map[move]) / (total_score_sum / 3.0)
			level_mechanic_sensitivity[move] = clampf(1.0 / max(0.5, pow(move_share, 0.25)), 0.75, 1.35)
		_recalculate_multipliers()
		
	if is_instance_valid(Events):
		Events.level_analyzed.emit(current_level_analysis.duplicate(true))
		
	return current_level_analysis

func _collect_level_features(
	node: Node,
	platform_rects: Array[Rect2],
	hazard_rects: Array[Rect2],
	jewel_positions: Array[Vector2]
) -> void:
	# Warstwy czysto wizualne (np. kafelki Level 1 nad kolizjami prostokątnymi) pomijamy –
	# geometrię opisują już StaticBody2D, a tysiące kafelków spowalniałyby analizę O(n^2).
	if node.is_in_group("visual_only"):
		return
	if node is TileMapLayer:
		var tm := node as TileMapLayer
		var used_cells: Array[Vector2i] = tm.get_used_cells()
		var tile_size: Vector2 = Vector2(16, 16)
		if tm.tile_set:
			tile_size = Vector2(tm.tile_set.tile_size)
		for cell in used_cells:
			var world_pos: Vector2 = tm.to_global(tm.map_to_local(cell)) - tile_size * 0.5
			platform_rects.append(Rect2(world_pos, tile_size))
	elif node is StaticBody2D:
		var sb := node as StaticBody2D
		for child in sb.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				var r_shape := child.shape as RectangleShape2D
				var center: Vector2 = child.global_position
				platform_rects.append(Rect2(center - r_shape.size * 0.5, r_shape.size))
	elif node is Area2D:
		var area := node as Area2D
		var scr: Script = area.get_script()
		var scr_path: String = scr.resource_path if scr else ""
		if area.is_in_group("jewels") or scr_path.ends_with("jewel.gd") or area.name.begins_with("Jewel"):
			jewel_positions.append(area.global_position)
		elif scr_path.ends_with("hazard_area.gd") or area.collision_layer == 16:
			for child in area.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D:
					var r_shape := child.shape as RectangleShape2D
					var center: Vector2 = child.global_position
					hazard_rects.append(Rect2(center - r_shape.size * 0.5, r_shape.size))
					
	for child in node.get_children():
		_collect_level_features(child, platform_rects, hazard_rects, jewel_positions)

func get_dominant_mechanic_label() -> String:
	var dom: String = String(current_level_analysis.get("dominant_mechanic", "balanced"))
	match dom:
		"double_jump":
			return "AETHER (DOUBLE JUMP)"
		"wall_climb":
			return "ASCENT (WALL CLIMB)"
		"dash":
			return "MOMENTUM (AIR DASH)"
		_:
			return "SYNERGIA (FLOW)"
