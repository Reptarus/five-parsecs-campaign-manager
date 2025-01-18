extends "res://tests/test_base.gd"

const BattlefieldGenerator = preload("res://src/core/systems/BattlefieldGenerator.gd")
const PositionValidator = preload("res://src/core/systems/PositionValidator.gd")
const Mission = preload("res://src/core/systems/Mission.gd")

var generator
var validator
var test_mission

func before_each() -> void:
	super.before_each()
	generator = BattlefieldGenerator.new()
	validator = PositionValidator.new()
	test_mission = Mission.new()
	track_test_resource(generator)
	track_test_resource(validator)
	track_test_resource(test_mission)

func after_each() -> void:
	super.after_each()
	generator = null
	validator = null
	test_mission = null

# Helper function to convert Mission to Dictionary
func _mission_to_dict(mission: Mission) -> Dictionary:
	return {
		"type": mission.mission_type,
		"difficulty": mission.difficulty,
		"environment": mission.environment,
		"size": mission.size,
		"features": mission.features
	}