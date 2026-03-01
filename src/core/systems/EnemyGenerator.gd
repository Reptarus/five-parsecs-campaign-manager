class_name EnemyGenerator
extends Resource

## Enemy Generation System for Five Parsecs Campaign Manager
## Enhanced with JSON data integration for comprehensive enemy generation
## Uses data/enemy_types.json for detailed enemy configurations

# DataManager accessed via autoload singleton (not preload)
const HouseRulesHelper = preload("res://src/core/systems/HouseRulesHelper.gd")

signal enemies_generated(enemies: Array[Resource])
signal enemy_data_loaded(categories_count: int)
signal generation_failed(error: String)

# JSON data loaded from files
var enemy_data: Dictionary = {}
var loot_tables: Dictionary = {}
var spawn_rules: Dictionary = {}
var data_manager: Node = null  # DataManager autoload

# Legacy compatibility - fallback data
var enemy_categories: Dictionary = {}
var enemy_stats_base: Dictionary = {}

func _init() -> void:
	## Initialize enemy generator with JSON data
	_load_enemy_data()

func _load_enemy_data() -> void:
	## Load enemy data from JSON files
	data_manager = Engine.get_main_loop().root.get_node_or_null("/root/DataManager") if Engine.get_main_loop() else null
	
	# Load main enemy types data
	enemy_data = data_manager.load_json_file("res://data/enemy_types.json")
	if enemy_data.is_empty():
		push_error("Failed to load enemy data from res://data/enemy_types.json")
		_load_fallback_enemy_data()
	else:
		print("EnemyGenerator: Loaded %d enemy categories from JSON" % enemy_data.get("enemy_categories", []).size())
		
		# Extract loot tables and spawn rules
		loot_tables = enemy_data.get("enemy_loot_tables", {})
		spawn_rules = enemy_data.get("enemy_spawn_rules", {})
		
		# Build legacy compatibility structures
		_build_legacy_compatibility()
		
		enemy_data_loaded.emit(enemy_data.get("enemy_categories", []).size())

func _load_fallback_enemy_data() -> void:
	## Load fallback enemy data if JSON fails
	enemy_categories = {
		"criminal": ["Thug", "Gang Leader", "Crime Boss", "Hired Gun", "Smuggler"],
		"alien": ["K'Erin Warrior", "Swift Scout", "Engineer Tech", "Precursor", "Soulless"],
		"hostile": ["Converted", "Swarm Warrior", "Pirate", "Raider", "Mercenary"],
		"security": ["Unity Guard", "Corporate Security", "Local Militia", "Police Officer"],
		"wildlife": ["Predator", "Pack Hunter", "Giant Insect", "Toxic Creature"]
	}
	
	enemy_stats_base = {
		"Thug": {"combat_skill": 1, "toughness": 3, "speed": 4, "weapons": ["Blade", "Handgun"]},
		"Gang Leader": {"combat_skill": 2, "toughness": 4, "speed": 4, "weapons": ["Auto Pistol", "Blade"]},
		"K'Erin Warrior": {"combat_skill": 3, "toughness": 4, "speed": 5, "weapons": ["Blade", "Handgun"]},
		"Unity Guard": {"combat_skill": 2, "toughness": 4, "speed": 4, "weapons": ["Military Rifle", "Armor"]},
		"Pirate": {"combat_skill": 2, "toughness": 3, "speed": 4, "weapons": ["Shotgun", "Blade"]},
		"Converted": {"combat_skill": 2, "toughness": 5, "speed": 3, "weapons": ["Bio Weapon", "Armor"]},
		"Predator": {"combat_skill": 2, "toughness": 4, "speed": 6, "weapons": ["Natural Weapons"]}
	}

