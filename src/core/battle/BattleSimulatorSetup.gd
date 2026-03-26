class_name BattleSimulatorSetup
extends RefCounted

## Generates standalone battle parameters for the Battle Simulator.
## Creates temporary crew, selects enemies from enemy_types.json,
## and fabricates a mission context for TacticalBattleUI.

const CharacterTableRoller := preload("res://src/core/character/Generation/CharacterTableRoller.gd")

const ENEMY_TYPES_PATH := "res://data/enemy_types.json"
const MISSION_TEMPLATES_PATH := "res://data/mission_templates.json"

var _enemy_data: Dictionary = {}
var _mission_data: Dictionary = {}


func _init() -> void:
	_enemy_data = _load_json(ENEMY_TYPES_PATH)
	_mission_data = _load_json(MISSION_TEMPLATES_PATH)


## Returns enemy categories for UI dropdown: [{id, name}]
func get_enemy_categories() -> Array:
	var categories: Array = []
	for cat in _enemy_data.get("enemy_categories", []):
		categories.append({
			"id": cat.get("id", ""),
			"name": cat.get("name", "Unknown")
		})
	return categories


## Returns enemies within a specific category
func get_enemies_for_category(category_id: String) -> Array:
	for cat in _enemy_data.get("enemy_categories", []):
		if cat.get("id", "") == category_id:
			return cat.get("enemies", [])
	return []


## Returns all mission template types for UI dropdown: [{type, title_templates}]
func get_mission_types() -> Array:
	var types: Array = []
	for template in _mission_data.get("mission_templates", []):
		types.append({
			"type": template.get("type", "UNKNOWN"),
		})
	return types


## Generate a complete battle context from user config.
## config: {crew_size: int, enemy_category: String, enemy_type: String,
##          mission_type: String, difficulty: int}
## Returns: {crew: Array, enemies: Array, mission_data: Dictionary}
func generate_battle_context(config: Dictionary) -> Dictionary:
	var crew_size: int = clampi(config.get("crew_size", 4), 3, 6)
	var difficulty: int = clampi(config.get("difficulty", 2), 1, 5)
	var enemy_category: String = config.get("enemy_category", "")
	var enemy_type_id: String = config.get("enemy_type", "")
	var mission_type: String = config.get("mission_type", "")

	var crew: Array = _generate_crew(crew_size)
	var enemy_type: Dictionary = _select_enemy_type(enemy_category, enemy_type_id)
	var enemies: Array = _generate_enemy_squad(enemy_type, difficulty)
	var mission: Dictionary = _generate_mission(mission_type, enemy_type)

	return {
		"crew": crew,
		"enemies": enemies,
		"mission_data": mission,
	}


## Generate temporary crew members as lightweight dicts.
func _generate_crew(count: int) -> Array:
	var crew: Array = []
	for i in range(count):
		crew.append({
			"name": CharacterTableRoller.generate_random_name(),
			"character_name": CharacterTableRoller.generate_random_name(),
			"combat_skill": randi_range(0, 2),
			"toughness": randi_range(3, 5),
			"savvy": randi_range(0, 2),
			"reactions": randi_range(1, 3),
			"speed": randi_range(4, 5),
			"luck": randi_range(0, 1),
		})
		# Sync name fields
		crew[i]["name"] = crew[i]["character_name"]
	return crew


## Select an enemy type by category + id, or random.
func _select_enemy_type(category_id: String, enemy_id: String) -> Dictionary:
	# Random selection
	if category_id.is_empty() or category_id == "random":
		var categories: Array = _enemy_data.get("enemy_categories", [])
		if categories.is_empty():
			return _fallback_enemy()
		var cat: Dictionary = categories[randi() % categories.size()]
		var enemies: Array = cat.get("enemies", [])
		if enemies.is_empty():
			return _fallback_enemy()
		return enemies[randi() % enemies.size()]

	# Specific category
	var enemies: Array = get_enemies_for_category(category_id)
	if enemies.is_empty():
		return _fallback_enemy()

	# Random within category
	if enemy_id.is_empty() or enemy_id == "random":
		return enemies[randi() % enemies.size()]

	# Specific enemy type
	for enemy in enemies:
		if enemy.get("id", "") == enemy_id:
			return enemy

	return enemies[randi() % enemies.size()]


