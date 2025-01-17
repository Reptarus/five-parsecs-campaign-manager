@tool
class_name MissionGenerator
extends Node

## Dependencies
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")
const Mission := preload("res://src/core/systems/Mission.gd")
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const RivalSystem := preload("res://src/core/rivals/RivalSystem.gd")
const PositionValidator := preload("res://src/core/systems/PositionValidator.gd")
const ResourceSystem := preload("res://src/core/systems/ResourceSystem.gd")
const EventManager := preload("res://src/core/managers/EventManager.gd")
const TableProcessor := preload("res://src/core/systems/TableProcessor.gd")
const TableLoader := preload("res://src/core/systems/TableLoader.gd")

var terrain_system: TerrainSystem
var rival_system: RivalSystem
var position_validator: PositionValidator
var resource_system: ResourceSystem
var event_manager: EventManager
var table_processor: TableProcessor

func _init() -> void:
	table_processor = TableProcessor.new()
	_load_mission_tables()

func _load_mission_tables() -> void:
	var tables = TableLoader.load_tables_from_directory("res://data/mission_tables")
	for table_name in tables:
		table_processor.register_table(tables[table_name])

func setup(
	_terrain_system: TerrainSystem,
	_rival_system: RivalSystem,
	_position_validator: PositionValidator,
	_resource_system: ResourceSystem,
	_event_manager: EventManager
) -> void:
	terrain_system = _terrain_system
	rival_system = _rival_system
	position_validator = _position_validator
	resource_system = _resource_system
	event_manager = _event_manager

## Generate a mission from a template
func generate_mission(template: MissionTemplate) -> Mission:
	if not template.validate():
		push_error("Invalid mission template")
		return null
		
	var mission := Mission.new()
	
	# Set basic mission properties
	mission.mission_type = template.type
	mission.mission_name = _generate_title(template)
	mission.description = _generate_description(template)
	mission.difficulty = _calculate_difficulty(template)
	mission.reward_range = template.reward_range
	
	# Set objectives using table processor
	mission.objectives = _generate_objectives(template)
	
	# Set deployment points and objective points
	mission.deployment_points = _generate_deployment_points(mission)
	mission.objective_points = _generate_objective_points(mission)
	
	# Set rewards with resource system integration
	var reward_data := _calculate_rewards(mission)
	mission.rewards = reward_data
	
	# Add rival involvement using table processor
	if rival_system and _should_add_rival():
		rival_system.setup_rival_involvement(mission)
	
	# Check for and apply mission events using table processor
	_check_mission_events(mission)
	
	return mission

func _should_add_rival() -> bool:
	var result = table_processor.roll_table("rival_involvement")
	return result["success"] and result["result"]

## Calculate base credit reward using table processor
func _calculate_base_credits(range: Vector2, difficulty: int) -> int:
	var result = table_processor.roll_table("credit_rewards", difficulty)
	if result["success"]:
		return result["result"]
	
	# Fallback to old calculation if table not found
	var base_reward := randi_range(int(range.x), int(range.y))
	var difficulty_modifier := 1.0 + (difficulty * 0.2)
	return roundi(base_reward * difficulty_modifier)

## Check for potential mission events using table processor
func _check_mission_events(mission: Mission) -> void:
	if not event_manager:
		return
	
	var event_types = ["RIVAL_INTERFERENCE", "UNEXPECTED_ALLIES", "ENVIRONMENTAL_HAZARD", "CRITICAL_INTEL"]
	
	for event_type in event_types:
		var result = table_processor.roll_table("mission_events")
		if result["success"] and result["result"].has(event_type):
			event_manager.trigger_mission_event(event_type, mission)

## Calculate mission rewards considering events
func _calculate_rewards(mission: Mission) -> Dictionary:
	var rewards := {}
	var base_credits := _calculate_base_credits(mission.reward_range, mission.difficulty)
	
	# Apply event modifiers if available
	if event_manager:
		var reward_multiplier = event_manager.get_mission_event_effect("rewards.multiplier")
		base_credits = roundi(base_credits * reward_multiplier)
	
	rewards["credits"] = base_credits
	
	# Add bonus rewards based on mission type using table processor
	var bonus_result = table_processor.roll_table("bonus_rewards", mission.mission_type)
	if bonus_result["success"]:
		rewards.merge(bonus_result["result"])
	else:
		# Fallback to old system
		match mission.mission_type:
			GameEnums.MissionType.RED_ZONE:
				rewards["reputation"] = 2
			GameEnums.MissionType.BLACK_ZONE:
				rewards["reputation"] = 3
				rewards["intel"] = 1
			GameEnums.MissionType.PATRON:
				rewards["reputation"] = 1
				if randf() <= 0.3:
					rewards["item"] = _generate_reward_item()
	
	return rewards

