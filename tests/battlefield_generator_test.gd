extends "res://tests/test_base.gd"

const BattlefieldGenerator = preload("res://src/core/battle/BattlefieldGenerator.gd")

var battlefield_generator: BattlefieldGenerator

func before_each() -> void:
	super.before_each()
	battlefield_generator = BattlefieldGenerator.new()
	add_child(battlefield_generator)

func after_each() -> void:
	super.after_each()
	battlefield_generator.queue_free()

func test_generate_mission() -> void:
	var mission = battlefield_generator.generate_mission()
	track_test_resource(mission)
	
	assert_not_null(mission, "Mission should be created")
	assert_true(mission.type in GameEnums.MissionType.values(), "Mission type should be valid")
	assert_true(mission.difficulty in GameEnums.DifficultyLevel.values(), "Difficulty should be valid")
	assert_true(mission.environment in GameEnums.PlanetEnvironment.values(), "Environment should be valid")
	assert_true(mission.objective in GameEnums.MissionObjective.values(), "Objective should be valid")