func _build_legacy_compatibility() -> void:
	## Build legacy enemy_categories structure from JSON data
	for category_data in enemy_data.get("enemy_categories", []):
		var category_id = category_data.get("id", "")
		var enemies = []
		
		for enemy in category_data.get("enemies", []):
			enemies.append(enemy.get("name", "Unknown"))
			
			# Also populate legacy stats
			enemy_stats_base[enemy.get("name", "Unknown")] = {
				"combat_skill": enemy.get("stats", {}).get("combat", 3),
				"toughness": enemy.get("stats", {}).get("toughness", 3),
				"speed": enemy.get("stats", {}).get("speed", 4),
				"weapons": enemy.get("equipment", {}).get("weapons", ["Basic Weapon"])
			}
		
		enemy_categories[category_id] = enemies

func generate_enemies_for_mission(mission: Resource, crew_size: int = 4) -> Array[Resource]:
	## Generate appropriate enemies for a mission based on Five Parsecs rules
	var enemies: Array[Resource] = []

	var mission_type = mission.get_meta("mission_type") if mission and mission.has_method("get_meta") else "Patrol"
	var difficulty = mission.get_meta("difficulty") if mission and mission.has_method("get_meta") else 1

	var enemy_category: String = _determine_enemy_category(mission_type)
	var enemy_count: int = _calculate_enemy_count(difficulty, crew_size)

	for i: int in range(enemy_count):
		var enemy: Resource = _create_enemy(enemy_category, difficulty)

		enemies.append(enemy)

	enemies_generated.emit(enemies)
	return enemies

func _determine_enemy_category(mission_type: String) -> String:
	## Determine enemy category based on mission type using JSON spawn rules
	var mission_spawn_rules = spawn_rules.get("mission_type", {})
	
	# Check if we have specific spawn rules for this mission type
	if mission_spawn_rules.has(mission_type):
		var rules = mission_spawn_rules[mission_type]
		var primary_categories = rules.get("primary", [])
		var secondary_categories = rules.get("secondary", [])
		
		# 70% chance for primary categories, 30% for secondary
		if randf() < 0.7 and not primary_categories.is_empty():
			return primary_categories.pick_random()
		elif not secondary_categories.is_empty():
			return secondary_categories.pick_random()
		elif not primary_categories.is_empty():
			return primary_categories.pick_random()
	
	# Enhanced fallback logic using JSON category data
	if not enemy_data.get("enemy_categories", []).is_empty():
		match mission_type:
			"Patrol", "Investigate":
				return _select_from_categories(["raiders", "corporate_security"])
			"Hunt", "Bounty":
				return _select_from_categories(["raiders", "alien_creatures"])
			"Guard", "Defend":
				return _select_from_categories(["raiders", "cultists"])
			"Deliver", "Trade":
				return _select_from_categories(["raiders", "corporate_security"])
			"Explore":
				return _select_from_categories(["alien_creatures", "cultists", "raiders"])
			"Salvage":
				return _select_from_categories(["raiders", "alien_creatures"])
			_:
				return _select_from_categories(["raiders", "corporate_security"])
	
	# Ultimate fallback to legacy system
	match mission_type:
		"Patrol", "Investigate":
			return ["criminal", "hostile"].pick_random()
		"Hunt", "Bounty":
			return ["criminal", "alien"].pick_random()
		"Guard", "Defend":
			return ["hostile", "criminal"].pick_random()
		"Deliver", "Trade":
			return ["criminal", "security"].pick_random()
		"Explore":
			return ["wildlife", "alien", "hostile"].pick_random()
		"Salvage":
			return ["criminal", "wildlife"].pick_random()
		_:
			return "criminal"

func _select_from_categories(preferred_categories: Array) -> String:
	## Select enemy category from preferred list, fallback to available categories
	var available_categories = []
	
	# Get available category IDs from JSON data
	for category_data in enemy_data.get("enemy_categories", []):
		available_categories.append(category_data.get("id", ""))
	
	# Try preferred categories first
	for category in preferred_categories:
		if category in available_categories:
			return category
	
	# Fallback to any available category
	if not available_categories.is_empty():
		return available_categories.pick_random()
	
	# Ultimate fallback
	return "raiders"

