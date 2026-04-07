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
var bestiary_ref: Dictionary = {}  # RulesReference/Bestiary.json
var elite_enemies_ref: Dictionary = {}  # RulesReference/EliteEnemies.json
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

	# Load RulesReference data for cross-validation and elite enemies
	bestiary_ref = data_manager.load_json_file("res://data/RulesReference/Bestiary.json")
	elite_enemies_ref = data_manager.load_json_file("res://data/RulesReference/EliteEnemies.json")

	if enemy_data.is_empty():
		push_error("Failed to load enemy data from res://data/enemy_types.json")
		_load_fallback_enemy_data()
	else:
		
		# Extract loot tables and spawn rules
		loot_tables = enemy_data.get("enemy_loot_tables", {})
		spawn_rules = enemy_data.get("enemy_spawn_rules", {})
		
		# Build legacy compatibility structures
		_build_legacy_compatibility()
		
		enemy_data_loaded.emit(enemy_data.get("enemy_categories", []).size())

func _load_fallback_enemy_data() -> void:
	## Load fallback enemy data if JSON fails
	# Fallback categories using book names (Core Rules pp.94-103)
	enemy_categories = {
		"criminal_elements": ["Gangers", "Punks", "Raiders", "Cultists", "Pirates"],
		"hired_muscle": ["Unknown Mercs", "Enforcers", "Corporate Security", "Unity Grunts"],
		"interested_parties": ["Vigilantes", "Bounty Hunters", "Colonial Militia", "Salvage Team"],
		"roving_threats": ["Razor Lizards", "Sand Runners", "Large Bugs", "Vent Crawlers"]
	}

	# Book-accurate fallback stats
	enemy_stats_base = {
		"Gangers": {"combat_skill": 0, "toughness": 3, "speed": 4, "weapons": ["Handgun"]},
		"Punks": {"combat_skill": 0, "toughness": 3, "speed": 4, "weapons": ["Scrap Pistol"]},
		"Raiders": {"combat_skill": 1, "toughness": 3, "speed": 4, "weapons": ["Colony Rifle", "Blade"]},
		"Unknown Mercs": {"combat_skill": 1, "toughness": 4, "speed": 5, "weapons": ["Military Rifle"]},
		"Enforcers": {"combat_skill": 1, "toughness": 4, "speed": 4, "weapons": ["Military Rifle"]},
		"Corporate Security": {"combat_skill": 1, "toughness": 4, "speed": 4, "weapons": ["Military Rifle"]},
		"Razor Lizards": {"combat_skill": 1, "toughness": 3, "speed": 6, "weapons": ["Fangs"]},
		"Sand Runners": {"combat_skill": 0, "toughness": 3, "speed": 7, "weapons": ["Fangs"]}
	}

