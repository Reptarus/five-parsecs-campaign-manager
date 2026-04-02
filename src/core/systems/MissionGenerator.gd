@tool
extends Node
# This file should be referenced via preload
# Use explicit preloads instead of global class names


# Import necessary classes
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
func generate_mission(mission_type: int = GlobalEnums.MissionType.NONE) -> Dictionary:
	var valid_templates = []
	
	# Filter templates by mission type if specified
	if mission_type != GlobalEnums.MissionType.NONE:
		for template in mission_templates:
			if template.get("type", GlobalEnums.MissionType.NONE) == mission_type:
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
## NOTE: Enemy composition is determined at battle setup time using enemy_types.json
## and Core Rules encounter tables (pp.93-94), not at mission generation time.
## This returns an empty placeholder — actual composition is resolved by the battle pipeline.
func _generate_enemy_composition(_template: String) -> Array:
	return []

## Return mission difficulty from template data
## Core Rules has no difficulty point system — difficulty is narrative/contextual.
func _calculate_mission_difficulty(mission: Dictionary) -> int:
	return int(mission.get("difficulty", 1))

## Generate rewards for a mission (Core Rules p.120)
## Base pay is 1D6 credits. Modifiers (Easy +1, objective win, patron pay) are
## applied at post-battle resolution, not at mission generation time.
func _generate_rewards(_difficulty: int) -> Dictionary:
	return {
		"credits": rng.randi_range(1, 6),  # Core Rules p.120: 1D6 credits
		"reputation": 0,  # Handled by post-battle sequence
		"items": []  # Loot handled by LootSystemConstants tables
	}

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
		var mission_type = GlobalEnums.MissionType.values()[rng.randi() % GlobalEnums.MissionType.size()]
		if mission_type == GlobalEnums.MissionType.NONE:
			mission_type = GlobalEnums.MissionType.SABOTAGE
		
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