@tool
extends "res://tests/fixtures/base/game_test.gd"

const UnifiedStorySystem: GDScript = preload("res://src/core/story/UnifiedStorySystem.gd")
const StoryQuestData: GDScript = preload("res://src/core/story/StoryQuestData.gd")

# Test variables with explicit types
var story_system: UnifiedStorySystem = null
var signal_received: bool = false
var last_signal_data: Dictionary = {}

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
	
	TypeSafeMixin._safe_method_call_bool(story_system, "initialize_story", [test_data])
	
	assert_true(signal_received, "Story updated signal should be emitted")
	assert_eq(last_signal_data.title, test_data.title, "Story title should match")
	assert_eq(last_signal_data.description, test_data.description, "Story description should match")

func test_quest_addition() -> void:
	var test_quest: StoryQuestData = StoryQuestData.new()
	test_quest.id = "test_quest"
	test_quest.title = "Test Quest"
	test_quest.description = "A test quest"
	
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [test_quest])
	
	var quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_quests", [])
	assert_eq(quests.size(), 1, "Should have one quest")
	
	var quest: StoryQuestData = quests[0]
	assert_eq(quest.id, "test_quest", "Quest ID should match")
	assert_eq(quest.title, "Test Quest", "Quest title should match")

func test_quest_completion() -> void:
	var test_quest: StoryQuestData = StoryQuestData.new()
	test_quest.id = "test_quest"
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [test_quest])
	
	TypeSafeMixin._safe_method_call_bool(story_system, "complete_quest", ["test_quest"])
	
	assert_true(signal_received, "Quest completed signal should be emitted")
	assert_eq(last_signal_data.quest_id, "test_quest", "Completed quest ID should match")
	assert_eq(last_signal_data.status, "completed", "Quest status should be completed")

func test_quest_failure() -> void:
	var test_quest: StoryQuestData = StoryQuestData.new()
	test_quest.id = "test_quest"
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [test_quest])
	
	TypeSafeMixin._safe_method_call_bool(story_system, "fail_quest", ["test_quest"])
	
	assert_true(signal_received, "Quest failed signal should be emitted")
	assert_eq(last_signal_data.quest_id, "test_quest", "Failed quest ID should match")
	assert_eq(last_signal_data.status, "failed", "Quest status should be failed")

func test_quest_dependencies() -> void:
	var quest1: StoryQuestData = StoryQuestData.new()
	quest1.id = "quest1"
	
	var quest2: StoryQuestData = StoryQuestData.new()
	quest2.id = "quest2"
	quest2.dependencies = ["quest1"]
	
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [quest1])
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [quest2])
	
	var is_available: bool = TypeSafeMixin._safe_method_call_bool(story_system, "is_quest_available", ["quest2"])
	assert_false(is_available, "Quest2 should not be available until Quest1 is completed")
	
	TypeSafeMixin._safe_method_call_bool(story_system, "complete_quest", ["quest1"])
	is_available = TypeSafeMixin._safe_method_call_bool(story_system, "is_quest_available", ["quest2"])
	assert_true(is_available, "Quest2 should be available after Quest1 is completed")

func test_quest_state_persistence() -> void:
	var test_quest: StoryQuestData = StoryQuestData.new()
	test_quest.id = "test_quest"
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [test_quest])
	
	TypeSafeMixin._safe_method_call_bool(story_system, "complete_quest", ["test_quest"])
	
	var state: Dictionary = TypeSafeMixin._safe_method_call_dict(story_system, "get_story_state", [])
	assert_true(state.has("quests"), "Story state should have quests")
	assert_true(state.quests.has("test_quest"), "Story state should have test quest")
	assert_eq(state.quests.test_quest.status, "completed", "Quest status should be persisted")

func test_invalid_quest_operations() -> void:
	# Test completing non-existent quest
	TypeSafeMixin._safe_method_call_bool(story_system, "complete_quest", ["invalid_quest"])
	assert_false(signal_received, "Should not emit signal for invalid quest")
	
	# Test failing non-existent quest
	_reset_signals()
	TypeSafeMixin._safe_method_call_bool(story_system, "fail_quest", ["invalid_quest"])
	assert_false(signal_received, "Should not emit signal for invalid quest")
	
	# Test adding duplicate quest
	var test_quest: StoryQuestData = StoryQuestData.new()
	test_quest.id = "test_quest"
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [test_quest])
	
	_reset_signals()
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [test_quest])
	assert_false(signal_received, "Should not emit signal for duplicate quest")

func test_quest_validation() -> void:
	var invalid_quest: StoryQuestData = StoryQuestData.new()
	# Missing required ID
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [invalid_quest])
	
	var quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_quests", [])
	assert_eq(quests.size(), 0, "Should not add invalid quest")
	
	# Invalid dependency
	var quest: StoryQuestData = StoryQuestData.new()
	quest.id = "test_quest"
	quest.dependencies = ["non_existent_quest"]
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [quest])
	
	quests = TypeSafeMixin._safe_method_call_array(story_system, "get_quests", [])
	assert_eq(quests.size(), 0, "Should not add quest with invalid dependencies")