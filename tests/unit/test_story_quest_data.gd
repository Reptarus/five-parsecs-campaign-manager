@tool
extends "res://addons/gut/test.gd"

const StoryQuestData: GDScript = preload("res://src/core/story/StoryQuestData.gd")
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const TypeSafeMixin: GDScript = preload("res://tests/fixtures/type_safe_test_mixin.gd")
const TestHelper: GDScript = preload("res://tests/fixtures/test_helper.gd")

var quest_data: StoryQuestData = null

func before_each() -> void:
	await super.before_each()
	quest_data = StoryQuestData.new()
	if not quest_data:
		push_error("Failed to create quest data")
		return
		
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_quest_id", ["test_quest"])
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_quest_title", ["Test Quest"])
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_quest_type", [GameEnums.QuestType.STORY])
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_quest_status", [GameEnums.QuestStatus.ACTIVE])
	
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	quest_data = null

func test_initialization() -> void:
	assert_not_null(quest_data, "Quest data should be initialized")
	
	var quest_id: String = TypeSafeMixin._safe_method_call_string(quest_data, "get_quest_id", [], "")
	var quest_title: String = TypeSafeMixin._safe_method_call_string(quest_data, "get_quest_title", [], "")
	var quest_type: int = TypeSafeMixin._safe_method_call_int(quest_data, "get_quest_type", [], -1)
	var quest_status: int = TypeSafeMixin._safe_method_call_int(quest_data, "get_quest_status", [], -1)
	
	assert_eq(quest_id, "test_quest", "Should set quest ID")
	assert_eq(quest_title, "Test Quest", "Should set quest title")
	assert_eq(quest_type, GameEnums.QuestType.STORY, "Should set quest type")
	assert_eq(quest_status, GameEnums.QuestStatus.ACTIVE, "Should set quest status")

func test_quest_objectives() -> void:
	var objective: Dictionary = {
		"id": 1,
		"description": "Test Objective",
		"completed": false,
		"required": true
	}
	
	TypeSafeMixin._safe_method_call_bool(quest_data, "add_objective", [objective])
	var objectives: Array = TypeSafeMixin._safe_method_call_array(quest_data, "get_objectives", [], [])
	assert_eq(objectives.size(), 1, "Should add objective")
	
	var completed: bool = TypeSafeMixin._safe_method_call_bool(quest_data, "is_completed", [], false)
	assert_false(completed, "Quest should not be completed")
	
	TypeSafeMixin._safe_method_call_bool(quest_data, "complete_objective", [1])
	var obj: Dictionary = TypeSafeMixin._safe_method_call_dict(quest_data, "get_objective", [1], {})
	assert_true(obj.get("completed", false), "Should complete objective")
	
	completed = TypeSafeMixin._safe_method_call_bool(quest_data, "is_completed", [], false)
	assert_true(completed, "Quest should be completed")

func test_quest_rewards() -> void:
	var reward: Dictionary = {
		"type": GameEnums.ResourceType.CREDITS,
		"amount": 1000,
		"claimed": false
	}
	
	TypeSafeMixin._safe_method_call_bool(quest_data, "add_reward", [reward])
	var rewards: Array = TypeSafeMixin._safe_method_call_array(quest_data, "get_rewards", [], [])
	assert_eq(rewards.size(), 1, "Should add reward")
	
	var rewards_claimed: bool = TypeSafeMixin._safe_method_call_bool(quest_data, "are_rewards_claimed", [], false)
	assert_false(rewards_claimed, "Rewards should not be claimed")
	
	TypeSafeMixin._safe_method_call_bool(quest_data, "claim_reward", [0])
	rewards = TypeSafeMixin._safe_method_call_array(quest_data, "get_rewards", [], [])
	assert_true(rewards[0].get("claimed", false), "Should claim reward")
	
	rewards_claimed = TypeSafeMixin._safe_method_call_bool(quest_data, "are_rewards_claimed", [], false)
	assert_true(rewards_claimed, "All rewards should be claimed")

func test_quest_requirements() -> void:
	var requirement: Dictionary = {
		"type": GameEnums.ResourceType.REPUTATION,
		"value": 5,
		"met": false
	}
	
	TypeSafeMixin._safe_method_call_bool(quest_data, "add_requirement", [requirement])
	var requirements: Array = TypeSafeMixin._safe_method_call_array(quest_data, "get_requirements", [], [])
	assert_eq(requirements.size(), 1, "Should add requirement")
	
	var requirements_met: bool = TypeSafeMixin._safe_method_call_bool(quest_data, "are_requirements_met", [], false)
	assert_false(requirements_met, "Requirements should not be met")
	
	TypeSafeMixin._safe_method_call_bool(quest_data, "update_requirement", [0, true])
	requirements = TypeSafeMixin._safe_method_call_array(quest_data, "get_requirements", [], [])
	assert_true(requirements[0].get("met", false), "Should update requirement")
	
	requirements_met = TypeSafeMixin._safe_method_call_bool(quest_data, "are_requirements_met", [], false)
	assert_true(requirements_met, "Requirements should be met")

