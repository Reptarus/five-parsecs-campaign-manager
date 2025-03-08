@tool
extends Node
# This file should be referenced via preload
# Use explicit preloads instead of global class names

const Self = preload("res://src/core/systems/MissionGenerator.gd")

# Import necessary classes
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const TableLoader = preload("res://src/core/systems/TableLoader.gd")
const TableProcessor = preload("res://src/core/systems/TableProcessor.gd")
const FiveParsecsGameState = preload("res://src/core/state/GameState.gd")

## Signals
signal mission_generated(mission_data: Dictionary)
signal mission_generation_failed(error: String)

## Mission Templates
var mission_templates: Array = []
var current_mission: Dictionary = {}
var mission_cache: Array = []

## Dependencies
var game_state: FiveParsecsGameState
var rng = RandomNumberGenerator.new()

## Initialize the generator
func _init() -> void:
	rng.randomize()
	_load_mission_templates()

## Load mission templates from data files
func _load_mission_templates() -> void:
	var mission_data_file = "res://data/mission_templates.json"
	var missions_file = FileAccess.open(mission_data_file, FileAccess.READ)
	
	if missions_file:
		var mission_json = JSON.parse_string(missions_file.get_as_text())
		
		if mission_json:
			if mission_json is Dictionary and mission_json.has("mission_templates"):
				mission_templates = mission_json["mission_templates"]
			elif mission_json is Array:
				mission_templates = mission_json
		
		missions_file.close()
	else:
		push_error("Failed to load mission templates from: " + mission_data_file)

## Set the game state reference
func set_game_state(state: FiveParsecsGameState) -> void:
	game_state = state

## Generate a mission of a specific type
func generate_mission(mission_type: int = GameEnums.MissionType.NONE) -> Dictionary:
	var valid_templates = []
	
	# Filter templates by mission type if specified
	if mission_type != GameEnums.MissionType.NONE:
		for template in mission_templates:
			if template.get("type", GameEnums.MissionType.NONE) == mission_type:
				valid_templates.append(template)
	else:
		valid_templates = mission_templates.duplicate()
	
	# If no valid templates, return empty mission
	if valid_templates.is_empty():
		mission_generation_failed.emit("No valid mission templates found")
		return {}
	
	# Select a random template
	var template = valid_templates[rng.randi() % valid_templates.size()]
	
	# Generate mission from template
	var mission = _generate_from_template(template)
	
	current_mission = mission
	mission_generated.emit(mission)
	
	return mission

## Generate mission from template
func _generate_from_template(template: Dictionary) -> Dictionary:
	var mission = template.duplicate(true)
	
	# Generate a unique ID
	mission["id"] = str(randi())
	
	# Generate random objectives if needed
	if mission.has("objectives") and mission["objectives"] is Array:
		var objectives = []
		for objective_template in mission["objectives"]:
			var objective = _generate_objective(objective_template)
			objectives.append(objective)
		mission["objectives"] = objectives
	
	# Generate enemy composition
	if mission.has("enemy_composition_template"):
		var enemy_comp = _generate_enemy_composition(mission["enemy_composition_template"])
		mission["enemy_composition"] = enemy_comp
		mission.erase("enemy_composition_template")
	
	# Calculate difficulty based on factors
	mission["difficulty"] = _calculate_mission_difficulty(mission)
	
	# Generate rewards based on difficulty
	mission["rewards"] = _generate_rewards(mission["difficulty"])
	
	return mission

## Generate objective from template
func _generate_objective(objective_template: Dictionary) -> Dictionary:
	var objective = objective_template.duplicate(true)
	
	# Replace variables in description
	if objective.has("description") and objective["description"] is String:
		var description = objective["description"]
		
		# Replace variables with actual values
		description = description.replace("%OBJECT%", _generate_random_object())
		description = description.replace("%LOCATION%", _generate_random_location())
		
		objective["description"] = description
	
	return objective

## Generate enemy composition based on template
func _generate_enemy_composition(template: String) -> Array:
	var enemies = []
	
	match template:
		"standard":
			# Generate standard enemy composition
			var enemy_count = rng.randi_range(4, 8)
			for i in range(enemy_count):
				var enemy = {
					"type": GameEnums.EnemyType.GANGERS,
					"rank": GameEnums.EnemyRank.MINION
				}
				enemies.append(enemy)
			
			# Add an elite
			enemies.append({
				"type": GameEnums.EnemyType.GANGERS,
				"rank": GameEnums.EnemyRank.ELITE
			})
		
		"boss":
			# Generate boss enemy composition
			var minion_count = rng.randi_range(3, 6)
			for i in range(minion_count):
				var enemy = {
					"type": GameEnums.EnemyType.GANGERS,
					"rank": GameEnums.EnemyRank.MINION
				}
				enemies.append(enemy)
			
			# Add elite guards
			var elite_count = rng.randi_range(1, 2)
			for i in range(elite_count):
				enemies.append({
					"type": GameEnums.EnemyType.GANGERS,
					"rank": GameEnums.EnemyRank.ELITE
				})
			
			# Add the boss
			enemies.append({
				"type": GameEnums.EnemyType.BOSS,
				"rank": GameEnums.EnemyRank.BOSS
			})
		
		"patrol":
			# Generate patrol enemy composition
			var enemy_count = rng.randi_range(3, 5)
			for i in range(enemy_count):
				var enemy = {
					"type": GameEnums.EnemyType.SECURITY_BOTS,
					"rank": GameEnums.EnemyRank.MINION
				}
				enemies.append(enemy)
		
		"raiders":
			# Generate raider enemy composition
			var enemy_count = rng.randi_range(5, 9)
			for i in range(enemy_count):
				var enemy = {
					"type": GameEnums.EnemyType.RAIDERS,
					"rank": GameEnums.EnemyRank.MINION
				}
				enemies.append(enemy)
			
			# Add an elite
			enemies.append({
				"type": GameEnums.EnemyType.RAIDERS,
				"rank": GameEnums.EnemyRank.ELITE
			})
	
	return enemies

