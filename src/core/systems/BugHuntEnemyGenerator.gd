class_name BugHuntEnemyGenerator
extends RefCounted

## Generates Bug Hunt enemies from contact marker reveals.
## Loads data from the bug_hunt JSON data files for enemy species,
## subtypes, leaders, and spawn rules.

const ENEMIES_PATH := "res://data/bug_hunt/bug_hunt_enemies.json"
const SUBTYPES_PATH := "res://data/bug_hunt/bug_hunt_alien_subtypes.json"
const LEADERS_PATH := "res://data/bug_hunt/bug_hunt_alien_leaders.json"
const SPAWN_PATH := "res://data/bug_hunt/bug_hunt_spawn_rules.json"

var _enemies_data: Dictionary = {}
var _subtypes_data: Dictionary = {}
var _leaders_data: Dictionary = {}
var _spawn_data: Dictionary = {}
var _loaded: bool = false

## Track campaign state for enemy generation
var _current_enemy_type: Dictionary = {}  # The enemy type for this mission
var _enemy_type_determined: bool = false
var _encounters_this_mission: int = 0  # How many contacts revealed so far
var _leader_dice_remaining: int = 3  # D12 pool for pack leader detection
var _leaders_spawned: int = 0
var _mission_number: int = 0  # For pack leader availability check


func _init() -> void:
	_load_data()