func _calculate_enemy_count(difficulty: int, crew_size: int) -> int:
	## Calculate enemy count based on crew size and difficulty (Core Rules p.63)
	##
	## Crew Size Rules:
	## - Size 6: Roll 2D6, pick HIGHER result
	## - Size 5: Roll 1D6
	## - Size 4: Roll 2D6, pick LOWER result
	##
	## Difficulty Modifiers:
	## - Challenging: Reroll 1s and 2s before picking (more enemies, still 1-6 range)
	## - Hardcore/Insanity: Add +1 to final count
	var base_count: int = 0
	var is_challenging := (difficulty == 3)  # CHALLENGING difficulty rerolls low dice

	# Helper function to roll a die, rerolling 1s and 2s for CHALLENGING
	var _roll_die := func() -> int:
		var result := randi() % 6 + 1
		if is_challenging:
			# Reroll 1s and 2s once (Core Rules: reroll before picking)
			if result <= 2:
				result = randi() % 6 + 1
		return result

	# Sprint 26.5: Track rolls for debug logging
	var rolls: Array = []
	var roll_method: String = ""

	# Step 1: Calculate base enemy count using crew-size-based dice rolling
	match crew_size:
		6:
			# Roll 2D6, pick higher
			var roll1: int = _roll_die.call()
			var roll2: int = _roll_die.call()
			rolls = [roll1, roll2]
			roll_method = "2D6 pick HIGHER"
			base_count = max(roll1, roll2)
		5:
			# Roll 1D6
			var roll1: int = _roll_die.call()
			rolls = [roll1]
			roll_method = "1D6"
			base_count = roll1
		4:
			# Roll 2D6, pick lower
			var roll1: int = _roll_die.call()
			var roll2: int = _roll_die.call()
			rolls = [roll1, roll2]
			roll_method = "2D6 pick LOWER"
			base_count = min(roll1, roll2)
		_:
			# Default to crew size 6 behavior for other sizes
			var roll1: int = _roll_die.call()
			var roll2: int = _roll_die.call()
			rolls = [roll1, roll2]
			roll_method = "2D6 pick HIGHER (default)"
			base_count = max(roll1, roll2)

	var pre_modifier_count: int = base_count
	var modifier: int = 0

	# Step 2: Apply difficulty-based modifiers (for non-CHALLENGING difficulties)
	match difficulty:
		1: # Easy (STORY) - reduce count slightly
			modifier = -1
			base_count = max(1, base_count - 1)
		4: # Hardcore - add +1 to count
			modifier = 1
			base_count += 1
		5: # Nightmare - significantly increase count
			modifier = 2
			base_count += 2

	# Ensure minimum of 1 enemy
	var final_count: int = max(1, base_count)

	# Sprint 26.5: Debug log the calculation
	_debug_log_enemy_count(crew_size, difficulty, roll_method, rolls, pre_modifier_count, modifier, final_count)

	return final_count
	##
func _create_enemy(category: String, difficulty: int) -> Resource:
	## Create a single enemy of specified category and difficulty using JSON data
	var enemy := Resource.new()

	# Try to use JSON data first
	var enemy_template = _get_enemy_template_from_json(category, difficulty)
	if not enemy_template.is_empty():
		return _create_enemy_from_template(enemy_template, difficulty)

	# Fallback to legacy system
	var enemy_types: Array[String] = enemy_categories.get(category, ["Thug"])
	var enemy_type: String = enemy_types.pick_random()

	var base_stats = enemy_stats_base.get(enemy_type, {
		"combat_skill": 1, "toughness": 3, "speed": 4, "weapons": ["Handgun"]
	})

	# Apply difficulty modifiers
	var modified_stats = _apply_difficulty_modifiers(base_stats, difficulty)

	# HOUSE RULE: varied_armaments - Each enemy gets individually rolled weapons
	var weapons = modified_stats.weapons
	if HouseRulesHelper.is_enabled("varied_armaments"):
		weapons = _roll_varied_weapons(weapons)

	# Set enemy properties
	enemy.set_meta("name", enemy_type)
	enemy.set_meta("category", category)
	enemy.set_meta("combat_skill", modified_stats.combat_skill)
	enemy.set_meta("toughness", modified_stats.toughness)
	enemy.set_meta("speed", modified_stats.speed)
	enemy.set_meta("weapons", weapons)
	enemy.set_meta("difficulty", difficulty)

	return enemy

