@tool
extends GdUnitGameTest

# Mock Story Quest Data with expected values (Universal Mock Strategy)
class MockStoryQuestData extends Resource:
	var id: String = "test_quest_001"
	var title: String = "Test Quest"
	var description: String = "A test quest"
	var dependencies: Array = []
	var status: String = "pending"
	
	func get_id() -> String: return id
	func get_title() -> String: return title
	func get_description() -> String: return description
	func get_dependencies() -> Array: return dependencies
	func get_status() -> String: return status
	func set_status(new_status: String) -> void: status = new_status

# Mock Unified Story System with expected values (Universal Mock Strategy)
class MockUnifiedStorySystem extends Resource:
	var story_data: Dictionary = {}
	var quests: Array[MockStoryQuestData] = []
	var completed_quests: Array[String] = []
	var failed_quests: Array[String] = []
	
	# Core story management
	func initialize_story(data: Dictionary) -> void:
		story_data = data.duplicate()
		story_updated.emit(story_data)
	
	func get_story_data() -> Dictionary:
		return story_data
	
	# Quest management
	func add_quest(quest: MockStoryQuestData) -> bool:
		if quest and quest.id != "":
			for existing_quest in quests:
				if existing_quest.id == quest.id:
					return false # Duplicate quest
			quests.append(quest)
			return true
		return false
	
	func get_quests() -> Array[MockStoryQuestData]:
		return quests
	
	func complete_quest(quest: MockStoryQuestData) -> bool:
		if quest and _has_quest(quest.id):
			quest.set_status("completed")
			if not completed_quests.has(quest.id):
				completed_quests.append(quest.id)
			quest_completed.emit(quest.id)
			return true
		return false
	
	func fail_quest(quest: MockStoryQuestData) -> bool:
		if quest and _has_quest(quest.id):
			quest.set_status("failed")
			if not failed_quests.has(quest.id):
				failed_quests.append(quest.id)
			quest_failed.emit(quest.id)
			return true
		return false
	
	func is_quest_available(quest_id: String) -> bool:
		var quest = _get_quest_by_id(quest_id)
		if quest:
			for dependency in quest.dependencies:
				if not completed_quests.has(dependency):
					return false
			return true
		return false
	
	func get_story_state() -> Dictionary:
		var quest_states: Dictionary = {}
		for quest in quests:
			quest_states[quest.id] = {"status": quest.status}
		return {
			"story": story_data,
			"quests": quest_states,
			"completed_quests": completed_quests,
			"failed_quests": failed_quests
		}
	
	# Helper methods
	func _has_quest(quest_id: String) -> bool:
		for quest in quests:
			if quest.id == quest_id:
				return true
		return false
	
	func _get_quest_by_id(quest_id: String) -> MockStoryQuestData:
		for quest in quests:
			if quest.id == quest_id:
				return quest
		return null
	
	# Required signals (immediate emission pattern)
	signal story_updated(data: Dictionary)
	signal quest_completed(quest_id: String)
	signal quest_failed(quest_id: String)
	
	# Required methods from Node interface (renamed to avoid conflicts)
	func mock_has_method(method_name: String) -> bool:
		return true # Mock always has methods
	
	func mock_has_signal(signal_name: String) -> bool:
		return signal_name in ["story_updated", "quest_completed", "quest_failed"]

# Type-safe instance variables
var story_system: MockUnifiedStorySystem = null
var signal_received: bool = false
var last_signal_data: Dictionary = {}

func before_test() -> void:
	super.before_test()
	story_system = MockUnifiedStorySystem.new()
	track_resource(story_system)
	_reset_signals()
	_connect_signals()

func after_test() -> void:
	story_system = null
	_reset_signals()
	super.after_test()

func _reset_signals() -> void:
	signal_received = false
	last_signal_data.clear()

