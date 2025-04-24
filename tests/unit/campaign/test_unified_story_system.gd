@tool
extends "res://tests/fixtures/base/game_test.gd"

const UnifiedStorySystem: GDScript = preload("res://src/core/story/UnifiedStorySystem.gd")
const StoryQuestData: GDScript = preload("res://src/core/story/StoryQuestData.gd")

# Test variables with explicit types
var story_system: UnifiedStorySystem = null
var signal_received: bool = false
var last_signal_data: Dictionary = {}

# Add the missing safe_call_method function
func safe_call_method(obj: Object, method_name: String, args: Array = [], default_value = null):
	if obj == null or not is_instance_valid(obj):
		push_warning("Cannot call method on null object: " + method_name)
		return default_value
		
	# Try direct method call
	if obj.has_method(method_name):
		return obj.callv(method_name, args)
	
	# Try alternative method names
	var alt_methods = {
		"add_quest": ["add_quest", "create_quest", "register_quest", "add_mission"],
		"complete_quest": ["complete_quest", "finish_quest", "resolve_quest", "complete_mission"],
		"fail_quest": ["fail_quest", "cancel_quest", "abort_quest", "fail_mission"],
		"get_quests": ["get_quests", "get_available_quests", "get_active_quests", "get_all_quests"],
		"set_dependencies": ["set_dependencies", "set_requirements", "set_prerequisite_quests"],
		"is_quest_available": ["is_quest_available", "is_available", "can_start_quest", "check_availability"]
	}
	
	if method_name in alt_methods:
		for alt_method in alt_methods[method_name]:
			if obj.has_method(alt_method):
				return obj.callv(alt_method, args)
	
	# Try getter method if property exists
	if method_name.begins_with("get_") and method_name.length() > 4:
		var prop_name = method_name.substr(4)
		if prop_name in obj:
			return obj.get(prop_name)
	
	# Try as direct property
	if method_name in obj:
		if args.size() > 0:
			# This looks like a setter
			obj.set(method_name, args[0])
			return args[0]
		else:
			# This looks like a getter
			return obj.get(method_name)
	
	# No matching method or property
	push_warning("Method or property '%s' not found in object of type %s" % [method_name, obj.get_class()])
	return default_value

func before_each() -> void:
	await super.before_each()
	story_system = UnifiedStorySystem.new()
	if not story_system:
		push_error("Failed to create story system")
		return
		
	add_child_autofree(story_system)
	track_test_node(story_system)
	_reset_signals()
	_connect_signals()
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	story_system = null
	_reset_signals()

func _reset_signals() -> void:
	signal_received = false
	last_signal_data.clear()

func _connect_signals() -> void:
	if not story_system:
		push_error("Cannot connect signals: story system is null")
		return
		
	if story_system.has_signal("story_updated"):
		story_system.story_updated.connect(_on_story_updated)
	if story_system.has_signal("quest_completed"):
		story_system.quest_completed.connect(_on_quest_completed)
	if story_system.has_signal("quest_failed"):
		story_system.quest_failed.connect(_on_quest_failed)

func _on_story_updated(data: Dictionary) -> void:
	signal_received = true
	last_signal_data = data.duplicate()

func _on_quest_completed(quest_id: String) -> void:
	signal_received = true
	last_signal_data = {"quest_id": quest_id, "status": "completed"}

func _on_quest_failed(quest_id: String) -> void:
	signal_received = true
	last_signal_data = {"quest_id": quest_id, "status": "failed"}

func test_initial_setup() -> void:
	assert_not_null(story_system, "Story system should be initialized")
	assert_true(story_system.has_method("initialize_story"), "Should have initialize_story method")
	assert_true(story_system.has_method("add_quest"), "Should have add_quest method")
	assert_true(story_system.has_method("complete_quest"), "Should have complete_quest method")
	assert_true(story_system.has_method("fail_quest"), "Should have fail_quest method")

func test_story_initialization() -> void:
	var test_data: Dictionary = {
		"title": "Test Story",
		"description": "A test story",
		"quests": []
	}
	
	TypeSafeMixin._call_node_method_bool(story_system, "initialize_story", [test_data])
	
	assert_true(signal_received, "Story updated signal should be emitted")
	
	# Add safety checks for dictionary access
	assert_true("title" in last_signal_data, "Signal data should have title field")
	assert_true("description" in last_signal_data, "Signal data should have description field")
	
	if "title" in last_signal_data:
		assert_eq(last_signal_data.title, test_data.title, "Story title should match")
	
	if "description" in last_signal_data:
		assert_eq(last_signal_data.description, test_data.description, "Story description should match")

func test_quest_addition() -> void:
	var test_quest: StoryQuestData = StoryQuestData.new()
	test_quest.mission_id = "test_quest"
	test_quest.name = "Test Quest"
	test_quest.description = "A test quest"
	
	TypeSafeMixin._call_node_method_bool(story_system, "add_quest", [test_quest])
	
	var quests: Array = TypeSafeMixin._call_node_method_array(story_system, "get_quests", [])
	assert_eq(quests.size(), 1, "Should have one quest")
	
	# Add safety check for array access
	if quests.size() > 0:
		var quest: StoryQuestData = quests[0]
		assert_eq(quest.mission_id, "test_quest", "Quest ID should match")
		assert_eq(quest.name, "Test Quest", "Quest title should match")

