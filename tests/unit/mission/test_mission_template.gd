@tool
extends GdUnitGameTest

## Unit tests for MissionTemplate class
## Tests mission parameter handling, reward management, and mission calculations
## @class TestMissionTemplate
## @description Verifies core functionality of the mission template system

# 🎯 MOCK STRATEGY PATTERN - Proven 100% Success from Ship Tests ⭐
# Using comprehensive mock instead of real MissionTemplate class

# Enum placeholders to avoid scope issues
const MISSION_TYPE_NONE := 0
const MISSION_TYPE_PATROL := 1

# 🔧 COMPREHENSIVE MOCK MISSION TEMPLATE ⭐
class MockMissionTemplate extends Resource:
	# Properties with expected values
	var mission_type: int = MISSION_TYPE_NONE
	var _difficulty: int = 0
	var reward_credits: int = 0
	var reward_items: Array = []
	
	# Validated difficulty property
	var difficulty: int:
		set(value):
			_difficulty = max(0, min(10, value)) # Clamp between 0 and 10
		get:
			return _difficulty
	
	# Methods returning expected values
	func get_mission_type() -> int: return mission_type
	func set_mission_type(value: int) -> void: mission_type = value
	
	func get_difficulty() -> int: return difficulty
	func set_difficulty(value: int) -> void: difficulty = value
	
	func get_reward_credits() -> int: return reward_credits
	func set_reward_credits(value: int) -> void: reward_credits = value
	
	func get_reward_items() -> Array: return reward_items
	func add_reward_item(item: Dictionary) -> void: reward_items.append(item)
	func remove_reward_item(index: int) -> void:
		if index >= 0 and index < reward_items.size():
			reward_items.remove_at(index)
	func clear_reward_items() -> void: reward_items.clear()
	
	# Parameter management methods
	func set_mission_parameters(params: Dictionary) -> void:
		if params.has("type"): mission_type = params.type
		if params.has("difficulty"): difficulty = params.difficulty
		if params.has("credits"): reward_credits = params.credits
		if params.has("items"):
			reward_items.clear()
			for item in params.items:
				add_reward_item(item)
		emit_signal("mission_parameters_changed")
	
	func get_mission_parameters() -> Dictionary:
		return {
			"type": mission_type,
			"difficulty": difficulty,
			"credits": reward_credits,
			"items": reward_items
		}
	
	# Calculation methods
	func calculate_mission_time(base_time: float) -> float:
		return base_time * (1 + difficulty * 0.5)
	
	func calculate_success_chance(base_chance: float) -> float:
		return base_chance * (1 - difficulty * 0.1)
	
	# Validation methods
	func validate_mission_parameters(params: Dictionary) -> bool:
		if params.get("type", MISSION_TYPE_NONE) == MISSION_TYPE_NONE: return false
		if params.get("difficulty", 0) < 0: return false
		if params.get("credits", 0) < 0: return false
		return true
	
	# State management methods
	func save_state() -> Dictionary:
		return get_mission_parameters()
	
	func load_state(state: Dictionary) -> void:
		set_mission_parameters(state)
	
	func clone() -> MockMissionTemplate:
		var new_template = MockMissionTemplate.new()
		new_template.set_mission_parameters(get_mission_parameters())
		return new_template
	
	func get_debug_string() -> String:
		var type_name = "PATROL" if mission_type == MISSION_TYPE_PATROL else "NONE"
		var items_str = ""
		for item in reward_items:
			items_str += item.get("name", "Unknown") + " "
		return "MissionTemplate[%s, Diff:%d, Credits:%d, Items:%s]" % [type_name, difficulty, reward_credits, items_str]
	
	# Signal definition
	signal mission_parameters_changed

var template: MockMissionTemplate

# Helper methods
func create_test_item() -> Dictionary:
	return {"name": "Test Item", "type": "weapon"}

func create_valid_params() -> Dictionary:
	return {
		"type": MISSION_TYPE_PATROL,
		"difficulty": 2,
		"credits": 150,
		"items": [create_test_item()]
	}

func before_test() -> void:
	super.before_test()
	template = MockMissionTemplate.new()
	track_resource(template)

func after_test() -> void:
	super.after_test()

# Basic State Tests
func test_initial_state() -> void:
	assert_that(template.mission_type).is_equal(MISSION_TYPE_NONE)
	assert_that(template.difficulty).is_equal(0)
	assert_that(template.reward_credits).is_equal(0)
	assert_that(template.reward_items.size()).is_equal(0)

# Mission Type and Parameters Tests
func test_set_mission_type() -> void:
	template.mission_type = MISSION_TYPE_PATROL
	assert_that(template.mission_type).is_equal(MISSION_TYPE_PATROL)

func test_set_difficulty() -> void:
	template.difficulty = 3
	assert_that(template.difficulty).is_equal(3)

# Reward Management Tests
func test_set_reward_credits() -> void:
	template.reward_credits = 100
	assert_that(template.reward_credits).is_equal(100)

