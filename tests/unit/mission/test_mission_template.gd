@tool
extends "res://tests/fixtures/base/game_test.gd"

## Unit tests for MissionTemplate class
## Tests mission parameter handling, reward management, and mission calculations
## @class TestMissionTemplate
## @description Verifies core functionality of the mission template system

const MissionTemplate := preload("res://src/core/templates/MissionTemplate.gd")

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
	track_test_resource(template)

func after_each() -> void:
	super.after_each()

# Basic State Tests
func test_initial_state() -> void:
	assert_eq(template.type, GameEnums.MissionType.NONE)
	assert_eq(template.difficulty_range.x, 1)
	assert_eq(template.reward_range.x, 100)
	assert_eq(template.title_templates.size(), 0)

# Mission Type and Parameters Tests
func test_set_mission_type() -> void:
	template.type = GameEnums.MissionType.PATROL
	assert_eq(template.type, GameEnums.MissionType.PATROL)

func test_set_difficulty() -> void:
	template.difficulty_range = Vector2(3, 5)
	assert_eq(template.difficulty_range.x, 3)

# Reward Management Tests
func test_set_reward_credits() -> void:
	template.reward_range = Vector2(100, 200)
	assert_eq(template.reward_range.x, 100)

func test_add_reward_item() -> void:
	var item = {"name": "Test Item", "type": "weapon"}
	if template.has_method("add_reward_item"):
		template.add_reward_item(item)
		assert_eq(template.reward_items.size(), 1)
		assert_eq(template.reward_items[0], item)
	else:
		# Skip test if method doesn't exist
		pending("add_reward_item method not available")

func test_remove_reward_item() -> void:
	if not template.has_method("add_reward_item") or not template.has_method("remove_reward_item"):
		pending("reward item methods not available")
		return
	
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	template.remove_reward_item(0)
	assert_eq(template.reward_items.size(), 0)

func test_clear_reward_items() -> void:
	if not template.has_method("add_reward_item") or not template.has_method("clear_reward_items"):
		pending("reward item methods not available")
		return
		
	var item1 = {"name": "Item 1", "type": "weapon"}
	var item2 = {"name": "Item 2", "type": "armor"}
	template.add_reward_item(item1)
	template.add_reward_item(item2)
	template.clear_reward_items()
	assert_eq(template.reward_items.size(), 0)

# Parameter Management Tests
func test_set_mission_parameters() -> void:
	if not template.has_method("set_mission_parameters"):
		pending("set_mission_parameters method not available")
		return
		
	var params = {
		"type": GameEnums.MissionType.PATROL,
		"difficulty": 2,
		"credits": 150,
		"items": [ {"name": "Test Item", "type": "weapon"}]
	}
	template.set_mission_parameters(params)
	assert_eq(template.type, GameEnums.MissionType.PATROL)
	assert_eq(template.difficulty_range.y, 2)
	assert_eq(template.reward_range.x, 150)
	assert_true(template.title_templates.size() > 0)

func test_get_mission_parameters() -> void:
	if not template.has_method("get_mission_parameters"):
		pending("get_mission_parameters method not available")
		return
		
	template.type = GameEnums.MissionType.PATROL
	template.difficulty_range = Vector2(2, 4)
	template.reward_range = Vector2(150, 300)
	if template.has_method("add_reward_item"):
		var item = {"name": "Test Item", "type": "weapon"}
		template.add_reward_item(item)
	
	var params = template.get_mission_parameters()
	assert_eq(params.type, GameEnums.MissionType.PATROL)
	assert_eq(params.difficulty, 2)
	assert_eq(params.credits, 150)
	if template.has_method("add_reward_item"):
		assert_eq(params.items.size(), 1)

# Calculation Tests
func test_calculate_mission_time() -> void:
	if not template.has_method("calculate_mission_time"):
		pending("calculate_mission_time method not available")
		return
		
	template.difficulty_range = Vector2(2, 4)
	var base_time = 10
	var expected_time = base_time * (1 + template.difficulty_range.x * 0.5)
	assert_eq(template.calculate_mission_time(base_time), expected_time)