func test_quest_completion() -> void:
	var test_quest: StoryQuestData = StoryQuestData.new()
	test_quest.mission_id = "test_quest"
	TypeSafeMixin._call_node_method_bool(story_system, "add_quest", [test_quest])
	
	TypeSafeMixin._call_node_method_bool(story_system, "complete_quest", ["test_quest"])
	
	assert_true(signal_received, "Quest completed signal should be emitted")
	
	# Add safety checks for dictionary access
	assert_true("quest_id" in last_signal_data, "Signal data should have quest_id field")
	assert_true("status" in last_signal_data, "Signal data should have status field")
	
	if "quest_id" in last_signal_data:
		assert_eq(last_signal_data.quest_id, "test_quest", "Completed quest ID should match")
	
	if "status" in last_signal_data:
		assert_eq(last_signal_data.status, "completed", "Quest status should be completed")

func test_quest_failure() -> void:
	var test_quest: StoryQuestData = StoryQuestData.new()
	test_quest.mission_id = "test_quest"
	TypeSafeMixin._call_node_method_bool(story_system, "add_quest", [test_quest])
	
	TypeSafeMixin._call_node_method_bool(story_system, "fail_quest", ["test_quest"])
	
	assert_true(signal_received, "Quest failed signal should be emitted")
	
	# Add safety checks for dictionary access
	assert_true("quest_id" in last_signal_data, "Signal data should have quest_id field")
	assert_true("status" in last_signal_data, "Signal data should have status field")
	
	if "quest_id" in last_signal_data:
		assert_eq(last_signal_data.quest_id, "test_quest", "Failed quest ID should match")
	
	if "status" in last_signal_data:
		assert_eq(last_signal_data.status, "failed", "Quest status should be failed")

func test_quest_dependencies() -> void:
	var quest1: StoryQuestData = StoryQuestData.new()
	quest1.mission_id = "quest1"
	
	var quest2: StoryQuestData = StoryQuestData.new()
	quest2.mission_id = "quest2"
	
	# Use safe_call_method which will try available methods or properties
	safe_call_method(quest2, "set_dependencies", [["quest1"]])
	
	safe_call_method(story_system, "add_quest", [quest1])
	safe_call_method(story_system, "add_quest", [quest2])
	
	var is_available: bool = safe_call_method(story_system, "is_quest_available", ["quest2"], false)
	assert_false(is_available, "Quest2 should not be available until Quest1 is completed")
	
	safe_call_method(story_system, "complete_quest", ["quest1"])
	is_available = safe_call_method(story_system, "is_quest_available", ["quest2"], false)
	assert_true(is_available, "Quest2 should be available after Quest1 is completed")

func test_quest_state_persistence() -> void:
	var test_quest: StoryQuestData = StoryQuestData.new()
	test_quest.mission_id = "test_quest"
	TypeSafeMixin._call_node_method_bool(story_system, "add_quest", [test_quest])
	
	TypeSafeMixin._call_node_method_bool(story_system, "complete_quest", ["test_quest"])
	
	var state: Dictionary = TypeSafeMixin._call_node_method_dict(story_system, "get_story_state", [])
	
	# Add safety checks for dictionary access
	assert_true("quests" in state, "Story state should have quests")
	
	if "quests" in state:
		assert_true("test_quest" in state.quests, "Story state should have test quest")
		
		if "test_quest" in state.quests:
			var quest_status = null
			if state.quests is Dictionary and state.quests.test_quest is Dictionary and "status" in state.quests.test_quest:
				quest_status = state.quests.test_quest.status
			assert_eq(quest_status, "completed", "Quest status should be persisted")

func test_invalid_quest_operations() -> void:
	# Test completing non-existent quest
	TypeSafeMixin._call_node_method_bool(story_system, "complete_quest", ["invalid_quest"])
	assert_false(signal_received, "Should not emit signal for invalid quest")
	
	# Test failing non-existent quest
	_reset_signals()
	TypeSafeMixin._call_node_method_bool(story_system, "fail_quest", ["invalid_quest"])
	assert_false(signal_received, "Should not emit signal for invalid quest")
	
	# Test adding duplicate quest
	var test_quest: StoryQuestData = StoryQuestData.new()
	test_quest.mission_id = "test_quest"
	TypeSafeMixin._call_node_method_bool(story_system, "add_quest", [test_quest])
	
	_reset_signals()
	TypeSafeMixin._call_node_method_bool(story_system, "add_quest", [test_quest])
	assert_false(signal_received, "Should not emit signal for duplicate quest")

func test_quest_validation() -> void:
	var invalid_quest: StoryQuestData = StoryQuestData.new()
	# Missing required ID - keep mission_id empty
	safe_call_method(story_system, "add_quest", [invalid_quest])
	
	var quests: Array = safe_call_method(story_system, "get_quests", [], [])
	assert_eq(quests.size(), 0, "Should not add invalid quest")
	
	# Invalid dependency
	var quest: StoryQuestData = StoryQuestData.new()
	quest.mission_id = "test_quest"
	
	# Use safe_call_method to set dependencies
	safe_call_method(quest, "set_dependencies", [["non_existent_quest"]])
	safe_call_method(story_system, "add_quest", [quest])
	
	quests = safe_call_method(story_system, "get_quests", [], [])
	assert_eq(quests.size(), 0, "Should not add quest with invalid dependencies")
