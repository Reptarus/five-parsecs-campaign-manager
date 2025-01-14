extends "res://addons/gut/test.gd"

const GameEnums = preload("res://src/core/systems/GlobalEnums.gd")
const BattlefieldGenerator = preload("res://src/core/battle/BattlefieldGenerator.gd")

var battlefield_generator: BattlefieldGenerator

func before_each() -> void:
	battlefield_generator = BattlefieldGenerator.new()
	add_child(battlefield_generator)

func after_each() -> void:
	battlefield_generator.queue_free()

func test_generate_mission() -> void:
	var mission = battlefield_generator.generate_mission()
	assert_not_null(mission, "Mission should be created")
	
	print("Mission Details:")
	print("Type: ", GameEnums.MissionType.keys()[mission.type])
	print("Difficulty: ", GameEnums.DifficultyLevel.keys()[mission.difficulty])
	print("Environment: ", GameEnums.PlanetEnvironment.keys()[mission.environment])
	print("Objective: ", GameEnums.MissionObjective.keys()[mission.objective])
	
	assert_true(mission.type in GameEnums.MissionType.values(), "Mission type should be valid")
	assert_true(mission.difficulty in GameEnums.DifficultyLevel.values(), "Difficulty should be valid")
	assert_true(mission.environment in GameEnums.PlanetEnvironment.values(), "Environment should be valid")
	assert_true(mission.objective in GameEnums.MissionObjective.values(), "Objective should be valid")
