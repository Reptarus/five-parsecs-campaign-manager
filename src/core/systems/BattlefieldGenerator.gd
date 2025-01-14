@tool
extends Node

## Dependencies
const TableProcessor := preload("res://src/core/systems/TableProcessor.gd")
const TableLoader := preload("res://src/core/systems/TableLoader.gd")
const PositionValidator := preload("res://src/core/systems/PositionValidator.gd")
const Mission := preload("res://src/core/systems/Mission.gd")
const GameEnums := preload("res://src/core/systems/GlobalEnums.gd")

## Signals
signal battlefield_generated(battlefield_data: Dictionary)
signal generation_failed(reason: String)

## Variables
var table_processor: TableProcessor
var position_validator: PositionValidator

## Constants
const BATTLEFIELD_TABLES_PATH := "res://data/battlefield_tables"
const MIN_BATTLEFIELD_SIZE := Vector2(20, 20)
const MAX_BATTLEFIELD_SIZE := Vector2(50, 50)

func _init() -> void:
	table_processor = TableProcessor.new()
	_load_battlefield_tables()

func _load_battlefield_tables() -> void:
	var tables = TableLoader.load_tables_from_directory(BATTLEFIELD_TABLES_PATH)
	for table_name in tables:
		table_processor.register_table(tables[table_name])

## Setup the generator with required dependencies
func setup(_position_validator: PositionValidator) -> void:
	position_validator = _position_validator

## Generate a battlefield for a mission
func generate_battlefield(mission: Mission) -> Dictionary:
	var battlefield_data := {}
	
	# Generate base terrain
	var terrain_result = table_processor.roll_table("terrain_types", mission.mission_type)
	if not terrain_result["success"]:
		generation_failed.emit("Failed to generate terrain")
		return {}
	
	battlefield_data["terrain"] = terrain_result["result"]
	
	# Calculate battlefield size based on mission parameters
	var size_multiplier := _calculate_size_multiplier(mission)
	battlefield_data["size"] = _calculate_battlefield_size(size_multiplier)
	
	# Generate cover elements
	var cover_elements := _generate_cover_elements(
		battlefield_data["terrain"],
		mission.mission_type,
		mission.difficulty
	)
	battlefield_data["cover"] = cover_elements
	
	# Generate hazard features
	var hazards := _generate_hazard_features(
		battlefield_data["terrain"],
		mission.mission_type,
		mission.difficulty
	)
	battlefield_data["hazards"] = hazards
	
	# Generate strategic points
	var strategic_points := _generate_strategic_points(
		battlefield_data["terrain"],
		mission.mission_type,
		mission.difficulty
	)
	battlefield_data["strategic_points"] = strategic_points
	
	# Validate the generated battlefield
	if not _validate_battlefield(battlefield_data):
		generation_failed.emit("Failed to validate battlefield")
		return {}
	
	battlefield_generated.emit(battlefield_data)
	return battlefield_data

## Calculate size multiplier based on mission parameters
func _calculate_size_multiplier(mission: Mission) -> float:
	var base_multiplier := 1.0
	
	# Adjust for mission type
	match mission.mission_type:
		GameEnums.MissionType.RED_ZONE:
			base_multiplier *= 1.2
		GameEnums.MissionType.BLACK_ZONE:
			base_multiplier *= 0.8
		GameEnums.MissionType.PATRON:
			base_multiplier *= 1.0
	
	# Adjust for difficulty
	base_multiplier *= (1.0 + (mission.difficulty * 0.1))
	
	return base_multiplier

## Calculate battlefield size based on multiplier
func _calculate_battlefield_size(multiplier: float) -> Vector2:
	var base_size := Vector2(30, 30)
	var adjusted_size := base_size * multiplier
	
	return Vector2(
		clampf(adjusted_size.x, MIN_BATTLEFIELD_SIZE.x, MAX_BATTLEFIELD_SIZE.x),
		clampf(adjusted_size.y, MIN_BATTLEFIELD_SIZE.y, MAX_BATTLEFIELD_SIZE.y)
	)

