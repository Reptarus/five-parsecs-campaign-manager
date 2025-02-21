@tool
extends "res://addons/gut/test.gd"

const UnifiedStorySystem: GDScript = preload("res://src/core/story/UnifiedStorySystem.gd")
const StoryQuestData: GDScript = preload("res://src/core/story/StoryQuestData.gd")
const GameEnums: GDScript = preload("res://src/core/systems/GlobalEnums.gd")
const TypeSafeMixin: GDScript = preload("res://tests/fixtures/type_safe_test_mixin.gd")
const TestHelper: GDScript = preload("res://tests/fixtures/test_helper.gd")

var story_system: UnifiedStorySystem = null
var signal_received: bool = false
var last_signal_data: Dictionary = {}

func before_each() -> void:
	await super.before_each()
	story_system = UnifiedStorySystem.new()
	if not story_system:
		push_error("Failed to create story system")
		return
		
	add_child(story_system)
	_reset_signals()
	_connect_signals()
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	if is_instance_valid(story_system):
		story_system.queue_free()
	story_system = null
	_reset_signals()

func _reset_signals() -> void:
	signal_received = false
	last_signal_data.clear()

func _connect_signals() -> void:
	if not story_system:
		push_error("Cannot connect signals: story system is null")
		return
		
	if story_system.has_signal("quest_added"):
		var err := story_system.connect("quest_added", _on_quest_added)
		if err != OK:
			push_error("Failed to connect quest_added signal")
			
	if story_system.has_signal("quest_completed"):
		var err := story_system.connect("quest_completed", _on_quest_completed)
		if err != OK:
			push_error("Failed to connect quest_completed signal")
			
	if story_system.has_signal("quest_failed"):
		var err := story_system.connect("quest_failed", _on_quest_failed)
		if err != OK:
			push_error("Failed to connect quest_failed signal")
			
	if story_system.has_signal("story_progressed"):
		var err := story_system.connect("story_progressed", _on_story_progressed)
		if err != OK:
			push_error("Failed to connect story_progressed signal")

func _on_quest_added(quest: StoryQuestData) -> void:
	signal_received = true
	last_signal_data = {"type": "quest_added", "quest": quest}

func _on_quest_completed(quest: StoryQuestData) -> void:
	signal_received = true
	last_signal_data = {"type": "quest_completed", "quest": quest}

func _on_quest_failed(quest: StoryQuestData) -> void:
	signal_received = true
	last_signal_data = {"type": "quest_failed", "quest": quest}

func _on_story_progressed(progress: int) -> void:
	signal_received = true
	last_signal_data = {"type": "story_progressed", "progress": progress}

func test_initialization() -> void:
	assert_not_null(story_system, "Story system should be initialized")
	
	var active_quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_active_quests", [], [])
	assert_eq(active_quests.size(), 0, "Should start with no active quests")
	
	var completed_quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_completed_quests", [], [])
	assert_eq(completed_quests.size(), 0, "Should start with no completed quests")
	
	var progress: int = TypeSafeMixin._safe_method_call_int(story_system, "get_story_progress", [], 0)
	assert_eq(progress, 0, "Should start with no story progress")

func test_add_quest() -> void:
	var quest: StoryQuestData = StoryQuestData.new()
	if not quest:
		push_error("Failed to create quest")
		return
		
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_id", ["test_quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_title", ["Test Quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_type", [GameEnums.QuestType.STORY])
	
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [quest])
	var active_quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_active_quests", [], [])
	assert_eq(active_quests.size(), 1, "Should add quest to active quests")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit quest_added signal")
	assert_eq(last_signal_data.get("signal_name", ""), "quest_added", "Should emit correct signal")

func test_complete_quest() -> void:
	var quest: StoryQuestData = StoryQuestData.new()
	if not quest:
		push_error("Failed to create quest")
		return
		
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_id", ["test_quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_title", ["Test Quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_type", [GameEnums.QuestType.STORY])
	
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [quest])
	TypeSafeMixin._safe_method_call_bool(story_system, "complete_quest", [quest])
	
	var active_quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_active_quests", [], [])
	assert_eq(active_quests.size(), 0, "Should remove from active quests")
	
	var completed_quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_completed_quests", [], [])
	assert_eq(completed_quests.size(), 1, "Should add to completed quests")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit quest_completed signal")
	assert_eq(last_signal_data.get("signal_name", ""), "quest_completed", "Should emit correct signal")