## Generate enemy squad dicts from the selected type + difficulty.
func _generate_enemy_squad(enemy_type: Dictionary, difficulty: int) -> Array:
	# Parse numbers modifier (e.g. "+2", "+0", "+3")
	var numbers_str: String = str(enemy_type.get("numbers", "+0"))
	var numbers_mod: int = 0
	if numbers_str.begins_with("+"):
		numbers_mod = int(numbers_str.substr(1))
	else:
		numbers_mod = int(numbers_str)

	# Base count + numbers modifier + difficulty adjustment
	var base_count: int = 5
	var difficulty_mod: int = 0
	match difficulty:
		1: difficulty_mod = -1
		2: difficulty_mod = 0
		3: difficulty_mod = 0
		4: difficulty_mod = 1
		5: difficulty_mod = 2

	var total: int = maxi(2, base_count + numbers_mod + difficulty_mod)

	var squad: Array = []
	var enemy_name: String = enemy_type.get("name", "Unknown Enemy")
	var combat_skill: int = int(enemy_type.get("combat_skill", 0))
	var toughness: int = int(enemy_type.get("toughness", 3))
	var speed_val: int = int(enemy_type.get("speed", 4))
	var panic: String = str(enemy_type.get("panic", "1-2"))
	var ai: String = str(enemy_type.get("ai", "A"))
	var weapons: String = str(enemy_type.get("weapons", "1 A"))
	var special_rules: Array = enemy_type.get("special_rules", [])

	for i in range(total):
		squad.append({
			"name": "%s %d" % [enemy_name, i + 1],
			"combat_skill": combat_skill,
			"toughness": toughness,
			"speed": speed_val,
			"reactions": 1,
			"panic": panic,
			"ai": ai,
			"weapons": weapons,
			"special_rules": special_rules,
		})

	return squad


## Generate mission data dict for TacticalBattleUI.
func _generate_mission(mission_type: String, enemy_type: Dictionary) -> Dictionary:
	var template: Dictionary = {}
	var templates: Array = _mission_data.get("mission_templates", [])

	if mission_type.is_empty() or mission_type == "RANDOM":
		if not templates.is_empty():
			template = templates[randi() % templates.size()]
	else:
		for t in templates:
			if t.get("type", "") == mission_type:
				template = t
				break
		if template.is_empty() and not templates.is_empty():
			template = templates[0]

	var title_templates: Array = template.get("title_templates", ["Battle Simulation"])
	var title: String = title_templates[randi() % title_templates.size()] if not title_templates.is_empty() else "Battle Simulation"
	# Replace template placeholders
	title = title.replace("{LOCATION}", "Sector %d" % randi_range(1, 99))

	var objectives: Array = template.get("objectives", [])
	var objective: Dictionary = objectives[randi() % objectives.size()] if not objectives.is_empty() else {"type": "FIGHT", "description": "Eliminate all opposition"}

	return {
		"title": title,
		"type": template.get("type", "OPPORTUNITY"),
		"objective": objective.get("description", "Eliminate all opposition"),
		"objective_type": objective.get("type", "FIGHT"),
		"battle_type": 0,
		"difficulty": template.get("difficulty_range", {}).get("min", 1),
		"enemy_name": enemy_type.get("name", "Unknown"),
		"enemy_category_rules": enemy_type.get("category_rules", ""),
		"special_rules": enemy_type.get("special_rules", []),
	}


## Fallback enemy if data loading fails.
func _fallback_enemy() -> Dictionary:
	return {
		"id": "fallback_raiders",
		"name": "Raiders",
		"numbers": "+1",
		"panic": "1-2",
		"speed": 4,
		"combat_skill": 1,
		"toughness": 3,
		"ai": "A",
		"weapons": "2 A",
		"special_rules": [],
	}


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("BattleSimulatorSetup: Could not load %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		file.close()
		return json.data
	file.close()
	return {}
