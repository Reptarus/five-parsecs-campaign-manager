@tool
extends GameTest

const StoryQuestData: GDScript = preload("res://src/core/story/StoryQuestData.gd")

var quest_data: StoryQuestData = null

func before_each() -> void:
	await super.before_each()
	quest_data = StoryQuestData.new()
	if not quest_data:
		push_error("Failed to create story quest data")
		return
	track_test_resource(quest_data)
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	quest_data = null

func test_initialization() -> void:
	assert_not_null(quest_data, "Story quest data should be initialized")
	
	var quest_id: String = _call_node_method_string(quest_data, "get_quest_id", [], "")
	var title: String = _call_node_method_string(quest_data, "get_title", [], "")
	var description: String = _call_node_method_string(quest_data, "get_description", [], "")
	var objectives: Array = _call_node_method_array(quest_data, "get_objectives", [], [])
	var rewards: Dictionary = _call_node_method_dict(quest_data, "get_rewards", [], {})
	var prerequisites: Array = _call_node_method_array(quest_data, "get_prerequisites", [], [])
	
	assert_ne(quest_id, "", "Should initialize with a quest ID")
	assert_ne(title, "", "Should initialize with a title")
	assert_ne(description, "", "Should initialize with a description")
	assert_eq(objectives.size(), 0, "Should initialize with no objectives")
	assert_eq(rewards.size(), 0, "Should initialize with no rewards")
	assert_eq(prerequisites.size(), 0, "Should initialize with no prerequisites")

func test_objective_management() -> void:
	# Test adding objectives
	var objective1 = {
		"id": "obj1",
		"description": "Test objective 1",
		"type": "kill",
		"target": "enemy_type_1",
		"amount": 5,
		"completed": false
	}
	
	var objective2 = {
		"id": "obj2",
		"description": "Test objective 2",
		"type": "collect",
		"target": "item_type_1",
		"amount": 3,
		"completed": false
	}
	
	var success: bool = _call_node_method_bool(quest_data, "add_objective", [objective1], false)
	assert_true(success, "Should successfully add first objective")
	
	success = _call_node_method_bool(quest_data, "add_objective", [objective2], false)
	assert_true(success, "Should successfully add second objective")
	
	var objectives: Array = _call_node_method_array(quest_data, "get_objectives", [], [])
	assert_eq(objectives.size(), 2, "Should have two objectives")
	
	# Test completing objectives
	success = _call_node_method_bool(quest_data, "complete_objective", ["obj1"], false)
	assert_true(success, "Should successfully complete first objective")
	
	var is_completed: bool = _call_node_method_bool(quest_data, "is_objective_completed", ["obj1"], false)
	assert_true(is_completed, "First objective should be marked as completed")
	
	is_completed = _call_node_method_bool(quest_data, "is_objective_completed", ["obj2"], false)
	assert_false(is_completed, "Second objective should not be marked as completed")
	
	# Test quest completion
	success = _call_node_method_bool(quest_data, "complete_objective", ["obj2"], false)
	assert_true(success, "Should successfully complete second objective")
	
	is_completed = _call_node_method_bool(quest_data, "is_completed", [], false)
	assert_true(is_completed, "Quest should be marked as completed when all objectives are done")

func test_reward_management() -> void:
	# Test setting rewards
	var rewards = {
		"credits": 1000,
		"experience": 500,
		"items": ["item1", "item2"],
		"reputation": 50
	}
	
	var success: bool = _call_node_method_bool(quest_data, "set_rewards", [rewards], false)
	assert_true(success, "Should successfully set rewards")
	
	var quest_rewards: Dictionary = _call_node_method_dict(quest_data, "get_rewards", [], {})
	assert_eq(quest_rewards.credits, 1000, "Should store correct credit reward")
	assert_eq(quest_rewards.experience, 500, "Should store correct experience reward")
	assert_eq(quest_rewards.items.size(), 2, "Should store correct number of item rewards")
	assert_eq(quest_rewards.reputation, 50, "Should store correct reputation reward")
	
	# Test claiming rewards
	success = _call_node_method_bool(quest_data, "claim_rewards", [], false)
	assert_true(success, "Should successfully claim rewards")
	
	var is_claimed: bool = _call_node_method_bool(quest_data, "are_rewards_claimed", [], false)
	assert_true(is_claimed, "Rewards should be marked as claimed")
	
	success = _call_node_method_bool(quest_data, "claim_rewards", [], false)
	assert_false(success, "Should not be able to claim rewards twice")