## Generate cover elements based on terrain and mission parameters
func _generate_cover_elements(terrain: Dictionary, mission_type: int, difficulty: int) -> Array[Dictionary]:
	var cover_elements: Array[Dictionary] = []
	var cover_count := _calculate_cover_count(terrain, difficulty)
	
	for i in range(cover_count):
		var cover_result: Dictionary = table_processor.roll_table("cover_elements", mission_type)
		if cover_result["success"]:
			var cover: Dictionary = cover_result["result"]
			var position: Vector2 = position_validator.get_valid_cover_point(cover_elements)
			if position != Vector2.ZERO:
				cover["position"] = position
				cover_elements.append(cover)
	
	return cover_elements

## Calculate number of cover elements to generate
func _calculate_cover_count(terrain: Dictionary, difficulty: int) -> int:
	var base_count := 10
	var terrain_modifier: float = terrain.get("cover_density", 1.0)
	var difficulty_modifier := 1.0 + (difficulty * 0.1)
	
	return roundi(base_count * terrain_modifier * difficulty_modifier)

## Generate hazard features based on terrain and mission parameters
func _generate_hazard_features(terrain: Dictionary, mission_type: int, difficulty: int) -> Array[Dictionary]:
	var hazards: Array[Dictionary] = []
	var hazard_count := _calculate_hazard_count(terrain, difficulty)
	
	for i in range(hazard_count):
		var hazard_result: Dictionary = table_processor.roll_table("hazard_features", mission_type)
		if hazard_result["success"]:
			var hazard: Dictionary = hazard_result["result"]
			var position: Vector2 = position_validator.get_valid_hazard_point(hazards)
			if position != Vector2.ZERO:
				hazard["position"] = position
				hazards.append(hazard)
	
	return hazards

## Calculate number of hazard features to generate
func _calculate_hazard_count(terrain: Dictionary, difficulty: int) -> int:
	var base_count := 3
	var terrain_modifier: float = terrain.get("hazard_density", 1.0)
	var difficulty_modifier := 1.0 + (difficulty * 0.2)
	
	return roundi(base_count * terrain_modifier * difficulty_modifier)

## Generate strategic points based on terrain and mission parameters
func _generate_strategic_points(terrain: Dictionary, mission_type: int, difficulty: int) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var point_count := _calculate_strategic_point_count(terrain, difficulty)
	
	for i in range(point_count):
		var point_result: Dictionary = table_processor.roll_table("strategic_points", mission_type)
		if point_result["success"]:
			var point: Dictionary = point_result["result"]
			var position: Vector2 = position_validator.get_valid_strategic_point(points)
			if position != Vector2.ZERO:
				point["position"] = position
				points.append(point)
	
	return points

## Calculate number of strategic points to generate
func _calculate_strategic_point_count(terrain: Dictionary, difficulty: int) -> int:
	var base_count := 5
	var terrain_modifier: float = terrain.get("strategic_density", 1.0)
	var difficulty_modifier := 1.0 + (difficulty * 0.1)
	
	return roundi(base_count * terrain_modifier * difficulty_modifier)

## Validate the generated battlefield
func _validate_battlefield(battlefield_data: Dictionary) -> bool:
	# Check for minimum required elements
	if battlefield_data.get("cover", []).is_empty():
		return false
	
	if battlefield_data.get("strategic_points", []).is_empty():
		return false
	
	# Validate terrain data
	if not battlefield_data.has("terrain") or battlefield_data.terrain.is_empty():
		return false
	
	# Validate battlefield size
	var size = battlefield_data.get("size", Vector2.ZERO)
	if size.x < MIN_BATTLEFIELD_SIZE.x or size.y < MIN_BATTLEFIELD_SIZE.y:
		return false
	
	return true