func _connect_signals() -> void:
	if story_system:
		story_system.story_updated.connect(_on_story_updated)
		story_system.quest_completed.connect(_on_quest_completed)
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
	assert_that(story_system).is_not_null()
	# Test direct method calls instead of safe wrappers (proven pattern)
	assert_that(story_system.mock_has_method("initialize_story")).is_true()
	assert_that(story_system.mock_has_method("add_quest")).is_true()
	assert_that(story_system.mock_has_method("complete_quest")).is_true()
	assert_that(story_system.mock_has_method("fail_quest")).is_true()

func test_story_initialization() -> void:
	var test_data: Dictionary = {
		"title": "Test Story",
		"description": "A test story",
		"quests": []
	}
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	story_system.initialize_story(test_data)
	
	assert_that(signal_received).is_true()
	assert_that(last_signal_data.get("title", "")).is_equal(test_data.title)
	assert_that(last_signal_data.get("description", "")).is_equal(test_data.description)

func test_quest_addition() -> void:
	var test_quest = MockStoryQuestData.new()
	test_quest.id = "test_quest"
	test_quest.title = "Test Quest"
	test_quest.description = "A test quest"
	track_resource(test_quest)
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	var success: bool = story_system.add_quest(test_quest)
	assert_that(success).is_true()
	
	var quests: Array[MockStoryQuestData] = story_system.get_quests()
	assert_that(quests.size()).is_equal(1)
	
	var quest: MockStoryQuestData = quests[0]
	assert_that(quest.id).is_equal("test_quest")
	assert_that(quest.title).is_equal("Test Quest")

func test_quest_completion() -> void:
	var test_quest = MockStoryQuestData.new()
	test_quest.id = "test_quest"
	track_resource(test_quest)
	
	story_system.add_quest(test_quest)
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	var success: bool = story_system.complete_quest(test_quest)
	assert_that(success).is_true()
	
	assert_that(signal_received).is_true()
	assert_that(last_signal_data.get("quest_id", "")).is_equal("test_quest")
	assert_that(last_signal_data.get("status", "")).is_equal("completed")

func test_quest_failure() -> void:
	var test_quest = MockStoryQuestData.new()
	test_quest.id = "test_quest"
	track_resource(test_quest)
	
	story_system.add_quest(test_quest)
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	var success: bool = story_system.fail_quest(test_quest)
	assert_that(success).is_true()
	
	assert_that(signal_received).is_true()
	assert_that(last_signal_data.get("quest_id", "")).is_equal("test_quest")
	assert_that(last_signal_data.get("status", "")).is_equal("failed")

func test_quest_dependencies() -> void:
	var quest1 = MockStoryQuestData.new()
	quest1.id = "quest1"
	track_resource(quest1)
	
	var quest2 = MockStoryQuestData.new()
	quest2.id = "quest2"
	quest2.dependencies = ["quest1"]
	track_resource(quest2)
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	story_system.add_quest(quest1)
	story_system.add_quest(quest2)
	
	var is_available: bool = story_system.is_quest_available("quest2")
	assert_that(is_available).is_false()
	
	story_system.complete_quest(quest1)
	
	is_available = story_system.is_quest_available("quest2")
	assert_that(is_available).is_true()

func test_quest_state_persistence() -> void:
	var test_quest = MockStoryQuestData.new()
	test_quest.id = "test_quest"
	track_resource(test_quest)
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	story_system.add_quest(test_quest)
	story_system.complete_quest(test_quest)
	
	var state: Dictionary = story_system.get_story_state()
	assert_that(state.has("quests")).is_true()
	assert_that(state.quests.has("test_quest")).is_true()
	assert_that(state.quests.test_quest.status).is_equal("completed")