func _build_legacy_compatibility() -> void:
	## Build legacy enemy_categories structure from JSON data
	for category_data in enemy_data.get("enemy_categories", []):
		var category_id = category_data.get("id", "")
		var enemies = []

		for enemy in category_data.get("enemies", []):
			enemies.append(enemy.get("name", "Unknown"))

			# Populate legacy stats — JSON uses flat properties, not nested "stats"/"equipment"
			enemy_stats_base[enemy.get("name", "Unknown")] = {
				"combat_skill": enemy.get("combat_skill", 0),
				"toughness": enemy.get("toughness", 3),
				"speed": enemy.get("speed", 4),
				"weapons": _resolve_weapon_code(enemy.get("weapons", "1 A"))
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
	
	# Enhanced fallback logic using JSON category data (Core Rules p.94)
	if not enemy_data.get("enemy_categories", []).is_empty():
		match mission_type:
			"Patrol", "Investigate":
				return _select_from_categories(["criminal_elements", "hired_muscle"])
			"Hunt", "Bounty":
				return _select_from_categories(["criminal_elements", "interested_parties"])
			"Guard", "Defend":
				return _select_from_categories(["hired_muscle", "criminal_elements"])
			"Deliver", "Trade":
				return _select_from_categories(["criminal_elements", "hired_muscle"])
			"Explore":
				return _select_from_categories(["roving_threats", "interested_parties"])
			"Salvage":
				return _select_from_categories(["roving_threats", "interested_parties"])
			_:
				return _select_from_categories(["criminal_elements", "hired_muscle"])
	
	# Ultimate fallback using book category IDs
	match mission_type:
		"Patrol", "Investigate":
			return ["criminal_elements", "hired_muscle"].pick_random()
		"Hunt", "Bounty":
			return ["criminal_elements", "interested_parties"].pick_random()
		"Guard", "Defend":
			return ["hired_muscle", "criminal_elements"].pick_random()
		"Deliver", "Trade":
			return ["criminal_elements", "hired_muscle"].pick_random()
		"Explore":
			return ["roving_threats", "interested_parties"].pick_random()
		"Salvage":
			return ["roving_threats", "interested_parties"].pick_random()
		_:
			return "criminal_elements"

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
	return "criminal_elements"

func _calculate_enemy_count(
	difficulty: int, crew_size: int, is_quest: bool = false
) -> int:
	## Calculate enemy count based on crew size and difficulty (Core Rules p.63)
	##
	## Crew Size Rules (campaign crew size setting, NOT roster count):
	## - Size 6: Roll 2D6, pick HIGHER result
	## - Size 5: Roll 1D6
	## - Size 4: Roll 2D6, pick LOWER result
	##
	## Difficulty Modifiers (via DifficultyModifiers.gd):
	## - Challenging: Reroll 1s and 2s before picking
	## - Hardcore: Add +1 basic enemy to final count
	## - Insanity: +1 specialist enemy added separately (not here — see BattlePhase)
	## - Easy: Remove 1 Basic enemy if total is 5+ opponents
	##
	## Quest Mission Reroll (Core Rules p.99 — Interested Parties):
	## - During Quest missions, reroll any die scoring 1 once
	var base_count: int = 0
	var is_challenging := DifficultyModifiers.should_reroll_low_enemy_dice(difficulty)

	# Helper: roll a die with difficulty and quest reroll modifiers
	var _roll_die := func() -> int:
		var result := randi() % 6 + 1
		if is_challenging:
			# Reroll 1s and 2s once (Core Rules p.65: reroll before picking)
			if result <= 2:
				result = randi() % 6 + 1
		# Quest missions: reroll any die scoring 1 once (Core Rules p.99)
		elif is_quest and result == 1:
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

	# Step 2: Apply difficulty-based modifiers using DifficultyModifiers (Core Rules pp.64-65)
	# Hardcore: +1 basic enemy per battle
	var modifier: int = DifficultyModifiers.get_enemy_count_modifier(difficulty)
	base_count += modifier

	# Easy: Remove 1 Basic enemy if total would be 5+ (Core Rules Easy mode)
	var easy_reduction: int = DifficultyModifiers.get_easy_enemy_reduction(base_count, difficulty)
	base_count -= easy_reduction
	modifier -= easy_reduction

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
	var enemy_types: Array = enemy_categories.get(category, ["Thug"])
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

func _get_enemy_template_from_json(
	category: String, _difficulty: int
) -> Dictionary:
	## Get enemy template from JSON using D100 roll_range (book-accurate).
	## difficulty parameter preserved for API compatibility but not used
	## for selection — the Core Rules use flat D100 tables per category.
	return _roll_enemy_in_category(category)

func _calculate_enemy_threat_level(enemy_template: Dictionary) -> int:
	## Calculate threat level of enemy template
	## JSON uses flat properties: combat_skill, toughness (not nested stats)
	var combat: int = enemy_template.get("combat_skill", 0)
	var toughness: int = enemy_template.get("toughness", 3)

	# Simple threat calculation: (combat + toughness) / 2
	return max(1, (combat + toughness) / 2)

func _create_enemy_from_template(
	template: Dictionary, difficulty: int
) -> Resource:
	## Create enemy from JSON template with difficulty adjustments
	var enemy := Resource.new()

	# Basic information
	enemy.set_meta("id", template.get("id", "unknown"))
	enemy.set_meta("name", template.get("name", "Unknown Enemy"))

	# Stats — JSON uses flat properties, not nested "stats" sub-dict
	var base_stats := {
		"combat_skill": template.get("combat_skill", 0),
		"toughness": template.get("toughness", 3),
		"speed": template.get("speed", 4),
	}
	var modified_stats = _apply_json_difficulty_modifiers(
		base_stats, difficulty
	)

	enemy.set_meta("combat_skill", modified_stats.get("combat_skill", 0))
	enemy.set_meta("toughness", modified_stats.get("toughness", 3))
	enemy.set_meta("speed", modified_stats.get("speed", 4))

	# Weapons — JSON stores Core Rules notation (e.g., "2 A")
	var weapons: Array = _resolve_weapon_code(
		template.get("weapons", "1 A")
	)

	# HOUSE RULE: varied_armaments
	if HouseRulesHelper.is_enabled("varied_armaments"):
		weapons = _roll_varied_weapons(weapons)

	enemy.set_meta("weapons", weapons)

	# AI type and special rules from JSON
	enemy.set_meta("ai", template.get("ai", "A"))
	enemy.set_meta("panic", template.get("panic", "1-2"))
	enemy.set_meta("numbers", template.get("numbers", "+0"))
	enemy.set_meta(
		"special_rules", template.get("special_rules", [])
	)

	# Difficulty and category tracking
	enemy.set_meta("difficulty", difficulty)
	enemy.set_meta(
		"threat_level", _calculate_enemy_threat_level(template)
	)

	return enemy

func _apply_json_difficulty_modifiers(
	base_stats: Dictionary, difficulty: int
) -> Dictionary:
	## Apply difficulty modifiers to enemy stats
	var modified = base_stats.duplicate()

	# Difficulty uses GlobalEnums.DifficultyLevel values
	match difficulty:
		1: # Easy
			modified["combat_skill"] = max(
				0, modified.get("combat_skill", 0) - 1
			)
		3, 4, 5: # Hard, Veteran, Elite
			modified["combat_skill"] = (
				modified.get("combat_skill", 0) + 1
			)
			modified["toughness"] = (
				modified.get("toughness", 3) + 1
			)

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

func generate_enemies_as_dicts(
	mission_data: Dictionary, campaign_crew_size: int = 6
) -> Array[Dictionary]:
	## Generate enemies as Dictionary array using JSON data.
	## campaign_crew_size: the fixed campaign setting (4/5/6), NOT roster count.
	##
	## Core Rules order of operations (pp.92-93):
	## 1. Select enemy type (D100 encounter tables)
	## 2. Roll base enemy count (crew-size dice formula)
	## 3. Add Numbers modifier from enemy type
	## 4. Apply difficulty modifiers
	var danger_level: int = mission_data.get("danger_level", 2)
	var mission_source: String = mission_data.get(
		"mission_source", "patron"
	)
	var is_quest: bool = mission_data.get("is_quest", false)

	# Step 1: Select enemy type FIRST (Core Rules pp.91-94)
	var category: String = ""
	var template: Dictionary = {}
	var preset_enemy: String = mission_data.get("enemy_type", "")
	if not preset_enemy.is_empty() and preset_enemy != "Unknown Hostiles":
		template = _find_enemy_template_by_name(preset_enemy)
		if not template.is_empty():
			category = template.get("category", "")
	# Fallback: roll random enemy from D100 encounter table
	if template.is_empty():
		if not mission_source.is_empty():
			category = _roll_encounter_category(mission_source)
		else:
			var objective: String = mission_data.get("objective", "patrol")
			category = _determine_enemy_category(objective.capitalize())
		template = _roll_enemy_in_category(category)

	# Step 2: Roll base enemy count using campaign crew size (Core Rules p.63)
	var base_count: int = _calculate_enemy_count(
		danger_level, campaign_crew_size, is_quest)

	# Step 3: Add Numbers modifier from enemy type (Core Rules p.92)
	var numbers_mod: int = _parse_numbers_modifier(
		template.get("numbers", "+0"))
	var enemy_count: int = maxi(1, base_count + numbers_mod)

	var enemy_name: String = template.get("name", "Unknown Hostiles")
	var base_combat: int = template.get("combat_skill", 0)
	var base_tough: int = template.get("toughness", 3)
	var base_speed: int = template.get("speed", 4)
	var base_weapons: Array = _resolve_weapon_code(
		template.get("weapons", "1 A"))

	# Specialist/Lieutenant per Core Rules p.93
	var specialist_count: int = 0
	if enemy_count >= 7:
		specialist_count = 2
	elif enemy_count >= 3:
		specialist_count = 1
	var has_lieutenant: bool = (enemy_count >= 4)

	var enemies: Array[Dictionary] = []
	for i in range(enemy_count):
		var role: String = "standard"
		var combat_mod: int = 0
		var weapons: Array = base_weapons.duplicate()
		var extra_weapons: Array = []

		if has_lieutenant and i == 0:
			role = "lieutenant"
			combat_mod = 1
			extra_weapons = ["Blade"]
		elif specialist_count > 0 and i >= (enemy_count - specialist_count):
			role = "specialist"

		var display_name: String = enemy_name
		if role == "lieutenant":
			display_name = "%s Lieutenant" % enemy_name
		elif role == "specialist":
			display_name = "%s Specialist" % enemy_name

		enemies.append({
			"type": enemy_name,
			"name": display_name,
			"role": role,
			"combat_skill": base_combat + combat_mod,
			"toughness": base_tough,
			"reactions": 2 if role == "lieutenant" else 1,
			"speed": base_speed,
			"weapons": weapons + extra_weapons,
			"ai": template.get("ai", "A"),
			"panic": template.get("panic", "1-2"),
			"special_rules": template.get("special_rules", []),
			"is_leader": (role == "lieutenant"),
			"category": category,
		})

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
## D100 ENCOUNTER TABLE METHODS — Core Rules pp.94-103
## ═══════════════════════════════════════════════════════════════════════════════

func select_enemy_for_mission(mission_source: String) -> Dictionary:
	## Roll on D100 encounter tables to select enemy type for a mission.
	## Returns full enemy template dict with "category" key added.
	## mission_source: "patron", "opportunity", "quest", "unknown_rival"
	var category: String = _roll_encounter_category(mission_source)
	var template: Dictionary = _roll_enemy_in_category(category)
	if template.is_empty():
		# Fallback: pick any enemy from any category
		template = _roll_enemy_in_category("criminal_elements")
	template["category"] = category
	# Look up category-level rules (seize initiative modifier, etc.)
	for cat_data in enemy_data.get("enemy_categories", []):
		if cat_data.get("id", "") == category:
			template["category_name"] = cat_data.get("name", "")
			template["category_rules"] = cat_data.get(
				"category_rules", ""
			)
			template["seize_initiative_modifier"] = cat_data.get(
				"seize_initiative_modifier", 0
			)
			break
	return template

func _roll_encounter_category(mission_source: String) -> String:
	## Roll D100 on enemy_encounter_categories table (Core Rules p.94).
	## Returns category ID like "criminal_elements", "hired_muscle", etc.
	var tables: Dictionary = enemy_data.get(
		"enemy_encounter_categories", {}
	)
	var source_table: Dictionary = tables.get(
		mission_source, tables.get("patron", {})
	)

	if source_table.is_empty():
		return "criminal_elements"

	var roll: int = randi_range(1, 100)
	for category_id in source_table:
		var range_arr: Array = source_table[category_id]
		if range_arr.size() >= 2:
			if roll >= range_arr[0] and roll <= range_arr[1]:
				return category_id

	# Shouldn't reach here if D100 ranges are complete
	return "criminal_elements"

func _roll_enemy_in_category(category_id: String) -> Dictionary:
	## Roll D100 within a category to pick specific enemy type.
	## Uses per-enemy roll_range fields for book-accurate selection.
	for category_data in enemy_data.get("enemy_categories", []):
		if category_data.get("id", "") == category_id:
			var enemies: Array = category_data.get("enemies", [])
			if enemies.is_empty():
				return {}

			var roll: int = randi_range(1, 100)
			for enemy in enemies:
				var r: Array = enemy.get("roll_range", [0, 0])
				if r.size() >= 2 and roll >= r[0] and roll <= r[1]:
					return enemy

			# Fallback if roll didn't match (shouldn't happen)
			return enemies.pick_random()

	return {}

func _find_enemy_template_by_name(enemy_name: String) -> Dictionary:
	## Search all categories for an enemy matching the given name.
	## Used when a patron job specifies a preset enemy type.
	for category_data in enemy_data.get("enemy_categories", []):
		for enemy in category_data.get("enemies", []):
			if enemy.get("name", "") == enemy_name:
				var result: Dictionary = enemy.duplicate()
				result["category"] = category_data.get("id", "")
				return result
	return {}

## Public wrapper for dice-based enemy count formula (Core Rules p.63).
## Used by BattleSetupWizard and other external callers.
func calculate_enemy_count(
	difficulty: int, crew_size: int, is_quest: bool = false
) -> int:
	return _calculate_enemy_count(difficulty, crew_size, is_quest)

## Calculate enemy count for the Raided starship travel event (Core Rules p.70).
## Uses a DIFFERENT formula than standard battles — one step up in dice:
## - Crew 6: Roll 3D6, pick HIGHEST
## - Crew 5: Roll 2D6, pick HIGHEST
## - Crew 4: Roll 1D6
func calculate_raided_enemy_count(campaign_crew_size: int) -> int:
	match campaign_crew_size:
		6:
			# 3D6 pick highest
			var rolls: Array[int] = []
			for i in range(3):
				rolls.append(randi() % 6 + 1)
			return rolls.max()
		5:
			# 2D6 pick highest
			var roll1: int = randi() % 6 + 1
			var roll2: int = randi() % 6 + 1
			return max(roll1, roll2)
		4:
			# 1D6
			return randi() % 6 + 1
		_:
			# Default to crew 6 formula
			var rolls: Array[int] = []
			for i in range(3):
				rolls.append(randi() % 6 + 1)
			return rolls.max()

## ═══════════════════════════════════════════════════════════════════════════════
## NUMBERS MODIFIER PARSING — Core Rules p.92
## ═══════════════════════════════════════════════════════════════════════════════

func _parse_numbers_modifier(numbers_str) -> int:
	## Parse the Numbers modifier from enemy type (e.g. "+2", "+0", "+3").
	## Returns the integer modifier to add to base enemy count.
	var s: String = str(numbers_str).strip_edges()
	if s.begins_with("+"):
		return int(s.substr(1))
	return int(s)

## ═══════════════════════════════════════════════════════════════════════════════
## WEAPON CODE RESOLUTION — Core Rules weapon tables
## ═══════════════════════════════════════════════════════════════════════════════

func _resolve_weapon_code(weapon_code) -> Array:
	## Convert Core Rules weapon notation (e.g., "2 A") to weapon names.
	## Format: "N X" where N = weapon count column, X = table letter.
	## A = basic weapon_1, B = basic weapon_2, C = basic weapon_3.
	## Also handles already-resolved arrays and plain weapon names.
	if weapon_code is Array:
		return weapon_code

	var code_str: String = str(weapon_code).strip_edges()
	if code_str.is_empty():
		return ["Hand Gun"]

	# Check if it's a Core Rules notation like "1 A", "2 B", "3 C"
	var parts: PackedStringArray = code_str.split(" ")
	if parts.size() == 2 and parts[0].is_valid_int():
		var count: int = parts[0].to_int()
		var table_letter: String = parts[1].to_upper()
		return _roll_weapons_from_table(count, table_letter)

	# Plain weapon name (e.g., "Shotgun, Blade")
	if "," in code_str:
		var weapons: Array = []
		for w in code_str.split(","):
			weapons.append(w.strip_edges())
		return weapons

	return [code_str]

func _roll_weapons_from_table(
	count: int, table_letter: String
) -> Array:
	## Roll on weapon tables from enemy_types.json.
	## table_letter: A=weapon_1, B=weapon_2, C=weapon_3
	var weapon_tables: Dictionary = enemy_data.get(
		"weapon_tables", {}
	)
	var basic_table: Array = weapon_tables.get("basic", [])

	# Map table letter to column name
	var column: String
	match table_letter:
		"A":
			column = "weapon_1"
		"B":
			column = "weapon_2"
		"C":
			column = "weapon_3"
		_:
			column = "weapon_1"

	var weapons: Array = []
	for i in range(count):
		if basic_table.is_empty():
			weapons.append("Hand Gun")
			continue

		# Roll D6 for weapon table row
		var roll: int = randi_range(1, 6)
		var weapon_name: String = "Hand Gun"
		for row in basic_table:
			if row.get("roll", 0) == roll:
				weapon_name = row.get(column, "Hand Gun")
				# Handle combo weapons like "Scrap Pistol + Blade"
				break
		weapons.append(weapon_name)

	return weapons

## ═══════════════════════════════════════════════════════════════════════════════
## DEBUG LOGGING - Sprint 26.5: Enemy Count Calculation Tracing
## ═══════════════════════════════════════════════════════════════════════════════

## Debug flag - set to true to enable enemy count debug logging
var DEBUG_ENEMY_COUNT := false

func _debug_log_enemy_count(crew_size: int, difficulty: int, roll_method: String, rolls: Array, base_count: int, modifier: int, final_count: int) -> void:
	## Log enemy count calculation for debugging
	if not DEBUG_ENEMY_COUNT:
		return
	print_verbose("│ Dice Rolls: %s" % str(rolls))
	if modifier != 0:
		pass


func enable_debug_logging() -> void:
	## Enable enemy count debug logging
	DEBUG_ENEMY_COUNT = true


func disable_debug_logging() -> void:
	## Disable enemy count debug logging
	DEBUG_ENEMY_COUNT = false