## Calculate mission difficulty
func _calculate_mission_difficulty(mission: Dictionary) -> int:
	var base_difficulty = 1
	
	# Adjust based on enemy composition
	if mission.has("enemy_composition"):
		for enemy in mission["enemy_composition"]:
			match enemy.get("rank", GameEnums.EnemyRank.MINION):
				GameEnums.EnemyRank.MINION:
					base_difficulty += 1
				GameEnums.EnemyRank.ELITE:
					base_difficulty += 2
				GameEnums.EnemyRank.BOSS:
					base_difficulty += 4
	
	# Adjust based on mission type
	if mission.has("type"):
		match mission["type"]:
			GameEnums.MissionType.BLACK_ZONE:
				base_difficulty += 2
			GameEnums.MissionType.SABOTAGE:
				base_difficulty += 1
			GameEnums.MissionType.ASSASSINATION:
				base_difficulty += 3
	
	# Adjust based on objective count
	if mission.has("objectives"):
		base_difficulty += mission["objectives"].size() - 1
	
	# Cap difficulty between 1 and 5
	return clampi(base_difficulty, 1, 5)

## Generate rewards based on difficulty
func _generate_rewards(difficulty: int) -> Dictionary:
	var rewards = {
		"credits": difficulty * 100 + rng.randi_range(0, 50) * 10,
		"reputation": difficulty,
		"items": []
	}
	
	# Add bonus items based on difficulty
	var item_count = difficulty / 2
	for i in range(item_count):
		rewards["items"].append({
			"type": "random",
			"rarity": _get_rarity_for_difficulty(difficulty)
		})
	
	return rewards

## Get appropriate rarity for difficulty
func _get_rarity_for_difficulty(difficulty: int) -> int:
	match difficulty:
		1, 2:
			return GameEnums.ItemRarity.COMMON if rng.randf() < 0.8 else GameEnums.ItemRarity.UNCOMMON
		3:
			var roll = rng.randf()
			if roll < 0.6:
				return GameEnums.ItemRarity.COMMON
			elif roll < 0.9:
				return GameEnums.ItemRarity.UNCOMMON
			else:
				return GameEnums.ItemRarity.RARE
		4:
			var roll = rng.randf()
			if roll < 0.4:
				return GameEnums.ItemRarity.UNCOMMON
			elif roll < 0.8:
				return GameEnums.ItemRarity.RARE
			else:
				return GameEnums.ItemRarity.EPIC
		5:
			var roll = rng.randf()
			if roll < 0.3:
				return GameEnums.ItemRarity.RARE
			elif roll < 0.7:
				return GameEnums.ItemRarity.EPIC
			else:
				return GameEnums.ItemRarity.LEGENDARY
		_:
			return GameEnums.ItemRarity.COMMON

## Generate a random object name
func _generate_random_object() -> String:
	var objects = [
		"data chip",
		"ancient artifact",
		"weapon prototype",
		"experimental device",
		"quantum core",
		"AI matrix",
		"navigation module",
		"alien sample",
		"encrypted drive",
		"rare mineral sample"
	]
	
	return objects[rng.randi() % objects.size()]

## Generate a random location name
func _generate_random_location() -> String:
	var locations = [
		"abandoned facility",
		"research lab",
		"mining complex",
		"ancient ruins",
		"corporate headquarters",
		"military outpost",
		"space station",
		"settlement outskirts",
		"orbital platform",
		"deep caverns"
	]
	
	return locations[rng.randi() % locations.size()]

## Get available missions
func get_available_missions() -> Array:
	# Return cached missions if available
	if not mission_cache.is_empty():
		return mission_cache
	
	# Generate new missions
	var missions = []
	var mission_count = rng.randi_range(2, 4)
	
	for i in range(mission_count):
		var mission_type = GameEnums.MissionType.values()[rng.randi() % GameEnums.MissionType.size()]
		if mission_type == GameEnums.MissionType.NONE:
			mission_type = GameEnums.MissionType.SABOTAGE
		
		var mission = generate_mission(mission_type)
		if not mission.is_empty():
			missions.append(mission)
	
	mission_cache = missions
	return missions

## Clear the mission cache
func clear_mission_cache() -> void:
	mission_cache.clear()

## Get mission by ID
func get_mission_by_id(mission_id: String) -> Dictionary:
	for mission in mission_cache:
		if mission.get("id", "") == mission_id:
			return mission
	
	return {}