class_name PlanetfallTacticalEnemyGenerator
extends RefCounted

## Generates Tactical Enemy profiles and assigns weapons from D100/D6 tables.
## Campaign starts with 3 tactical enemies (generated at milestones 1, 2, 3).
## Source: Planetfall pp.149-153

var _enemy_types: Array = []
var _weapon_profiles: Array = []
var _weapon_traits: Dictionary = {}
var _grunt_weapons: Array = []
var _specialist_weapons: Array = []
var _leader_weapons: Array = []
var _leader_rules: Dictionary = {}
var _loaded: bool = false


func _init() -> void:
	_load_tables()


## ============================================================================
## DATA LOADING
## ============================================================================

func _load_tables() -> void:
	var data: Dictionary = _load_json(
		"res://data/planetfall/tactical_enemies_generation.json")
	_enemy_types = data.get("enemy_types", [])
	_weapon_profiles = data.get("weapon_profiles", [])
	_weapon_traits = data.get("weapon_traits", {})
	_leader_rules = data.get("leader_rules", {})

	var grunt_data: Dictionary = data.get("grunt_weapons", {})
	_grunt_weapons = grunt_data.get("entries", [])

	var spec_data: Dictionary = data.get("specialist_weapons", {})
	_specialist_weapons = spec_data.get("entries", [])

	var leader_data: Dictionary = data.get("leader_weapons", {})
	_leader_weapons = leader_data.get("entries", [])

	_loaded = not _enemy_types.is_empty()


