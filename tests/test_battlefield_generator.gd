extends "res://addons/gut/test.gd"

const BattlefieldGenerator = preload("res://src/core/systems/BattlefieldGenerator.gd")
const PositionValidator = preload("res://src/core/systems/PositionValidator.gd")
const Mission = preload("res://src/core/systems/Mission.gd")
const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")

var generator: Node
var validator: Node
var test_mission: Mission

# Helper function to convert Mission to Dictionary
func _mission_to_dict(mission: Mission) -> Dictionary:
	return {
		"type": mission.mission_type,
		"difficulty": mission.difficulty,
		"environment": mission.environment,
		"size": mission.size,
		"features": mission.features
	}

func before_each() -> void:
	generator = BattlefieldGenerator.new()
	validator = PositionValidator.new()
	test_mission = Mission.new()
	
	# Setup test mission
	test_mission.mission_type = GameEnums.MissionType.RED_ZONE
	test_mission.difficulty = GameEnums.DifficultyLevel.NORMAL
	test_mission.environment = GameEnums.PlanetEnvironment.URBAN
	test_mission.size = Vector2i(20, 20)
	test_mission.features = []
	
	generator.setup(validator)

func after_each() -> void:
	generator.free()
	validator.free()

func test_battlefield_generation() -> void:
	var battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	
	# Test basic structure
	assert_has(battlefield, "terrain", "Battlefield should have terrain data")
	assert_has(battlefield, "size", "Battlefield should have size data")
	assert_has(battlefield, "cover", "Battlefield should have cover data")
	assert_has(battlefield, "hazards", "Battlefield should have hazard data")
	assert_has(battlefield, "strategic_points", "Battlefield should have strategic points")
	
	# Test size constraints
	var size = battlefield["size"] as Vector2
	assert_true(size.x >= BattlefieldGenerator.MIN_BATTLEFIELD_SIZE.x, "Battlefield width should meet minimum size")
	assert_true(size.y >= BattlefieldGenerator.MIN_BATTLEFIELD_SIZE.y, "Battlefield height should meet minimum size")
	assert_true(size.x <= BattlefieldGenerator.MAX_BATTLEFIELD_SIZE.x, "Battlefield width should not exceed maximum size")
	assert_true(size.y <= BattlefieldGenerator.MAX_BATTLEFIELD_SIZE.y, "Battlefield height should not exceed maximum size")

func test_terrain_generation() -> void:
	var battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	var terrain = battlefield["terrain"]
	
	# Test terrain properties
	assert_has(terrain, "type", "Terrain should have a type")
	assert_has(terrain, "name", "Terrain should have a name")
	assert_has(terrain, "movement_modifier", "Terrain should have a movement modifier")
	assert_has(terrain, "cover_density", "Terrain should have cover density")
	assert_has(terrain, "features", "Terrain should have features")
	
	# Test terrain values
	assert_true(terrain["movement_modifier"] > 0.0, "Movement modifier should be positive")
	assert_true(terrain["cover_density"] >= 0.0, "Cover density should be non-negative")
	assert_true(terrain["features"].size() > 0, "Terrain should have at least one feature")

func test_cover_generation() -> void:
	var battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	var cover_elements = battlefield["cover"]
	
	# Test cover array
	assert_true(cover_elements.size() > 0, "Should generate at least one cover element")
	
	# Test first cover element
	var cover = cover_elements[0]
	assert_has(cover, "type", "Cover should have a type")
	assert_has(cover, "name", "Cover should have a name")
	assert_has(cover, "protection_value", "Cover should have a protection value")
	assert_has(cover, "position", "Cover should have a position")
	
	# Test cover values
	assert_true(cover["protection_value"] > 0, "Protection value should be positive")
	assert_true(cover["position"] is Vector2, "Position should be Vector2")

func test_hazard_generation() -> void:
	var battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	var hazards = battlefield["hazards"]
	
	# Test hazards array
	if hazards.size() > 0:
		var hazard = hazards[0]
		assert_has(hazard, "type", "Hazard should have a type")
		assert_has(hazard, "name", "Hazard should have a name")
		assert_has(hazard, "danger_level", "Hazard should have a danger level")
		assert_has(hazard, "effect_radius", "Hazard should have an effect radius")
		assert_has(hazard, "position", "Hazard should have a position")
		
		# Test hazard values
		assert_true(hazard["danger_level"] > 0, "Danger level should be positive")
		assert_true(hazard["effect_radius"] > 0, "Effect radius should be positive")
		assert_true(hazard["position"] is Vector2, "Position should be Vector2")

func test_strategic_points_generation() -> void:
	var battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	var points = battlefield["strategic_points"]
	
	# Test strategic points array
	assert_true(points.size() > 0, "Should generate at least one strategic point")
	
	# Test first strategic point
	var point = points[0]
	assert_has(point, "type", "Strategic point should have a type")
	assert_has(point, "name", "Strategic point should have a name")
	assert_has(point, "strategic_value", "Strategic point should have a strategic value")
	assert_has(point, "position", "Strategic point should have a position")
	
	# Test point values
	assert_true(point["strategic_value"] > 0, "Strategic value should be positive")
	assert_true(point["position"] is Vector2, "Position should be Vector2")

func test_mission_type_influence() -> void:
	# Test RED_ZONE mission
	test_mission.mission_type = GameEnums.MissionType.RED_ZONE
	var red_zone_battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	
	# Test BLACK_ZONE mission
	test_mission.mission_type = GameEnums.MissionType.BLACK_ZONE
	var black_zone_battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	
	# Compare sizes (RED_ZONE should be larger than BLACK_ZONE)
	var red_size = red_zone_battlefield["size"] as Vector2
	var black_size = black_zone_battlefield["size"] as Vector2
	assert_true(red_size.x > black_size.x, "RED_ZONE battlefield should be wider than BLACK_ZONE")
	assert_true(red_size.y > black_size.y, "RED_ZONE battlefield should be taller than BLACK_ZONE")

func test_difficulty_influence() -> void:
	# Test EASY mission
	test_mission.difficulty = GameEnums.DifficultyLevel.EASY
	var easy_battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	
	# Test HARD mission
	test_mission.difficulty = GameEnums.DifficultyLevel.HARD
	var hard_battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	
	# Compare hazard counts (HARD should have more hazards)
	var easy_hazards = easy_battlefield["hazards"].size()
	var hard_hazards = hard_battlefield["hazards"].size()
	assert_true(hard_hazards > easy_hazards, "HARD difficulty should have more hazards")

func test_validation() -> void:
	# Test with invalid mission
	test_mission.mission_type = GameEnums.MissionType.NONE
	var invalid_battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	assert_true(invalid_battlefield.is_empty(), "Should return empty dictionary for invalid mission")
	
	# Test with valid mission but force validation failure
	test_mission.mission_type = GameEnums.MissionType.RED_ZONE
	validator.force_invalid_points = true # Assuming we add this feature to PositionValidator
	var failed_battlefield = generator.generate_battlefield(_mission_to_dict(test_mission))
	assert_true(failed_battlefield.is_empty(), "Should return empty dictionary when validation fails")