func _load_data() -> void:
	_enemies_data = _load_json(ENEMIES_PATH)
	_subtypes_data = _load_json(SUBTYPES_PATH)
	_leaders_data = _load_json(LEADERS_PATH)
	_spawn_data = _load_json(SPAWN_PATH)
	_loaded = not _enemies_data.is_empty()


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("BugHuntEnemyGenerator: File not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("BugHuntEnemyGenerator: JSON parse error in %s" % path)
		return {}
	return json.data if json.data is Dictionary else {}


## ============================================================================
## MISSION SETUP
## ============================================================================

func start_mission(mission_number: int) -> void:
	## Reset generator for a new mission.
	_current_enemy_type = {}
	_enemy_type_determined = false
	_encounters_this_mission = 0
	_leader_dice_remaining = 3
	_leaders_spawned = 0
	_mission_number = mission_number


## ============================================================================
## CONTACT REVEAL — THE CORE MECHANIC
## ============================================================================

func reveal_contact(encounter_modifier: int = 0) -> Dictionary:
	## Called when a Contact marker is detected and rolls 3-6 (CONTACT!).
	## Returns a Dictionary with enemy figures to place:
	##   {enemy_type, count, figures[], subtype, leader}
	if not _loaded:
		push_warning("BugHuntEnemyGenerator: Data not loaded")
		return {}

	# First contact determines enemy type for the entire mission
	if not _enemy_type_determined:
		_current_enemy_type = _roll_enemy_type()
		_enemy_type_determined = true

	_encounters_this_mission += 1

	# Determine number of enemies
	var numbers_formula: String = _current_enemy_type.get("numbers", "1D6")
	var count := _roll_numbers(numbers_formula) + encounter_modifier
	count = maxi(count, 1)  # Always at least 1

	# Generate individual enemy figures
	var figures: Array = []
	for i in range(count):
		figures.append(_create_enemy_figure(_current_enemy_type))

	# Check for subtype (if this enemy type has been encountered before)
	var subtype: Dictionary = {}
	if _encounters_this_mission > 1:
		subtype = _roll_subtype()
		if not subtype.is_empty():
			_apply_subtype(figures, subtype)

	# Check for pack leader (from 3rd mission onwards, max 3 per mission)
	var leader: Dictionary = {}
	if _mission_number >= 3 and _leader_dice_remaining > 0:
		leader = _check_for_leader(count)

	return {
		"enemy_type": {
			"id": _current_enemy_type.get("id", "unknown"),
			"name": _current_enemy_type.get("name", "Unknown Enemy"),
			"special_rules": _current_enemy_type.get("special_rules", "")
		},
		"count": figures.size(),
		"figures": figures,
		"subtype": subtype,
		"leader": leader,
		"encounter_number": _encounters_this_mission
	}


## ============================================================================
## ENEMY TYPE (D100)
## ============================================================================

func _roll_enemy_type() -> Dictionary:
	var roll := (randi() % 100) + 1
	var enemies: Array = _enemies_data.get("enemies", [])
	for enemy in enemies:
		if enemy is Dictionary and enemy.has("d100_range"):
			var range_val: Array = enemy.d100_range
			if range_val.size() >= 2 and roll >= range_val[0] and roll <= range_val[1]:
				return enemy
	# Fallback to first enemy
	return enemies[0] if not enemies.is_empty() else {}


func _roll_numbers(formula: String) -> int:
	## Parse dice formulas like "1D6", "1D3+2", "1D6+1"
	var result: int = 0
	var upper := formula.to_upper().strip_edges()

	if upper.contains("D"):
		var parts := upper.split("+")
		var dice_part := parts[0].strip_edges()
		var bonus: int = 0
		if parts.size() > 1:
			bonus = int(parts[1].strip_edges())

		var dice_split := dice_part.split("D")
		var num_dice: int = int(dice_split[0]) if dice_split[0] != "" else 1
		var die_sides: int = int(dice_split[1])

		for i in range(num_dice):
			result += (randi() % die_sides) + 1
		result += bonus
	else:
		result = int(upper)

	return result


func _create_enemy_figure(enemy_type: Dictionary) -> Dictionary:
	return {
		"speed": enemy_type.get("speed", 4),
		"combat_skill": enemy_type.get("combat_skill", 0),
		"toughness": enemy_type.get("toughness", 4),
		"damage": enemy_type.get("damage", 1),
		"enemy_id": enemy_type.get("id", "unknown"),
		"is_leader": false,
		"is_wounded": false
	}


## ============================================================================
## SUBTYPES (D6)
## ============================================================================

func _roll_subtype() -> Dictionary:
	var roll := (randi() % 6) + 1
	var subtypes: Array = _subtypes_data.get("subtypes", [])
	for st in subtypes:
		if st is Dictionary:
			if st.has("d6_value") and st.d6_value == roll:
				return st
	return {}


func _apply_subtype(figures: Array, subtype: Dictionary) -> void:
	## Apply subtype modifications to the enemy figures.
	var sub_id: String = subtype.get("id", "")

	match sub_id:
		"swarmers":
			# One additional enemy per contact reveal
			var extra := _create_enemy_figure(_current_enemy_type)
			figures.append(extra)
		"runners":
			# +1" movement speed
			for fig in figures:
				fig["speed"] = fig.get("speed", 4) + 1
		"spitters":
			# Ranged spit attack: any 6 hits within 6", Damage 1
			for fig in figures:
				fig["special_rule"] = "Spitter: Ranged attack within 6\" — roll 1D6, 6 hits (Damage 1, armor applies)"
		"ambushers":
			# Deploy within/behind closest terrain within 4" of marker
			for fig in figures:
				fig["special_rule"] = "Ambusher: Deploy within/behind closest terrain within 4\" of contact marker"
		"toughs":
			# 5+ saving throw vs Area weapons (or 4+ if existing save)
			for fig in figures:
				var existing_save: int = fig.get("saving_throw", 0)
				if existing_save > 0:
					fig["saving_throw"] = 4
				else:
					fig["saving_throw"] = 5
				fig["special_rule"] = "Tough: %d+ saving throw vs Area weapons" % fig["saving_throw"]
		"screamers":
			# End of Enemy Action: D10 <= enemies on table → spawn 1 more at center
			for fig in figures:
				fig["special_rule"] = "Screamer: End of Enemy Action — roll D10; if <= enemies on table, spawn +1 at center"

	# Tag all figures with the subtype for rule enforcement
	for fig in figures:
		fig["subtype"] = sub_id


## ============================================================================
## PACK LEADERS (D12 pool, D6 type)
## ============================================================================

func _check_for_leader(enemies_revealed: int) -> Dictionary:
	## Roll D12 dice from the remaining pool. If any roll <= enemies_revealed,
	## a pack leader is present. Discard one D12 from pool.
	if _leader_dice_remaining <= 0 or _leaders_spawned >= 3:
		return {}

	var leader_present := false
	for i in range(_leader_dice_remaining):
		var roll := (randi() % 12) + 1
		if roll <= enemies_revealed:
			leader_present = true
			break

	if not leader_present:
		return {}

	_leader_dice_remaining -= 1
	_leaders_spawned += 1

	# Roll D6 for leader type
	var type_roll := (randi() % 6) + 1
	var leaders: Array = _leaders_data.get("leaders", [])
	for leader in leaders:
		if leader is Dictionary and leader.get("d6_value", 0) == type_roll:
			return leader.duplicate()
	return {}


## ============================================================================
## CONTACT TABLE (D6 — called when a marker is detected)
## ============================================================================

func roll_contact_table() -> Dictionary:
	## Roll on the Contact Table (D6). Returns the result.
	## 1 = Stay frosty, 2 = Movement all over, 3-6 = CONTACT!
	var roll := (randi() % 6) + 1
	var contact_table: Array = _spawn_data.get("contact_markers", {}).get("contact_table", [])

	for entry in contact_table:
		if entry is Dictionary:
			if entry.has("d6_value") and entry.d6_value == roll:
				return {"roll": roll, "result": entry.duplicate()}
			elif entry.has("d6_range"):
				var range_val: Array = entry.d6_range
				if range_val.size() >= 2 and roll >= range_val[0] and roll <= range_val[1]:
					return {"roll": roll, "result": entry.duplicate()}

	return {"roll": roll, "result": {}}


## ============================================================================
## PRIORITY SPAWNING ("Beep... Sir?")
## ============================================================================

func roll_priority_spawning(priority: int, is_living_nightmare: bool = false) -> int:
	## Roll D6s equal to Priority. Count 6s for new Contact markers.
	## Returns number of new Contact markers to place.
	## On Living Nightmare, each 6 = 1 marker. Otherwise, any 6 = 1 marker total.
	var sixes: int = 0
	for i in range(priority):
		var roll := (randi() % 6) + 1
		if roll == 6:
			sixes += 1

	if sixes == 0:
		return 0

	if is_living_nightmare:
		return sixes
	else:
		return 1 if sixes > 0 else 0


## ============================================================================
## ACCESSORS
## ============================================================================

func get_current_enemy_type() -> Dictionary:
	return _current_enemy_type.duplicate()


func is_enemy_type_determined() -> bool:
	return _enemy_type_determined


func get_encounters_this_mission() -> int:
	return _encounters_this_mission


func get_leaders_spawned() -> int:
	return _leaders_spawned
