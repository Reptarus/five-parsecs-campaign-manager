@tool
extends Node
class_name RivalBattleGenerator

## Rival Battle Generator for Five Parsecs Campaign Manager
## Handles rival encounter mechanics, escalation, and battle generation

# Safe imports
# GlobalEnums available as autoload singleton
const Rival = preload("res://src/core/rivals/Rival.gd")

## Rival Battle Data Structure
class RivalBattle:
	var rival_id: String
	var battle_type: String  # "AMBUSH", "BROUGHT_FRIENDS", "SHOWDOWN", "ASSAULT", "RAID" (Core Rules p.91)
	var force_size: int = 3
	var force_composition: Array[Dictionary] = []
	var threat_level: int = 1
	var victory_conditions: Array[String] = []
	var defeat_consequences: Array[String] = []
	var special_rules: Array[String] = []
	var terrain_modifiers: Array[String] = []
	var escalation_level: int = 0
	
	func serialize() -> Dictionary:
		return {
			"rival_id": rival_id,
			"battle_type": battle_type,
			"force_size": force_size,
			"force_composition": force_composition,
			"threat_level": threat_level,
			"victory_conditions": victory_conditions,
			"defeat_consequences": defeat_consequences,
			"special_rules": special_rules,
			"terrain_modifiers": terrain_modifiers,
			"escalation_level": escalation_level
		}

## Rival Battle Generator Signals
signal rival_battle_generated(battle_data: RivalBattle)
signal rival_escalated(rival_id: String, new_threat_level: int)
signal rival_pursuit_triggered(rival_id: String, pursuit_data: Dictionary)
signal rival_defeated_permanently(rival_id: String)

## Battle generation data
var rival_force_templates: Dictionary = {}
var escalation_rules: Dictionary = {}
var battle_type_weights: Dictionary = {}
var _ref_data: Dictionary = {}  # Canonical JSON overlay (when available)

func _ready() -> void:
	_initialize_rival_data()

## Initialize rival battle data
func _initialize_rival_data() -> void:
	_load_ref_data()
	_load_force_templates()
	_load_escalation_rules()
	_load_battle_type_weights()

## Load canonical JSON overlay if available (data/rival_battles.json).
## Core Rules pp.91,119 define attack types (D10) and removal roll (4+),
## but not rival-specific force templates — those are app-defined groupings.
func _load_ref_data() -> void:
	var path := "res://data/rival_battles.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_ref_data = json.data
	file.close()

## Load rival force templates
func _load_force_templates() -> void:
	rival_force_templates = {
		"CRIMINAL_GANG": {
			"base_size": 4,
			"composition": [
				{"type": "gang_leader", "count": 1, "equipment": ["handgun", "armor"]},
				{"type": "gang_member", "count": 3, "equipment": ["scrap_pistol"]},
				{"type": "enforcer", "count": 0, "equipment": ["shotgun", "armor"]}  # Added when escalated
			],
			"special_rules": ["gang_tactics", "local_knowledge"],
			"preferred_terrain": ["urban", "industrial"]
		},
		"CORPORATE_SECURITY": {
			"base_size": 3,
			"composition": [
				{"type": "security_chief", "count": 1, "equipment": ["military_rifle", "combat_armor"]},
				{"type": "guard", "count": 2, "equipment": ["auto_rifle", "frag_vest"]},
				{"type": "heavy_trooper", "count": 0, "equipment": ["rattle_gun", "combat_armor"]}
			],
			"special_rules": ["corporate_resources", "advanced_equipment"],
			"preferred_terrain": ["corporate", "facility"]
		},
		"PIRATE_CREW": {
			"base_size": 5,
			"composition": [
				{"type": "pirate_captain", "count": 1, "equipment": ["hand_cannon", "boarding_saber"]},
				{"type": "pirate", "count": 4, "equipment": ["colony_rifle", "blade"]},
				{"type": "specialist", "count": 0, "equipment": ["blast_rifle", "gadget"]}
			],
			"special_rules": ["boarding_experience", "ruthless"],
			"preferred_terrain": ["spaceport", "ruins"]
		},
		"MERCENARY_UNIT": {
			"base_size": 3,
			"composition": [
				{"type": "merc_leader", "count": 1, "equipment": ["marksman_rifle", "combat_armor"]},
				{"type": "mercenary", "count": 2, "equipment": ["military_rifle", "frag_vest"]},
				{"type": "heavy_weapons", "count": 0, "equipment": ["plasma_rifle", "combat_armor"]}
			],
			"special_rules": ["professional", "coordinated"],
			"preferred_terrain": ["open", "defensive"]
		}
	}