func _load_json(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("PlanetfallTacticalEnemyGenerator: JSON not found: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("PlanetfallTacticalEnemyGenerator: JSON parse error: %s" % path)
		file.close()
		return {}
	file.close()
	if json.data is Dictionary:
		return json.data
	return {}


## ============================================================================
## ENEMY TYPE GENERATION
## ============================================================================

func generate_enemy_type(roll: int) -> Dictionary:
	## D100 lookup to determine enemy type. Returns the type entry.
	return _lookup_d100(_enemy_types, roll)


const ENEMY_TYPE_DIE := "Planetfall Tactical Enemy Type"


## One roll on the p.149 table. p.125 Scout Down! also uses this for an enemy that "does
## not add that enemy to your map".
func roll_enemy_type() -> Dictionary:
	return generate_enemy_type(_d100(ENEMY_TYPE_DIE))


func create_full_enemy(campaign: Resource) -> Dictionary:
	## Full generation: roll type + weapons + create state fields.
	## Returns a complete tactical enemy dict ready for campaign.tactical_enemies.
	var type_roll: int = _d100(ENEMY_TYPE_DIE)
	var enemy_type: Dictionary = generate_enemy_type(type_roll)
	if enemy_type.is_empty():
		return {}

	# Assign weapons
	var grunt_weapon: Dictionary = _roll_weapon_table(_grunt_weapons, GRUNT_WEAPONS_DIE)
	var specialist_weapon: Dictionary = _roll_weapon_table(_specialist_weapons,
			SPECIALIST_WEAPONS_DIE)
	var leader_weapon: Dictionary = _roll_weapon_table(_leader_weapons, LEADER_WEAPONS_DIE)

	# Build full enemy record
	var enemy: Dictionary = {
		"type": enemy_type.duplicate(),
		"type_roll": type_roll,
		"grunt_weapon": grunt_weapon,
		"specialist_weapon": specialist_weapon,
		"leader_weapon": leader_weapon,
		"enemy_info": 0,
		"boss_located": false,
		"strongpoint_located": false,
		"defeated": false,
		"occupied_sectors": []
	}

	# Add to campaign if provided
	if campaign and "tactical_enemies" in campaign:
		campaign.tactical_enemies.append(enemy)

	return enemy


func get_enemy_count_for_battle(enemy_type: Dictionary) -> int:
	## Roll the number formula from enemy type (e.g., "2D3+3"). p.151: "Weapons and
	## numbers encountered are generated for each battle."
	var formula: String = enemy_type.get("number", "1D6+3")
	return _evaluate_dice_formula(formula)


## The largest result a Number formula can give: p.129 Assault starts "with the maximum
## enemy encounter size (for example if this is normally 1D3+5, it would be 8)".
func max_of_formula(formula: String) -> int:
	var result: int = 0
	for part in formula.to_upper().split("+"):
		part = part.strip_edges()
		if "D" in part:
			var dice_parts: PackedStringArray = part.split("D")
			var count: int = int(dice_parts[0]) if dice_parts[0].length() > 0 else 1
			result += count * (int(dice_parts[1]) if dice_parts.size() > 1 else 6)
		else:
			result += int(part)
	return result


## The current table entry for a type id. A campaign stores a COPY of its enemy's entry
## when the enemy is generated, so keys added to the data later (K'Erin Champion, p.150)
## are read from here.
func type_by_id(type_id: String) -> Dictionary:
	for entry in _enemy_types:
		if entry is Dictionary and str(entry.get("id", "")) == type_id:
			return entry.duplicate(true)
	return {}


## ============================================================================
## WEAPON ASSIGNMENT
## ============================================================================

func get_weapon_profile(weapon_id: String) -> Dictionary:
	## Look up a weapon profile by ID.
	for wp in _weapon_profiles:
		if wp is Dictionary and wp.get("id", "") == weapon_id:
			return wp.duplicate()
	return {}


func get_weapon_trait_description(trait_id: String) -> String:
	return _weapon_traits.get(trait_id, "")


func assign_battle_weapons(enemy_type: Dictionary) -> Dictionary:
	## Roll weapons for an entire encounter group.
	## Returns {grunt_weapons: Array, specialist_weapon: Dict, leader_weapon: Dict}.
	var grunt_roll: Dictionary = _roll_weapon_table(_grunt_weapons, GRUNT_WEAPONS_DIE)
	var spec_roll: Dictionary = _roll_weapon_table(_specialist_weapons, SPECIALIST_WEAPONS_DIE)
	var leader_roll: Dictionary = _roll_weapon_table(_leader_weapons, LEADER_WEAPONS_DIE)

	# Resolve weapon IDs to full profiles
	var grunt_profiles: Array = []
	for wid in grunt_roll.get("weapons", []):
		grunt_profiles.append(get_weapon_profile(wid))

	var spec_profiles: Array = []
	for wid in spec_roll.get("weapons", []):
		spec_profiles.append(get_weapon_profile(wid))

	var leader_profiles: Array = []
	# Leaders carry grunt weapon PLUS leader weapon
	for wid in grunt_roll.get("weapons", []):
		leader_profiles.append(get_weapon_profile(wid))
	for wid in leader_roll.get("weapons", []):
		leader_profiles.append(get_weapon_profile(wid))

	return {
		"grunt_weapons": grunt_profiles,
		"specialist_weapons": spec_profiles,
		"leader_weapons": leader_profiles
	}


## ============================================================================
## LEADER/BOSS RULES
## ============================================================================

func get_leader_threshold() -> int:
	return _leader_rules.get("threshold", 6)


## p.149 "Leaders have 1 KP"; a type with its own value (K'Erin Champion, p.150) wins.
func get_leader_kp(enemy_type: Dictionary = {}) -> int:
	return int(enemy_type.get("leader_kp", _leader_rules.get("leader_kp", 1)))


## p.149: "Bosses have 2 KP and add +1 to both their Combat Skill and Toughness."
func get_boss_stats(enemy_type: Dictionary = {}) -> Dictionary:
	return {
		"kp": int(enemy_type.get("boss_kp", _leader_rules.get("boss_kp", 2))),
		"combat_bonus": _leader_rules.get("boss_combat_bonus", 1),
		"toughness_bonus": _leader_rules.get("boss_toughness_bonus", 1)
	}


## ============================================================================
## DICE (every roll through DiceManager so the QA seam can force it)
## ============================================================================

const GRUNT_WEAPONS_DIE := "Planetfall Enemy Grunt Weapons"
const SPECIALIST_WEAPONS_DIE := "Planetfall Enemy Specialist Weapons"
const LEADER_WEAPONS_DIE := "Planetfall Enemy Leader Weapons"
const NUMBER_DIE := "Planetfall Enemy Number"


static func _dice() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("/root/DiceManager") \
		if loop is SceneTree else null


func _d100(context: String) -> int:
	var dm := _dice()
	return int(dm.roll_d100(context)) if dm else randi_range(1, 100)


## One die of the Number formula. D3 and D6 are the only sizes on the p.149 table.
func _die(sides: int, context: String) -> int:
	var dm := _dice()
	if dm == null:
		return randi_range(1, sides)
	if sides == 3:
		return int(dm.roll_d3(context))
	if sides == 6:
		return int(dm.roll_d6(context))
	return randi_range(1, sides)


## ============================================================================
## PRIVATE
## ============================================================================

func _roll_weapon_table(table: Array, context: String) -> Dictionary:
	var dm := _dice()
	var roll: int = int(dm.roll_d6(context)) if dm else randi_range(1, 6)
	for entry in table:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func _evaluate_dice_formula(formula: String) -> int:
	## Parse simple dice formulas like "2D3+3", "1D6+3", "1D3+5".
	var result: int = 0
	var parts: PackedStringArray = formula.to_upper().split("+")
	for part in parts:
		part = part.strip_edges()
		if "D" in part:
			var dice_parts: PackedStringArray = part.split("D")
			var count: int = int(dice_parts[0]) if dice_parts[0].length() > 0 else 1
			var sides: int = int(dice_parts[1]) if dice_parts.size() > 1 else 6
			# One context per die size: a forced 5 meant for a D6 would be DISCARDED by
			# a D3 roll (DiceManager never clamps), so they cannot share a key.
			for _i in range(count):
				result += _die(sides, "%s D%d" % [NUMBER_DIE, sides])
		else:
			result += int(part)
	return result


func _lookup_d100(table: Array, roll: int) -> Dictionary:
	for entry in table:
		if entry is Dictionary:
			if roll >= entry.get("min", 0) and roll <= entry.get("max", 0):
				return entry.duplicate()
	return {}


func is_loaded() -> bool:
	return _loaded