func _get_enemy_template_from_json(category: String, difficulty: int) -> Dictionary:
	## Get enemy template from JSON data based on category and difficulty
	for category_data in enemy_data.get("enemy_categories", []):
		if category_data.get("id", "") == category:
			var enemies = category_data.get("enemies", [])

			# Filter enemies by difficulty if available
			var suitable_enemies = []
			for enemy in enemies:
				var enemy_threat = _calculate_enemy_threat_level(enemy)
				if enemy_threat <= difficulty:
					suitable_enemies.append(enemy)

			# If no suitable enemies found, use any from the category
			if suitable_enemies.is_empty():
				suitable_enemies = enemies

			if not suitable_enemies.is_empty():
				return suitable_enemies.pick_random()

	return {}

func _calculate_enemy_threat_level(enemy_template: Dictionary) -> int:
	## Calculate threat level of enemy template
	var stats = enemy_template.get("stats", {})
	var combat = stats.get("combat", 3)
	var toughness = stats.get("toughness", 3)

	# Simple threat calculation: (combat + toughness) / 2
	return max(1, (combat + toughness) / 2)

func _create_enemy_from_template(template: Dictionary, difficulty: int) -> Resource:
	## Create enemy from JSON template with difficulty adjustments
	var enemy := Resource.new()

	# Basic information
	enemy.set_meta("id", template.get("id", "unknown"))
	enemy.set_meta("name", template.get("name", "Unknown Enemy"))
	enemy.set_meta("description", template.get("description", ""))

	# Stats with difficulty modifiers
	var base_stats = template.get("stats", {})
	var modified_stats = _apply_json_difficulty_modifiers(base_stats, difficulty)

	enemy.set_meta("combat", modified_stats.get("combat", 3))
	enemy.set_meta("toughness", modified_stats.get("toughness", 3))
	enemy.set_meta("speed", modified_stats.get("speed", 4))
	enemy.set_meta("savvy", modified_stats.get("savvy", 2))

	# Equipment
	var equipment = template.get("equipment", {})
	var weapons = equipment.get("weapons", ["Basic Weapon"])

	# HOUSE RULE: varied_armaments - Each enemy gets individually rolled weapons
	if HouseRulesHelper.is_enabled("varied_armaments"):
		weapons = _roll_varied_weapons(weapons)

	enemy.set_meta("weapons", weapons)
	enemy.set_meta("armor", equipment.get("armor", "No Armor"))
	enemy.set_meta("gear", equipment.get("gear", []))

	# Abilities
	enemy.set_meta("abilities", template.get("abilities", []))

	# XP and loot
	enemy.set_meta("xp_value", template.get("xp_value", 1))
	enemy.set_meta("loot_table", template.get("loot_table", "common"))
	enemy.set_meta("tags", template.get("tags", []))

	# Difficulty and category tracking
	enemy.set_meta("difficulty", difficulty)
	enemy.set_meta("threat_level", _calculate_enemy_threat_level(template))

	return enemy

func _apply_json_difficulty_modifiers(base_stats: Dictionary, difficulty: int) -> Dictionary:
	## Apply difficulty modifiers to JSON enemy stats
	var modified = base_stats.duplicate()

	# Use spawn rules if available
	var difficulty_rules = spawn_rules.get("difficulty", {})
	var difficulty_name = _get_difficulty_name(difficulty)

	if difficulty_rules.has(difficulty_name):
		var rules = difficulty_rules[difficulty_name]
		var modifier = rules.get("enemy_count_modifier", 1.0)

		# Apply stat modifications based on difficulty
		if modifier < 1.0:  # Easy difficulty
			modified["combat"] = max(1, modified.get("combat", 3) - 1)
			modified["toughness"] = max(1, modified.get("toughness", 3) - 1)
		elif modifier > 1.3:  # Hard or higher difficulty
			modified["combat"] = modified.get("combat", 3) + 1
			modified["toughness"] = modified.get("toughness", 3) + 1
			modified["savvy"] = modified.get("savvy", 2) + 1

	return modified

