@tool
extends "res://tests/fixtures/game_test.gd"

const Mission := preload("res://src/core/systems/Mission.gd")

# Test variables
var mission: Mission # Using correct type since it's a Resource

# Lifecycle Methods
func before_each() -> void:
	await super.before_each()
	mission = Mission.new()
	track_test_resource(mission)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	mission = null

# Test Methods
func test_initial_state() -> void:
	assert_eq(mission.mission_type, GameEnums.MissionType.NONE, "Should start with no mission type")
	assert_eq(mission.objectives.size(), 0, "Should start with no objectives")
	assert_false(mission.is_completed, "Should not be completed")
	assert_false(mission.is_failed, "Should not be failed")

func test_mission_completion() -> void:
	watch_signals(mission)
	
	mission.is_completed = true
	assert_true(mission.is_completed, "Should be marked as completed")
	assert_signal_emitted(mission, "mission_completed")

func test_mission_failure() -> void:
	watch_signals(mission)
	
	mission.is_failed = true
	assert_true(mission.is_failed, "Should be marked as failed")
	assert_signal_emitted(mission, "mission_failed")

func test_phase_change() -> void:
	watch_signals(mission)
	
	mission.current_phase = "combat"
	assert_eq(mission.current_phase, "combat", "Should update phase")
	assert_signal_emitted(mission, "phase_changed")

func test_progress_update() -> void:
	watch_signals(mission)
	
	mission.completion_percentage = 50.0
	assert_eq(mission.completion_percentage, 50.0, "Should update progress")
	assert_signal_emitted(mission, "progress_updated")