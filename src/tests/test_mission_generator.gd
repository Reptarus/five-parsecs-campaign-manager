extends "res://addons/gut/test.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const MissionGenerator = preload("res://src/core/systems/MissionGenerator.gd")
const TerrainSystem = preload("res://src/core/terrain/TerrainSystem.gd")
const RivalSystem = preload("res://src/core/rivals/RivalSystem.gd")

var _mission_generator: MissionGenerator
var _terrain_system: TerrainSystem
var _rival_system: RivalSystem

func before_each():
	_terrain_system = TerrainSystem.new()
	_rival_system = RivalSystem.new()
	_mission_generator = MissionGenerator.new()
	_mission_generator.terrain_system = _terrain_system
	_mission_generator.rival_system = _rival_system
	add_child(_mission_generator)

func after_each():
	_mission_generator.queue_free()
	_terrain_system.queue_free()
	_rival_system.queue_free()

func test_mission_generation():
	var template = MissionTemplate.new()
	template.type = GameEnums.MissionType.PATROL
	template.difficulty_range = Vector2(1, 3)
	template.reward_range = Vector2(100, 300)
	template.title_templates = ["Test Mission"]
	
	var mission = _mission_generator.generate_mission(template)
	assert_not_null(mission, "Mission should be generated")
	assert_eq(mission.mission_type, GameEnums.MissionType.PATROL, "Mission type should match template")
	assert_true(mission.difficulty >= 1 and mission.difficulty <= 3, "Difficulty should be within range")
	assert_true(mission.rewards.credits >= 100 and mission.rewards.credits <= 300, "Reward should be within range")

func test_invalid_template():
	var template = MissionTemplate.new()
	# Don't set required fields
	var mission = _mission_generator.generate_mission(template)
	assert_null(mission, "Should return null for invalid template")

func test_rival_involvement():
	var template = MissionTemplate.new()
	template.type = GameEnums.MissionType.RAID
	template.difficulty_range = Vector2(2, 4)
	template.reward_range = Vector2(200, 400)
	template.title_templates = ["Rival Test Mission"]
	
	# Set up rival data
	_rival_system.add_rival({
		"id": "test_rival",
		"force_composition": ["grunt", "grunt", "elite"]
	})
	
	var mission = _mission_generator.generate_mission(template)
	assert_not_null(mission.rival_involvement, "Mission should have rival involvement")
	assert_true(mission.rival_involvement.rival_id == "test_rival", "Rival ID should match")

func test_terrain_generation():
	var template = MissionTemplate.new()
	template.type = GameEnums.MissionType.DEFENSE
	template.difficulty_range = Vector2(2, 4)
	template.reward_range = Vector2(200, 400)
	template.title_templates = ["Terrain Test Mission"]
	
	var mission = _mission_generator.generate_mission(template)
	assert_not_null(mission, "Mission should be generated")
	
	# Check if terrain features were generated
	var terrain_features = _count_terrain_features()
	assert_gt(terrain_features.total, 0, "Should have terrain features")

func test_objective_placement():
	var template = MissionTemplate.new()
	template.type = GameEnums.MissionType.SABOTAGE
	template.difficulty_range = Vector2(3, 5)
	template.reward_range = Vector2(300, 500)
	template.title_templates = ["Objective Test Mission"]
	
	var mission = _mission_generator.generate_mission(template)
	assert_not_null(mission, "Mission should be generated")
	assert_gt(mission.objectives.size(), 0, "Mission should have objectives")
	
	for objective in mission.objectives:
		assert_true(_is_valid_position(objective.position), "Objective should be at valid position")

func _count_terrain_features() -> Dictionary:
	var features = {
		"total": 0,
		"cover": 0,
		"obstacles": 0
	}
	
	var grid_size = _terrain_system.get_grid_size()
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var feature_type = _terrain_system.get_terrain_type(Vector2(x, y))
			if feature_type != GameEnums.TerrainFeatureType.NONE:
				features.total += 1
				if feature_type in [GameEnums.TerrainFeatureType.COVER_LOW, GameEnums.TerrainFeatureType.COVER_HIGH]:
					features.cover += 1
				else:
					features.obstacles += 1
	
	return features

func _is_valid_position(pos: Vector2) -> bool:
	var grid_size = _terrain_system.get_grid_size()
	return pos.x >= 0 and pos.x < grid_size.x and pos.y >= 0 and pos.y < grid_size.y