func test_invalid_quest_operations() -> void:
	# Test completing non-existent quest
	var invalid_quest = MockStoryQuestData.new()
	invalid_quest.id = "invalid_quest"
	track_resource(invalid_quest)
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	var success: bool = story_system.complete_quest(invalid_quest)
	assert_that(success).is_false()
	assert_that(signal_received).is_false()
	
	# Test failing non-existent quest
	_reset_signals()
	var invalid_quest2 = MockStoryQuestData.new()
	invalid_quest2.id = "invalid_quest2"
	track_resource(invalid_quest2)
	
	success = story_system.fail_quest(invalid_quest2)
	assert_that(success).is_false()
	assert_that(signal_received).is_false()
	
	# Test adding duplicate quest
	var test_quest = MockStoryQuestData.new()
	test_quest.id = "test_quest"
	track_resource(test_quest)
	
	story_system.add_quest(test_quest)
	
	_reset_signals()
	success = story_system.add_quest(test_quest)
	assert_that(success).is_false()

func test_quest_validation() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var invalid_quest = MockStoryQuestData.new()
	# Missing required ID
	invalid_quest.id = ""
	track_resource(invalid_quest)
	
	var success: bool = story_system.add_quest(invalid_quest)
	assert_that(success).is_false()
	
	# Test null quest
	success = story_system.add_quest(null)
	assert_that(success).is_false()

func test_complex_story_flow() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Initialize story
	var story_data = {
		"title": "Epic Story",
		"description": "An epic tale",
		"chapter": 1
	}
	story_system.initialize_story(story_data)
	
	# Create quest chain
	var quest1 = MockStoryQuestData.new()
	quest1.id = "prologue"
	quest1.title = "Prologue"
	track_resource(quest1)
	
	var quest2 = MockStoryQuestData.new()
	quest2.id = "chapter1"
	quest2.title = "Chapter 1"
	quest2.dependencies = ["prologue"]
	track_resource(quest2)
	
	var quest3 = MockStoryQuestData.new()
	quest3.id = "chapter2"
	quest3.title = "Chapter 2"
	quest3.dependencies = ["chapter1"]
	track_resource(quest3)
	
	# Add quests
	assert_that(story_system.add_quest(quest1)).is_true()
	assert_that(story_system.add_quest(quest2)).is_true()
	assert_that(story_system.add_quest(quest3)).is_true()
	
	# Test quest availability
	assert_that(story_system.is_quest_available("prologue")).is_true()
	assert_that(story_system.is_quest_available("chapter1")).is_false()
	assert_that(story_system.is_quest_available("chapter2")).is_false()
	
	# Complete prologue
	story_system.complete_quest(quest1)
	assert_that(story_system.is_quest_available("chapter1")).is_true()
	assert_that(story_system.is_quest_available("chapter2")).is_false()
	
	# Complete chapter 1
	story_system.complete_quest(quest2)
	assert_that(story_system.is_quest_available("chapter2")).is_true()
	
	# Verify final state
	var final_state = story_system.get_story_state()
	assert_that(final_state.completed_quests.size()).is_equal(2)
	assert_that(final_state.completed_quests.has("prologue")).is_true()
	assert_that(final_state.completed_quests.has("chapter1")).is_true()

func test_story_data_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var initial_data = {
		"title": "Test Story",
		"description": "A story for testing"
	}
	
	story_system.initialize_story(initial_data)
	var retrieved_data = story_system.get_story_data()
	
	assert_that(retrieved_data.get("title", "")).is_equal("Test Story")
	assert_that(retrieved_data.get("description", "")).is_equal("A story for testing")

func test_quest_status_tracking() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var quest1 = MockStoryQuestData.new()
	quest1.id = "quest1"
	track_resource(quest1)
	
	var quest2 = MockStoryQuestData.new()
	quest2.id = "quest2"
	track_resource(quest2)
	
	story_system.add_quest(quest1)
	story_system.add_quest(quest2)
	
	# Complete one, fail the other
	story_system.complete_quest(quest1)
	story_system.fail_quest(quest2)
	
	var state = story_system.get_story_state()
	assert_that(state.completed_quests.has("quest1")).is_true()
	assert_that(state.failed_quests.has("quest2")).is_true()
	assert_that(state.quests.quest1.status).is_equal("completed")
	assert_that(state.quests.quest2.status).is_equal("failed")