## Load escalation rules
func _load_escalation_rules() -> void:
	escalation_rules = {
		"encounter_frequency": {
			0: {"chance": 10, "description": "Rare encounters"},
			1: {"chance": 20, "description": "Occasional encounters"},
			2: {"chance": 35, "description": "Regular encounters"},
			3: {"chance": 50, "description": "Frequent encounters"},
			4: {"chance": 65, "description": "Constant pursuit"}
		},
		"force_modifications": {
			0: {"size_mod": 0, "equipment_mod": 0},
			1: {"size_mod": 1, "equipment_mod": 0},
			2: {"size_mod": 1, "equipment_mod": 1},
			3: {"size_mod": 2, "equipment_mod": 1},
			4: {"size_mod": 3, "equipment_mod": 2}
		}
	}

## Load battle type weights based on situation (Core Rules p.91 — D10 table)
## Default weights match exact D10 probabilities:
##   1=Ambush(10%), 2-3=Brought Friends(20%), 4-7=Showdown(40%),
##   8=Assault(10%), 9-10=Raid(20%)
func _load_battle_type_weights() -> void:
	battle_type_weights = {
		"default": {
			"AMBUSH": 10,
			"BROUGHT_FRIENDS": 20,
			"SHOWDOWN": 40,
			"ASSAULT": 10,
			"RAID": 20
		},
		"high_escalation": {
			"AMBUSH": 10,
			"BROUGHT_FRIENDS": 25,
			"SHOWDOWN": 25,
			"ASSAULT": 15,
			"RAID": 25
		},
		"first_encounter": {
			"AMBUSH": 25,
			"BROUGHT_FRIENDS": 15,
			"SHOWDOWN": 40,
			"ASSAULT": 10,
			"RAID": 10
		}
	}

## Generate rival battle encounter
func generate_rival_battle(rival_data: Rival, current_turn: int, crew_size: int = 4) -> RivalBattle:
	var battle = RivalBattle.new()
	battle.rival_id = rival_data.rival_name  # Using name as ID for simplicity
	
	# Determine escalation level based on encounter history
	var escalation_level = _calculate_escalation_level(rival_data, current_turn)
	battle.escalation_level = escalation_level
	
	# Generate battle type
	battle.battle_type = _determine_battle_type(rival_data, escalation_level)
	
	# Generate force composition
	_generate_rival_force(battle, rival_data, crew_size)
	
	# Add special rules and conditions
	_apply_battle_conditions(battle, rival_data)
	
	# Set victory/defeat conditions
	_set_battle_outcomes(battle, rival_data)
	
	self.rival_battle_generated.emit(battle)
	
	return battle

## Calculate escalation level based on rival history
func _calculate_escalation_level(rival_data: Rival, current_turn: int) -> int:
	var escalation = 0
	
	# Increase based on number of encounters
	var encounter_count = rival_data.encounter_history.size()
	escalation += min(2, encounter_count)
	
	# Increase based on time since first encounter
	if encounter_count > 0:
		var first_encounter_turn = rival_data.encounter_history[0].get("turn", current_turn)
		var turns_elapsed = current_turn - first_encounter_turn
		escalation += min(2, turns_elapsed / 3)  # +1 every 3 turns
	
	# Increase based on rival reputation
	escalation += max(0, rival_data.reputation / 2)
	
	# Cap at maximum escalation
	return min(4, escalation)

## Determine battle type based on rival and situation
func _determine_battle_type(rival_data: Rival, escalation_level: int) -> String:
	var weights: Dictionary
	
	# Select weight table based on situation
	if rival_data.encounter_history.size() == 0:
		weights = battle_type_weights["first_encounter"]
	elif escalation_level >= 3:
		weights = battle_type_weights["high_escalation"]
	else:
		weights = battle_type_weights["default"]
	
	# Roll with weights
	var total_weight = 0
	for weight in weights.values():
		total_weight += weight
	
	var roll = randi_range(1, total_weight)
	var current_weight = 0
	
	for battle_type in weights:
		current_weight += weights[battle_type]
		if roll <= current_weight:
			return battle_type
	
	return "ASSAULT"  # Fallback (Core Rules p.91)

