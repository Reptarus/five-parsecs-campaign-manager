@tool
extends "../../tests/fixtures/base_test.gd"

# MissionTemplate should extend Node for this test to work
const MissionTemplate := preload("res://src/core/systems/MissionTemplate.gd")

var template: MissionTemplate

func before_each() -> void:
	super.before_each()
	template = MissionTemplate.new()
	add_child(template)
	track_test_node(template)

func after_each() -> void:
	super.after_each()

func test_initial_state() -> void:
	assert_eq(template.mission_type, GameEnums.MissionType.NONE)
	assert_eq(template.difficulty, 0)
	assert_eq(template.reward_credits, 0)
	assert_eq(template.reward_items.size(), 0)

func test_set_mission_type() -> void:
	template.mission_type = GameEnums.MissionType.PATROL
	assert_eq(template.mission_type, GameEnums.MissionType.PATROL)

func test_set_difficulty() -> void:
	template.difficulty = 3
	assert_eq(template.difficulty, 3)

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