func test_fail_quest() -> void:
	var quest: StoryQuestData = StoryQuestData.new()
	if not quest:
		push_error("Failed to create quest")
		return
		
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_id", ["test_quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_title", ["Test Quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_type", [GameEnums.QuestType.STORY])
	
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [quest])
	TypeSafeMixin._safe_method_call_bool(story_system, "fail_quest", [quest])
	
	var active_quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_active_quests", [], [])
	assert_eq(active_quests.size(), 0, "Should remove from active quests")
	
	var failed_quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_failed_quests", [], [])
	assert_eq(failed_quests.size(), 1, "Should add to failed quests")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit quest_failed signal")
	assert_eq(last_signal_data.get("signal_name", ""), "quest_failed", "Should emit correct signal")

func test_story_progress() -> void:
	var quest: StoryQuestData = StoryQuestData.new()
	if not quest:
		push_error("Failed to create quest")
		return
		
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_id", ["test_quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_title", ["Test Quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_type", [GameEnums.QuestType.STORY])
	TypeSafeMixin._safe_method_call_bool(quest, "set_story_progress", [10])
	
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [quest])
	TypeSafeMixin._safe_method_call_bool(story_system, "complete_quest", [quest])
	
	var progress: int = TypeSafeMixin._safe_method_call_int(story_system, "get_story_progress", [], 0)
	assert_eq(progress, 10, "Should update story progress when completing quest")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit story_progressed signal")
	assert_eq(last_signal_data.get("signal_name", ""), "story_progressed", "Should emit correct signal")

func test_quest_tracking() -> void:
	var quest: StoryQuestData = StoryQuestData.new()
	if not quest:
		push_error("Failed to create quest")
		return
		
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_id", ["test_quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_title", ["Test Quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_type", [GameEnums.QuestType.STORY])
	
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [quest])
	var tracked_quest: StoryQuestData = TypeSafeMixin._safe_method_call_resource(story_system, "get_quest", ["test_quest"], null)
	assert_not_null(tracked_quest, "Should track quest by ID")
	
	var quest_title: String = TypeSafeMixin._safe_method_call_string(tracked_quest, "get_quest_title", [], "")
	assert_eq(quest_title, "Test Quest", "Should preserve quest data")

func test_quest_requirements() -> void:
	var quest: StoryQuestData = StoryQuestData.new()
	if not quest:
		push_error("Failed to create quest")
		return
		
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_id", ["test_quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_title", ["Test Quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_type", [GameEnums.QuestType.STORY])
	
	var requirement: Dictionary = {
		"type": GameEnums.ResourceType.REPUTATION,
		"value": 5,
		"met": false
	}
	TypeSafeMixin._safe_method_call_bool(quest, "add_requirement", [requirement])
	
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [quest])
	var can_start: bool = TypeSafeMixin._safe_method_call_bool(story_system, "can_start_quest", [quest], false)
	assert_false(can_start, "Should not allow starting quest with unmet requirements")
	
	TypeSafeMixin._safe_method_call_bool(quest, "update_requirement", [0, true])
	can_start = TypeSafeMixin._safe_method_call_bool(story_system, "can_start_quest", [quest], false)
	assert_true(can_start, "Should allow starting quest with met requirements")

func test_serialization() -> void:
	var quest: StoryQuestData = StoryQuestData.new()
	if not quest:
		push_error("Failed to create quest")
		return
		
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_id", ["test_quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_title", ["Test Quest"])
	TypeSafeMixin._safe_method_call_bool(quest, "set_quest_type", [GameEnums.QuestType.STORY])
	
	TypeSafeMixin._safe_method_call_bool(story_system, "add_quest", [quest])
	TypeSafeMixin._safe_method_call_bool(story_system, "advance_story", [])
	
	var data: Dictionary = TypeSafeMixin._safe_method_call_dict(story_system, "serialize", [], {})
	var new_system: UnifiedStorySystem = UnifiedStorySystem.new()
	TypeSafeMixin._safe_method_call_bool(new_system, "deserialize", [data])
	
	var active_quests: Array = TypeSafeMixin._safe_method_call_array(new_system, "get_active_quests", [], [])
	var completed_quests: Array = TypeSafeMixin._safe_method_call_array(new_system, "get_completed_quests", [], [])
	var progress: int = TypeSafeMixin._safe_method_call_int(new_system, "get_story_progress", [], 0)
	
	var original_active_quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_active_quests", [], [])
	var original_completed_quests: Array = TypeSafeMixin._safe_method_call_array(story_system, "get_completed_quests", [], [])
	var original_progress: int = TypeSafeMixin._safe_method_call_int(story_system, "get_story_progress", [], 0)
	
	assert_eq(active_quests.size(), original_active_quests.size(), "Should preserve active quests")
	assert_eq(completed_quests.size(), original_completed_quests.size(), "Should preserve completed quests")
	assert_eq(progress, original_progress, "Should preserve story progress")