## Generate rival force composition
func _generate_rival_force(battle: RivalBattle, rival_data: Rival, crew_size: int) -> void:
	# Determine rival type from rival_data
	var rival_type = rival_data.rival_type if rival_data.rival_type != "" else "CRIMINAL_GANG"
	
	# Get force template
	var template = rival_force_templates.get(
		rival_type, rival_force_templates["CRIMINAL_GANG"])
	
	# Calculate base force size
	var base_size = template.base_size
	var escalation_mod = escalation_rules.force_modifications[battle.escalation_level].size_mod
	
	# Scale with crew size (rivals should be challenging but not overwhelming)
	var size_modifier = max(0, (crew_size - 4) / 2)  # +1 per 2 crew over 4
	
	battle.force_size = base_size + escalation_mod + size_modifier
	battle.threat_level = 1 + battle.escalation_level + (crew_size / 3)
	
	# Generate force composition
	battle.force_composition.clear()
	var composition = template.composition.duplicate(true)
	
	# Apply escalation modifications
	if battle.escalation_level >= 2:
		# Add specialists/heavy units
		for unit in composition:
			if unit.count == 0:  # These are escalation units
				unit.count = 1
	
	if battle.escalation_level >= 3:
		# Add more regular troops
		for unit in composition:
			if unit.type != "gang_leader" and unit.type != "security_chief" and unit.type != "pirate_captain" and unit.type != "merc_leader":
				unit.count += 1
	
	# Copy composition to battle
	for unit in composition:
		if unit.count > 0:
			battle.force_composition.append(unit.duplicate())
	
	# Add special rules from template
	battle.special_rules.assign(template.special_rules.duplicate())
	
	# Add escalation special rules
	if battle.escalation_level >= 2:
		battle.special_rules.append("reinforced")
	if battle.escalation_level >= 3:
		battle.special_rules.append("veteran_unit")
	if battle.escalation_level >= 4:
		battle.special_rules.append("elite_equipment")

## Apply battle-specific conditions (Core Rules p.91 — 5 rival attack types)
func _apply_battle_conditions(battle: RivalBattle, rival_data: Rival) -> void:
	match battle.battle_type:
		"AMBUSH":
			battle.special_rules.append("surprise_attack")
			battle.special_rules.append("prepared_positions")
			battle.terrain_modifiers.append("cover_bonus")

		"BROUGHT_FRIENDS":
			battle.special_rules.append("reinforced_numbers")
			battle.force_size += randi_range(1, 3)
			if battle.escalation_level >= 2:
				battle.special_rules.append("coordinated_strike")

		"SHOWDOWN":
			battle.special_rules.append("formal_challenge")
			battle.special_rules.append("honor_combat")
			battle.victory_conditions.append("defeat_leader")

		"ASSAULT":
			battle.special_rules.append("aggressive_assault")
			battle.special_rules.append("full_force_attack")
			battle.terrain_modifiers.append("no_prepared_defenses")

		"RAID":
			battle.special_rules.append("hit_and_run")
			battle.special_rules.append("mobile_engagement")
			battle.terrain_modifiers.append("escape_routes")

## Set victory and defeat conditions
func _set_battle_outcomes(battle: RivalBattle, rival_data: Rival) -> void:
	# Standard victory conditions
	battle.victory_conditions.assign(["defeat_all_enemies", "achieve_objectives"])
	
	# Escalation-specific conditions
	if battle.escalation_level >= 3:
		battle.victory_conditions.append("capture_leader")
	
	# Defeat consequences
	battle.defeat_consequences.assign(["crew_injuries", "equipment_loss"])
	
	if battle.escalation_level >= 2:
		battle.defeat_consequences.append("rival_escalation")
	
	if battle.escalation_level >= 4:
		battle.defeat_consequences.append("pursuit_continues")

## Check if rival should attack this turn
func should_rival_attack(rival_data: Rival, current_turn: int) -> bool:
	var escalation_level = _calculate_escalation_level(rival_data, current_turn)
	var attack_chance = escalation_rules.encounter_frequency[escalation_level].chance
	
	# Modify based on time since last encounter
	var turns_since_last = current_turn - rival_data.last_encounter_turn
	if turns_since_last >= 3:
		attack_chance += 15  # More likely if haven't encountered recently
	
	var roll = randi_range(1, 100)
	return roll <= attack_chance