func _get_difficulty_name(difficulty: int) -> String:
	## Convert difficulty number to name used in spawn rules
	match difficulty:
		1: return "EASY"
		2: return "NORMAL"
		3: return "HARD"
		4: return "VETERAN"
		5: return "ELITE"
		_: return "NORMAL"

func _apply_difficulty_modifiers(base_stats: Dictionary, difficulty: int) -> Dictionary:
	## Apply difficulty modifiers to enemy stats
	var modified = base_stats.duplicate()

	match difficulty:
		1: # Easy - reduce stats slightly
			modified.combat_skill = max(0, modified.combat_skill - 1)
			modified.toughness = max(1, modified.toughness - 1)
		3: # Hard - increase stats
			modified.combat_skill += 1
			modified.toughness += 1
			# Add better weapons for hard enemies
			if modified.weapons.size() == 1:
				modified.weapons.append("Armor")

	return modified

func _roll_varied_weapons(base_weapons: Array) -> Array:
	## Instead of all enemies having the same weapons, each gets a randomly selected subset
	if base_weapons.is_empty():
		return ["Basic Weapon"]

	# Pool of common weapon variants to add variety
	var weapon_variants = [
		"Handgun", "Auto Pistol", "Shotgun", "Military Rifle", "Colony Rifle",
		"Blade", "Club", "Hand Cannon", "Scrap Pistol", "Infantry Laser"
	]

	var varied_weapons = []

	# 70% chance to keep a base weapon, 30% chance to swap for a variant
	for weapon in base_weapons:
		if randf() < 0.7:
			varied_weapons.append(weapon)
		else:
			# Swap for a random variant
			varied_weapons.append(weapon_variants.pick_random())

	# Ensure at least one weapon
	if varied_weapons.is_empty():
		varied_weapons.append(base_weapons[0] if not base_weapons.is_empty() else "Handgun")

	return varied_weapons

func generate_enemies_as_dicts(mission_data: Dictionary, crew_size: int = 4) -> Array[Dictionary]:
	## Generate enemies as Dictionary array for Dictionary-based mission data.
	## Uses same JSON data (enemy_types.json) and Core Rules enemy count calculation.
	var objective: String = mission_data.get("objective", "patrol")
	var danger_level: int = mission_data.get("danger_level", 1)
	var enemy_type_hint: String = mission_data.get("enemy_type", "")

	# Determine enemy category from objective (reuses existing logic)
	var category: String = _determine_enemy_category(objective.capitalize())

	# Calculate count using Core Rules p.63 dice rules
	var enemy_count: int = _calculate_enemy_count(danger_level, crew_size)

	var enemies: Array[Dictionary] = []
	for i in range(enemy_count):
		var template: Dictionary = _get_enemy_template_from_json(category, danger_level)
		var is_leader: bool = (i == 0)

		if not template.is_empty():
			var stats: Dictionary = template.get("stats", {})
			var equip: Dictionary = template.get("equipment", {})
			var weapons: Array = equip.get("weapons", ["Hand Gun"])
			enemies.append({
				"type": enemy_type_hint if not enemy_type_hint.is_empty() else template.get("name", "Unknown"),
				"name": ("%s Leader" % template.get("name", "Enemy")) if is_leader else template.get("name", "Enemy #%d" % i),
				"combat": stats.get("combat", 3) + (1 if is_leader else 0),
				"toughness": stats.get("toughness", 3) + (1 if is_leader else 0),
				"reactions": 2 if is_leader else 1,
				"speed": stats.get("speed", 4),
				"savvy": stats.get("savvy", 2),
				"weapons": weapons,
				"armor": equip.get("armor", ""),
				"abilities": template.get("abilities", []),
				"is_leader": is_leader,
				"xp_value": template.get("xp_value", 1) + (1 if is_leader else 0)
			})
		else:
			# Fallback if no JSON template found
			enemies.append({
				"type": enemy_type_hint if not enemy_type_hint.is_empty() else "Unknown Hostiles",
				"name": ("%s Leader" % enemy_type_hint) if is_leader else ("%s #%d" % [enemy_type_hint, i]),
				"combat": (danger_level + 1) if is_leader else danger_level,
				"toughness": 4 if is_leader else 3,
				"reactions": 2 if is_leader else 1,
				"speed": 4,
				"savvy": 2,
				"weapons": ["Military Rifle"] if is_leader else ["Hand Gun"],
				"armor": "",
				"abilities": [],
				"is_leader": is_leader,
				"xp_value": 2 if is_leader else 1
			})

	print("EnemyGenerator: Generated %d enemies (category '%s', danger %d, crew %d)" % [
		enemies.size(), category, danger_level, crew_size])
	return enemies