## Calculate mission difficulty using table processor
func _calculate_difficulty(template: MissionTemplate) -> int:
	var result = table_processor.roll_table("mission_difficulty", template.type)
	if result["success"]:
		var difficulty = result["result"]
		
		# Apply event modifiers if available
		if event_manager:
			var difficulty_multiplier = event_manager.get_mission_event_effect("mission_difficulty")
			difficulty = roundi(difficulty * difficulty_multiplier)
		
		return clampi(difficulty, 0, GameEnums.DifficultyLevel.size() - 1)
	
	# Fallback to old calculation
	var base_difficulty := randi_range(int(template.difficulty_range.x), int(template.difficulty_range.y))
	if event_manager:
		var difficulty_multiplier = event_manager.get_mission_event_effect("mission_difficulty")
		base_difficulty = roundi(base_difficulty * difficulty_multiplier)
	
	return clampi(base_difficulty, 0, GameEnums.DifficultyLevel.size() - 1)

## Generate objectives using table processor
func _generate_objectives(template: MissionTemplate) -> Array[Dictionary]:
	var objectives: Array[Dictionary] = []
	
	# Add primary objective
	objectives.append({
		"type": template.objective,
		"description": template.objective_description,
		"completed": false,
		"is_primary": true
	})
	
	# Add bonus objectives using table processor
	var bonus_result = table_processor.roll_table("bonus_objectives", template.type)
	if bonus_result["success"] and bonus_result["result"] is Array:
		for bonus in bonus_result["result"]:
			bonus["is_primary"] = false
			objectives.append(bonus)
	elif event_manager:
		# Fallback to event-based bonus objectives
		for event in event_manager.get_active_mission_events():
			if event.effects.has("bonus_objective") and event.effects.bonus_objective:
				var bonus_objective = event_manager._generate_bonus_objective(null)
				if not bonus_objective.is_empty():
					bonus_objective["is_primary"] = false
					objectives.append(bonus_objective)
	
	return objectives

## Generate deployment points using table processor
func _generate_deployment_points(mission: Mission) -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	# Get number of points from table
	var result = table_processor.roll_table("deployment_points")
	var num_points = 3 # Default
	if result["success"]:
		num_points = result["result"]
	
	# Modify based on active events
	if event_manager:
		for event in event_manager.get_active_mission_events():
			if event.effects.has("deployment_points"):
				num_points = event.effects.deployment_points
	
	# Generate points using position validator
	for _i in range(num_points):
		var point: Vector2 = position_validator.get_valid_deployment_point(points)
		if point != Vector2.ZERO:
			points.append(point)
	
	return points

## Generate objective points considering events
func _generate_objective_points(mission: Mission) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var num_points := mission.objectives.size()
	
	# Generate points using position validator
	for _i in range(num_points):
		var point: Vector2 = position_validator.get_valid_objective_point(points + mission.deployment_points)
		if point != Vector2.ZERO:
			points.append(point)
	
	return points

## Generate a reward item using table processor
func _generate_reward_item() -> Dictionary:
	var result = table_processor.roll_table("reward_items")
	if result["success"]:
		return result["result"]
	
	# Fallback to placeholder
	return {
		"type": "EQUIPMENT",
		"name": "Mystery Item",
		"value": 100
	}

## Generate mission title using table processor
func _generate_title(template: MissionTemplate) -> String:
	var result = table_processor.roll_table("mission_titles", template.type)
	if result["success"]:
		return result["result"]
	
	# Fallback to template
	if template.title_templates.is_empty():
		return "Untitled Mission"
	return template.title_templates.pick_random()

## Generate mission description using table processor
func _generate_description(template: MissionTemplate) -> String:
	var result = table_processor.roll_table("mission_descriptions", template.type)
	if result["success"]:
		return result["result"]
	
	# Fallback to template
	if template.description_templates.is_empty():
		return "No description available"
	return template.description_templates.pick_random()