## Process rival defeat
func process_rival_defeat(rival_data: Rival, battle_result: Dictionary) -> Dictionary:
	var result = {
		"rival_removed": false,
		"escalation_change": 0,
		"special_effects": []
	}
	
	# Check for permanent removal (Core Rules p.119 — 1D6 +mods, 4+ = removed)
	var removal_roll = randi_range(1, 6)
	var removal_threshold = 4  # Core Rules: 4+ to remove rival

	# Modifiers per Core Rules p.119
	if battle_result.get("tracked", false):
		removal_roll += 1  # +1 if rival was tracked
	if battle_result.get("leader_defeated", false):
		removal_roll += 1  # +1 if killed Unique Individual
	
	if removal_roll >= removal_threshold:
		result.rival_removed = true
		rival_data.active = false
		self.rival_defeated_permanently.emit(rival_data.rival_name)
	else:
		# Rival survives but may escalate or de-escalate
		if battle_result.get("crew_defeated", false):
			result.escalation_change = 1
			result.special_effects.append("increased_aggression")
		elif battle_result.get("decisive_victory", false):
			result.escalation_change = -1
			result.special_effects.append("reduced_activity")
	
	# Record encounter
	var encounter_data = {
		"battle_type": battle_result.get("battle_type", "unknown"),
		"result": "defeat" if result.rival_removed else "survived",
		"crew_casualties": battle_result.get("crew_casualties", 0),
		"escalation_level": _calculate_escalation_level(rival_data, battle_result.get("turn", 0))
	}
	rival_data.add_encounter(encounter_data)
	
	return result

## Generate pursuit mechanics when rival follows crew
func generate_pursuit_scenario(rival_data: Rival, destination_planet: String) -> Dictionary:
	var pursuit_chance = 30 + (rival_data.reputation * 10) + (_calculate_escalation_level(rival_data, 0) * 15)
	var pursuit_roll = randi_range(1, 100)
	
	var pursuit_data = {
		"rival_follows": pursuit_roll <= pursuit_chance,
		"pursuit_delay": randi_range(1, 3),  # Turns before rival arrives
		"pursuit_type": "standard"
	}
	
	if pursuit_data.rival_follows:
		# Determine pursuit type
		var pursuit_type_roll = randi_range(1, 6)
		if pursuit_type_roll <= 2:
			pursuit_data.pursuit_type = "immediate"  # Arrives same turn
			pursuit_data.pursuit_delay = 0
		elif pursuit_type_roll <= 4:
			pursuit_data.pursuit_type = "delayed"   # Arrives in 1-2 turns
		else:
			pursuit_data.pursuit_type = "tracked"   # Arrives in 2-3 turns, but knows location
		
		self.rival_pursuit_triggered.emit(rival_data.rival_name, pursuit_data)
	
	return pursuit_data

## Get rival threat assessment
func get_threat_assessment(rival_data: Rival, crew_size: int) -> Dictionary:
	var escalation_level = _calculate_escalation_level(rival_data, 0)
	var threat_multiplier = rival_data.get_threat_modifier()
	
	return {
		"escalation_level": escalation_level,
		"threat_rating": int(escalation_level * threat_multiplier * 2),
		"recommended_crew_size": 3 + escalation_level,
		"difficulty_assessment": _get_difficulty_name(escalation_level),
		"special_warnings": _get_threat_warnings(rival_data, escalation_level)
	}

## Get difficulty name for escalation level
func _get_difficulty_name(escalation_level: int) -> String:
	match escalation_level:
		0, 1: return "Manageable"
		2: return "Challenging"
		3: return "Dangerous"
		4: return "Extremely Dangerous"
	return "Unknown"

## Get special threat warnings
func _get_threat_warnings(rival_data: Rival, escalation_level: int) -> Array[String]:
	var warnings: Array[String] = []
	
	if escalation_level >= 3:
		warnings.append("High escalation - expect reinforced forces")
	
	if rival_data.encounter_history.size() >= 3:
		warnings.append("Experienced rival - knows crew tactics")
	
	if rival_data.reputation >= 3:
		warnings.append("High reputation rival - significant resources")
	
	return warnings

## Generate mock battle result for testing
func generate_mock_battle_result(battle: RivalBattle, crew_won: bool = true) -> Dictionary:
	return {
		"battle_type": battle.battle_type,
		"crew_won": crew_won,
		"total_victory": crew_won and randi_range(1, 6) >= 4,
		"decisive_victory": crew_won and randi_range(1, 6) >= 5,
		"leader_defeated": randi_range(1, 6) >= 4,
		"no_crew_losses": crew_won and randi_range(1, 6) >= 3,
		"crew_casualties": 0 if crew_won else randi_range(1, 2),
		"crew_defeated": not crew_won,
		"turn": 0
	}