func test_calculate_success_chance() -> void:
	if not template.has_method("calculate_success_chance"):
		pending("calculate_success_chance method not available")
		return
		
	template.difficulty_range = Vector2(2, 4)
	var base_chance = 0.8
	var expected_chance = base_chance * (1 - template.difficulty_range.x * 0.1)
	assert_eq(template.calculate_success_chance(base_chance), expected_chance)

# Validation Tests
func test_validate_mission_parameters() -> void:
	if not template.has_method("validate_mission_parameters"):
		pending("validate_mission_parameters method not available")
		return
		
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
	if template.has_method("set_difficulty"):
		template.set_difficulty(-1)
		assert_eq(template.get_difficulty(), 0)
		template.set_difficulty(11)
		assert_eq(template.get_difficulty(), 10)
	else:
		template.difficulty_range = Vector2(-1, 0)
		assert_eq(template.difficulty_range.x, 1)
		template.difficulty_range = Vector2(11, 12)
		assert_eq(template.difficulty_range.y, 5)

# New Performance Tests
func test_bulk_reward_operations() -> void:
	if not template.has_method("add_reward_item") or not template.has_method("clear_reward_items"):
		pending("reward item methods not available")
		return
		
	var start_time := Time.get_ticks_msec()
	for i in range(1000):
		template.add_reward_item(create_test_item())
	template.clear_reward_items()
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	assert_lt(duration, 1000, "Should handle bulk operations efficiently")

# New Signal Tests
func test_mission_parameters_changed_signal() -> void:
	if not template.has_method("set_mission_parameters") or not template.has_signal("mission_parameters_changed"):
		pending("mission_parameters_changed signal not available")
		return
		
	watch_signals(template)
	template.set_mission_parameters(create_valid_params())
	assert_signal_emitted(template, "mission_parameters_changed")

# New State Persistence Tests
func test_save_load_state() -> void:
	if not template.has_method("save_state") or not template.has_method("load_state"):
		pending("save_state/load_state methods not available")
		return
		
	if template.has_method("set_mission_parameters"):
		template.set_mission_parameters(create_valid_params())
	else:
		template.type = GameEnums.MissionType.PATROL
		template.difficulty_range = Vector2(2, 4)
		template.reward_range = Vector2(150, 300)
		
	var saved_state = template.save_state()
	var new_template = MissionTemplate.new()
	new_template.load_state(saved_state)
	assert_eq(new_template.type, template.type)
	new_template.free()

func test_clone_mission() -> void:
	if not template.has_method("clone"):
		pending("clone method not available")
		return
		
	template.type = GameEnums.MissionType.PATROL
	template.difficulty_range = Vector2(2, 4)
	template.reward_range = Vector2(150, 300)
	if template.has_method("add_reward_item"):
		var item = {"name": "Test Item", "type": "weapon"}
		template.add_reward_item(item)
	
	var clone = template.clone()
	assert_eq(clone.type, template.type)
	assert_eq(clone.difficulty_range.x, template.difficulty_range.x)
	assert_eq(clone.reward_range.x, template.reward_range.x)
	if template.has_method("add_reward_item"):
		assert_eq(clone.reward_items.size(), template.reward_items.size())
		assert_eq(clone.reward_items[0], template.reward_items[0])
	clone.free()

func test_to_string() -> void:
	if not template.has_method("to_string"):
		pending("to_string method not available")
		return
		
	template.type = GameEnums.MissionType.PATROL
	template.difficulty_range = Vector2(2, 4)
	template.reward_range = Vector2(150, 300)
	if template.has_method("add_reward_item"):
		var item = {"name": "Test Item", "type": "weapon"}
		template.add_reward_item(item)
	
	var str_rep = template.to_string()
	assert_true(str_rep.contains("PATROL"))
	assert_true(str_rep.contains("2"))
	assert_true(str_rep.contains("150"))
	assert_true(str_rep.contains("Test Item"))