func generate_random_encounter() -> Array[Resource]:
	## Generate a random encounter for unexpected battles
	var encounter_types = ["criminal", "wildlife", "hostile"]
	var category = encounter_types.pick_random()
	var count = randi_range(1, 3)
	var difficulty = randi_range(1, 2) # Random encounters are usually easier

	var enemies: Array[Resource] = []
	for i: int in range(count):
		var enemy: Resource = _create_enemy(category, difficulty)

		enemies.append(enemy)

	return enemies

func get_enemy_description(enemy: Resource) -> String:
	## Get a description of an enemy for UI display
	var name = enemy.get_meta("name") if enemy and enemy.has_method("get_meta") else "Unknown"
	var combat: int = enemy.get_meta("combat_skill") if enemy and enemy.has_method("get_meta") else 1
	var toughness: int = enemy.get_meta("toughness") if enemy and enemy.has_method("get_meta") else 3
	var weapons = enemy.get_meta("weapons") if enemy and enemy.has_method("get_meta") else []

	var weapon_text = weapons[0] if weapons.size() > 0 else "Unarmed"

	return "%s (Combat: %d, Toughness: %d) - Armed with %s" % [name, combat, toughness, weapon_text]

func get_enemy_threat_level(enemies: Array) -> String:
	## Calculate overall threat level of enemy group
	var total_threat: int = 0

	for enemy in enemies:
		var combat: int = enemy.get_meta("combat_skill") if enemy and enemy.has_method("get_meta") else 1
		var toughness: int = enemy.get_meta("toughness") if enemy and enemy.has_method("get_meta") else 3
		total_threat += combat + (toughness / 2.0)

	if total_threat <= 6:
		return "Low"
	elif total_threat <= 12:
		return "Medium"
	else:
		return "High"


## ═══════════════════════════════════════════════════════════════════════════════
## DEBUG LOGGING - Sprint 26.5: Enemy Count Calculation Tracing
## ═══════════════════════════════════════════════════════════════════════════════

## Debug flag - set to true to enable enemy count debug logging
var DEBUG_ENEMY_COUNT := false

func _debug_log_enemy_count(crew_size: int, difficulty: int, roll_method: String, rolls: Array, base_count: int, modifier: int, final_count: int) -> void:
	## Log enemy count calculation for debugging
	if not DEBUG_ENEMY_COUNT:
		return
	print("┌─────────────────────────────────────────────────────────────┐")
	print("│ ENEMY COUNT CALCULATION                                     │")
	print("├─────────────────────────────────────────────────────────────┤")
	print("│ Crew Size: %d" % crew_size)
	print("│ Difficulty: %d" % difficulty)
	print("│ Roll Method: %s" % roll_method)
	print("│ Dice Rolls: %s" % str(rolls))
	print("│ Base Count: %d" % base_count)
	if modifier != 0:
		print("│ Difficulty Modifier: %+d" % modifier)
	print("│ FINAL ENEMY COUNT: %d" % final_count)
	print("└─────────────────────────────────────────────────────────────┘")


func enable_debug_logging() -> void:
	## Enable enemy count debug logging
	DEBUG_ENEMY_COUNT = true
	print("EnemyGenerator: Enemy count debug logging ENABLED")


func disable_debug_logging() -> void:
	## Disable enemy count debug logging
	DEBUG_ENEMY_COUNT = false
	print("EnemyGenerator: Enemy count debug logging DISABLED")