func test_prerequisite_management() -> void:
	# Test adding prerequisites
	var prereq1 = {
		"type": "quest",
		"id": "quest_1",
		"state": "completed"
	}
	
	var prereq2 = {
		"type": "level",
		"value": 5
	}
	
	var success: bool = _call_node_method_bool(quest_data, "add_prerequisite", [prereq1], false)
	assert_true(success, "Should successfully add first prerequisite")
	
	success = _call_node_method_bool(quest_data, "add_prerequisite", [prereq2], false)
	assert_true(success, "Should successfully add second prerequisite")
	
	var prerequisites: Array = _call_node_method_array(quest_data, "get_prerequisites", [], [])
	assert_eq(prerequisites.size(), 2, "Should have two prerequisites")
	
	# Test checking prerequisites
	success = _call_node_method_bool(quest_data, "check_prerequisites", [ {"completed_quests": ["quest_1"], "player_level": 6}], false)
	assert_true(success, "Should pass prerequisite check when conditions are met")
	
	success = _call_node_method_bool(quest_data, "check_prerequisites", [ {"completed_quests": [], "player_level": 6}], false)
	assert_false(success, "Should fail prerequisite check when quest not completed")
	
	success = _call_node_method_bool(quest_data, "check_prerequisites", [ {"completed_quests": ["quest_1"], "player_level": 4}], false)
	assert_false(success, "Should fail prerequisite check when level too low")

func test_serialization() -> void:
	# Setup quest state
	_call_node_method_bool(quest_data, "set_quest_id", ["test_quest"])
	_call_node_method_bool(quest_data, "set_title", ["Test Quest"])
	_call_node_method_bool(quest_data, "set_description", ["Test Description"])
	
	var objective = {
		"id": "obj1",
		"description": "Test objective",
		"type": "kill",
		"target": "enemy_type_1",
		"amount": 5,
		"completed": false
	}
	_call_node_method_bool(quest_data, "add_objective", [objective])
	
	var rewards = {
		"credits": 1000,
		"experience": 500,
		"items": ["item1"],
		"reputation": 50
	}
	_call_node_method_bool(quest_data, "set_rewards", [rewards])
	
	var prereq = {
		"type": "quest",
		"id": "quest_1",
		"state": "completed"
	}
	_call_node_method_bool(quest_data, "add_prerequisite", [prereq])
	
	# Serialize and deserialize
	var data: Dictionary = _call_node_method_dict(quest_data, "serialize", [], {})
	var new_quest_data: StoryQuestData = StoryQuestData.new()
	track_test_resource(new_quest_data)
	_call_node_method_bool(new_quest_data, "deserialize", [data])
	
	# Verify quest properties
	var quest_id: String = _call_node_method_string(new_quest_data, "get_quest_id", [], "")
	var title: String = _call_node_method_string(new_quest_data, "get_title", [], "")
	var description: String = _call_node_method_string(new_quest_data, "get_description", [], "")
	var objectives: Array = _call_node_method_array(new_quest_data, "get_objectives", [], [])
	var quest_rewards: Dictionary = _call_node_method_dict(new_quest_data, "get_rewards", [], {})
	var prerequisites: Array = _call_node_method_array(new_quest_data, "get_prerequisites", [], [])
	
	assert_eq(quest_id, "test_quest", "Should preserve quest ID")
	assert_eq(title, "Test Quest", "Should preserve title")
	assert_eq(description, "Test Description", "Should preserve description")
	assert_eq(objectives.size(), 1, "Should preserve objectives")
	assert_eq(quest_rewards.credits, 1000, "Should preserve rewards")
	assert_eq(prerequisites.size(), 1, "Should preserve prerequisites")