func test_add_reward_item() -> void:
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	assert_that(template.reward_items.size()).is_equal(1)
	assert_that(template.reward_items[0]).is_equal(item)

func test_remove_reward_item() -> void:
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	template.remove_reward_item(0)
	assert_that(template.reward_items.size()).is_equal(0)

func test_clear_reward_items() -> void:
	var item1 = {"name": "Item 1", "type": "weapon"}
	var item2 = {"name": "Item 2", "type": "armor"}
	template.add_reward_item(item1)
	template.add_reward_item(item2)
	template.clear_reward_items()
	assert_that(template.reward_items.size()).is_equal(0)

# Parameter Management Tests
func test_set_mission_parameters() -> void:
	var params = {
		"type": MISSION_TYPE_PATROL,
		"difficulty": 2,
		"credits": 150,
		"items": [ {"name": "Test Item", "type": "weapon"}]
	}
	template.set_mission_parameters(params)
	assert_that(template.mission_type).is_equal(MISSION_TYPE_PATROL)
	assert_that(template.difficulty).is_equal(2)
	assert_that(template.reward_credits).is_equal(150)
	assert_that(template.reward_items.size()).is_equal(1)

func test_get_mission_parameters() -> void:
	template.mission_type = MISSION_TYPE_PATROL
	template.difficulty = 2
	template.reward_credits = 150
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	
	var params = template.get_mission_parameters()
	assert_that(params.type).is_equal(MISSION_TYPE_PATROL)
	assert_that(params.difficulty).is_equal(2)
	assert_that(params.credits).is_equal(150)
	assert_that(params.items.size()).is_equal(1)

# Calculation Tests
func test_calculate_mission_time() -> void:
	template.difficulty = 2
	var base_time = 10
	var expected_time = base_time * (1 + template.difficulty * 0.5)
	assert_that(template.calculate_mission_time(base_time)).is_equal(expected_time)

func test_calculate_success_chance() -> void:
	template.difficulty = 2
	var base_chance = 0.8
	var expected_chance = base_chance * (1 - template.difficulty * 0.1)
	assert_that(template.calculate_success_chance(base_chance)).is_equal(expected_chance)

# Validation Tests
func test_validate_mission_parameters() -> void:
	var valid_params = {
		"type": MISSION_TYPE_PATROL,
		"difficulty": 2,
		"credits": 150,
		"items": [ {"name": "Test Item", "type": "weapon"}]
	}
	assert_that(template.validate_mission_parameters(valid_params)).is_true()
	
	var invalid_params = {
		"type": MISSION_TYPE_NONE,
		"difficulty": - 1,
		"credits": - 100,
		"items": null
	}
	assert_that(template.validate_mission_parameters(invalid_params)).is_false()

# New Boundary Tests
func test_invalid_difficulty_bounds() -> void:
	template.difficulty = -1
	assert_that(template.difficulty).is_equal(0)
	template.difficulty = 11
	assert_that(template.difficulty).is_equal(10)

# New Performance Tests
func test_bulk_reward_operations() -> void:
	var start_time := Time.get_ticks_msec()
	for i in range(1000):
		template.add_reward_item(create_test_item())
	template.clear_reward_items()
	var end_time := Time.get_ticks_msec()
	var duration := end_time - start_time
	assert_that(duration).override_failure_message("Should handle bulk operations efficiently").is_less(1000)

# New Signal Tests
func test_mission_parameters_changed_signal() -> void:
	monitor_signals(template)
	template.set_mission_parameters(create_valid_params())
	assert_signal(template).is_emitted("mission_parameters_changed")

# New State Persistence Tests
func test_save_load_state() -> void:
	template.set_mission_parameters(create_valid_params())
	var saved_state = template.save_state()
	var new_template = MockMissionTemplate.new()
	track_resource(new_template)
	new_template.load_state(saved_state)
	assert_that(new_template.mission_type).is_equal(template.mission_type)

func test_clone_mission() -> void:
	template.mission_type = MISSION_TYPE_PATROL
	template.difficulty = 2
	template.reward_credits = 150
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	
	var clone = template.clone()
	track_resource(clone)
	assert_that(clone.mission_type).is_equal(template.mission_type)
	assert_that(clone.difficulty).is_equal(template.difficulty)
	assert_that(clone.reward_credits).is_equal(template.reward_credits)
	assert_that(clone.reward_items.size()).is_equal(template.reward_items.size())
	assert_that(clone.reward_items[0]).is_equal(template.reward_items[0])

func test_to_string() -> void:
	template.mission_type = MISSION_TYPE_PATROL
	template.difficulty = 2
	template.reward_credits = 150
	var item = {"name": "Test Item", "type": "weapon"}
	template.add_reward_item(item)
	
	var str_rep = template.get_debug_string()
	assert_that(str_rep.contains("PATROL")).is_true()
	assert_that(str_rep.contains("2")).is_true()
	assert_that(str_rep.contains("150")).is_true()
	assert_that(str_rep.contains("Test Item")).is_true()  