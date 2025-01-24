@tool
extends "res://tests/fixtures/base_test.gd"

## Unit tests for MissionTemplate class
## Tests mission parameter handling, reward management, and mission calculations
## @class TestMissionTemplate
## @description Verifies core functionality of the mission template system

const MissionTemplate := preload("res://src/core/systems/MissionTemplate.gd")

var template: MissionTemplate

# Helper methods
func create_test_item() -> Dictionary:
	return {"name": "Test Item", "type": "weapon"}

func create_valid_params() -> Dictionary:
	return {
		"type": GameEnums.MissionType.PATROL,
		"difficulty": 2,
		"credits": 150,
		"items": [create_test_item()]
	}

func before_each() -> void:
	super.before_each()
	template = MissionTemplate.new()
	add_child(template)
	track_test_node(template)

func after_each() -> void:
	super.after_each()

# Basic State Tests
func test_initial_state() -> void:
	assert_eq(template.mission_type, GameEnums.MissionType.NONE)
	assert_eq(template.difficulty, 0)
	assert_eq(template.reward_credits, 0)
	assert_eq(template.reward_items.size(), 0)

# Mission Type and Parameters Tests
func test_set_mission_type() -> void:
	template.mission_type = GameEnums.MissionType.PATROL
	assert_eq(template.mission_type, GameEnums.MissionType.PATROL)

func test_set_difficulty() -> void:
	template.difficulty = 3
	assert_eq(template.difficulty, 3)

# Reward Management Tests
func test_set_reward_credits() -> void:
	template.reward_credits = 100
	assert_eq(template.reward_credits, 100)

func test_add_reward_item() -> void:
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	assert_eq(template.reward_items.size(), 1)
	assert_eq(template.reward_items[0], item)

func test_remove_reward_item() -> void:
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	template.remove_reward_item(0)
	assert_eq(template.reward_items.size(), 0)

func test_clear_reward_items() -> void:
	var item1 = {"name": "Item 1", "type": "weapon"}
	var item2 = {"name": "Item 2", "type": "armor"}
	template.add_reward_item(item1)
	template.add_reward_item(item2)
	template.clear_reward_items()
	assert_eq(template.reward_items.size(), 0)

# Parameter Management Tests
func test_set_mission_parameters() -> void:
	var params = {
		"type": GameEnums.MissionType.PATROL,
		"difficulty": 2,
		"credits": 150,
		"items": [ {"name": "Test Item", "type": "weapon"}]
	}
	template.set_mission_parameters(params)
	assert_eq(template.mission_type, GameEnums.MissionType.PATROL)
	assert_eq(template.difficulty, 2)
	assert_eq(template.reward_credits, 150)
	assert_eq(template.reward_items.size(), 1)

func test_get_mission_parameters() -> void:
	template.mission_type = GameEnums.MissionType.PATROL
	template.difficulty = 2
	template.reward_credits = 150
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	
	var params = template.get_mission_parameters()
	assert_eq(params.type, GameEnums.MissionType.PATROL)
	assert_eq(params.difficulty, 2)
	assert_eq(params.credits, 150)
	assert_eq(params.items.size(), 1)

# Calculation Tests
func test_calculate_mission_time() -> void:
	template.difficulty = 2
	var base_time = 10
	var expected_time = base_time * (1 + template.difficulty * 0.5)
	assert_eq(template.calculate_mission_time(base_time), expected_time)

func test_calculate_success_chance() -> void:
	template.difficulty = 2
	var base_chance = 0.8
	var expected_chance = base_chance * (1 - template.difficulty * 0.1)
	assert_eq(template.calculate_success_chance(base_chance), expected_chance)

# Validation Tests
func test_validate_mission_parameters() -> void:
	var valid_params = {
		"type": GameEnums.MissionType.PATROL,
		"difficulty": 2,
		"credits": 150,
		"items": [ {"name": "Test Item", "type": "weapon"}]
	}
	assert_true(template.validate_mission_parameters(valid_params))
	
	var invalid_params = {
		"type": GameEnums.MissionType.NONE,
		"difficulty": - 1,
		"credits": - 100,
		"items": null
	}
	assert_false(template.validate_mission_parameters(invalid_params))

# New Boundary Tests
func test_invalid_difficulty_bounds() -> void:
	template.difficulty = -1
	assert_eq(template.difficulty, 0)
	template.difficulty = 11
	assert_eq(template.difficulty, 10)

# New Performance Tests
func test_bulk_reward_operations() -> void:
	var start_time := Time.get_ticks_msec()
	for i in range(1000):
		template.add_reward_item(create_test_item())
	template.clear_reward_items()
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	assert_lt(duration, 1000, "Should handle bulk operations efficiently")

# New Signal Tests
func test_mission_parameters_changed_signal() -> void:
	watch_signals(template)
	template.set_mission_parameters(create_valid_params())
	assert_signal_emitted(template, "mission_parameters_changed")

# New State Persistence Tests
func test_save_load_state() -> void:
	template.set_mission_parameters(create_valid_params())
	var saved_state = template.save_state()
	var new_template = MissionTemplate.new()
	new_template.load_state(saved_state)
	assert_eq(new_template.mission_type, template.mission_type)
	new_template.free()

func test_clone_mission() -> void:
	template.mission_type = GameEnums.MissionType.PATROL
	template.difficulty = 2
	template.reward_credits = 150
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	
	var clone = template.clone()
	assert_eq(clone.mission_type, template.mission_type)
	assert_eq(clone.difficulty, template.difficulty)
	assert_eq(clone.reward_credits, template.reward_credits)
	assert_eq(clone.reward_items.size(), template.reward_items.size())
	assert_eq(clone.reward_items[0], template.reward_items[0])
	clone.free()

func test_to_string() -> void:
	template.mission_type = GameEnums.MissionType.PATROL
	template.difficulty = 2
	template.reward_credits = 150
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	
	var str_rep = template.to_string()
	assert_true(str_rep.contains("PATROL"))
	assert_true(str_rep.contains("2"))
	assert_true(str_rep.contains("150"))
	assert_true(str_rep.contains("Test Item"))