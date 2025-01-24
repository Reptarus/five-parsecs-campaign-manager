@tool
extends "res://tests/fixtures/game_test.gd"

const Mission := preload("res://src/core/systems/Mission.gd")
const TerrainSystem := preload("res://src/core/terrain/TerrainSystem.gd")
const RivalSystem := preload("res://src/core/rivals/RivalSystem.gd")
const PositionValidator := preload("res://src/core/systems/PositionValidator.gd")
const EventManager := preload("res://src/core/managers/EventManager.gd")
const MissionGenerator := preload("res://src/core/systems/MissionGenerator.gd")
const ResourceSystem := preload("res://src/core/systems/ResourceSystem.gd")

var mission

func before_each() -> void:
	await super.before_each()
	var game_state = create_test_game_state()
	add_child(game_state)
	track_test_node(game_state)
	
	mission = Mission.new()
	add_child(mission)
	track_test_node(mission)
	await get_tree().process_frame
	
	# Setup default mission state
	mission.mission_name = "Test Mission"
	mission.mission_type = GameEnums.MissionType.PATROL
	mission.difficulty = GameEnums.DifficultyLevel.NORMAL

func after_each() -> void:
	await super.after_each()
	mission = null

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