func test_quest_location() -> void:
	var location: Dictionary = {
		"id": "loc_1",
		"name": "Test Location",
		"type": GameEnums.LocationType.TRADE_CENTER,
		"coordinates": Vector2(100, 100)
	}
	
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_location", [location])
	var quest_location: Dictionary = TypeSafeMixin._safe_method_call_dict(quest_data, "get_location", [], {})
	assert_not_null(quest_location, "Should set location")
	assert_eq(quest_location.get("id", ""), "loc_1", "Should preserve location ID")
	assert_eq(quest_location.get("type", -1), GameEnums.LocationType.TRADE_CENTER, "Should preserve location type")

func test_quest_progress() -> void:
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_progress", [50])
	var progress: int = TypeSafeMixin._safe_method_call_int(quest_data, "get_progress", [], 0)
	assert_eq(progress, 50, "Should set progress")
	
	TypeSafeMixin._safe_method_call_bool(quest_data, "increment_progress", [25])
	progress = TypeSafeMixin._safe_method_call_int(quest_data, "get_progress", [], 0)
	assert_eq(progress, 75, "Should increment progress")
	
	TypeSafeMixin._safe_method_call_bool(quest_data, "increment_progress", [50])
	progress = TypeSafeMixin._safe_method_call_int(quest_data, "get_progress", [], 0)
	assert_eq(progress, 100, "Should clamp progress at maximum")

func test_quest_completion() -> void:
	TypeSafeMixin._safe_method_call_bool(quest_data, "complete_quest", [])
	var status: int = TypeSafeMixin._safe_method_call_int(quest_data, "get_quest_status", [], -1)
	assert_eq(status, GameEnums.QuestStatus.COMPLETED, "Should mark quest as completed")
	
	var completed: bool = TypeSafeMixin._safe_method_call_bool(quest_data, "is_completed", [], false)
	assert_true(completed, "Should report quest as completed")
	
	TypeSafeMixin._safe_method_call_bool(quest_data, "fail_quest", [])
	status = TypeSafeMixin._safe_method_call_int(quest_data, "get_quest_status", [], -1)
	assert_eq(status, GameEnums.QuestStatus.FAILED, "Should mark quest as failed")
	
	completed = TypeSafeMixin._safe_method_call_bool(quest_data, "is_completed", [], false)
	assert_false(completed, "Should report quest as not completed")

func test_serialization() -> void:
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_quest_id", ["test_quest"])
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_quest_title", ["Test Quest"])
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_quest_type", [GameEnums.QuestType.STORY])
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_quest_status", [GameEnums.QuestStatus.ACTIVE])
	
	var objective: Dictionary = {
		"id": 1,
		"description": "Test Objective",
		"completed": false,
		"required": true
	}
	TypeSafeMixin._safe_method_call_bool(quest_data, "add_objective", [objective])
	
	var reward: Dictionary = {
		"type": GameEnums.ResourceType.CREDITS,
		"amount": 1000,
		"claimed": false
	}
	TypeSafeMixin._safe_method_call_bool(quest_data, "add_reward", [reward])
	
	var location: Dictionary = {
		"id": "loc_1",
		"name": "Test Location",
		"type": GameEnums.LocationType.TRADE_CENTER,
		"coordinates": Vector2(100, 100)
	}
	TypeSafeMixin._safe_method_call_bool(quest_data, "set_location", [location])
	
	var data: Dictionary = TypeSafeMixin._safe_method_call_dict(quest_data, "serialize", [], {})
	var new_quest: StoryQuestData = StoryQuestData.new()
	TypeSafeMixin._safe_method_call_bool(new_quest, "deserialize", [data])
	
	var quest_id: String = TypeSafeMixin._safe_method_call_string(new_quest, "get_quest_id", [], "")
	var quest_title: String = TypeSafeMixin._safe_method_call_string(new_quest, "get_quest_title", [], "")
	var quest_type: int = TypeSafeMixin._safe_method_call_int(new_quest, "get_quest_type", [], -1)
	var quest_status: int = TypeSafeMixin._safe_method_call_int(new_quest, "get_quest_status", [], -1)
	var objectives: Array = TypeSafeMixin._safe_method_call_array(new_quest, "get_objectives", [], [])
	var rewards: Array = TypeSafeMixin._safe_method_call_array(new_quest, "get_rewards", [], [])
	var quest_location: Dictionary = TypeSafeMixin._safe_method_call_dict(new_quest, "get_location", [], {})
	
	assert_eq(quest_id, "test_quest", "Should preserve quest ID")
	assert_eq(quest_title, "Test Quest", "Should preserve quest title")
	assert_eq(quest_type, GameEnums.QuestType.STORY, "Should preserve quest type")
	assert_eq(quest_status, GameEnums.QuestStatus.ACTIVE, "Should preserve quest status")
	assert_eq(objectives.size(), 1, "Should preserve objectives")
	assert_eq(rewards.size(), 1, "Should preserve rewards")
	assert_not_null(quest_location, "Should preserve location")