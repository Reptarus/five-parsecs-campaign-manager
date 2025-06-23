@tool
extends GdUnitGameTest

#
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

#
class MockUnifiedStorySystem extends Resource:
    var story_data: Dictionary = {}
    var quests: Array[MockStoryQuestData] = []
    var completed_quests: Array[String] = []
    var failed_quests: Array[String] = []
    
    #
    func initialize_story(data: Dictionary) -> void:
        story_data = data.duplicate()
    
    func get_story_data() -> Dictionary:
        return story_data

    #
    func add_quest(quest: MockStoryQuestData) -> bool:
        if quest and quest.id != "":
            for existing_quest in quests:
                if existing_quest.id == quest.id:
                    return false
            quests.append(quest)
            return true
        return false

    func get_quests() -> Array[MockStoryQuestData]:
        return quests

    func complete_quest(quest: MockStoryQuestData) -> bool:
        if quest and _has_quest(quest.id):
            if not completed_quests.has(quest.id):
                completed_quests.append(quest.id)
                quest_completed.emit(quest.id)
                return true
        return false

    func fail_quest(quest: MockStoryQuestData) -> bool:
        if quest and _has_quest(quest.id):
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
        var quest_states = {}
        for quest in quests:
            quest_states[quest.id] = {"status": quest.status}
        return {
            "story": story_data,
            "quests": quest_states,
            "completed_quests": completed_quests,
            "failed_quests": failed_quests,
        }
    
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

    signal story_updated(data: Dictionary)
    signal quest_completed(quest_id: String)
    signal quest_failed(quest_id: String)
    
    #
    func mock_has_method(method_name: String) -> bool:
        return true

    func mock_has_signal(signal_name: String) -> bool:
        return true

# Type-safe instance variables
var story_system: MockUnifiedStorySystem = null
var signal_received: bool = false
var last_signal_data: Dictionary = {}

func before_test() -> void:
    super.before_test()
    story_system = MockUnifiedStorySystem.new()
    _reset_signals()

func after_test() -> void:
    story_system = null
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
    assert_that(story_system.get_quests()).is_empty()
    assert_that(story_system.get_story_data()).is_empty()

func test_story_initialization() -> void:
    var test_data: Dictionary = {
        "title": "Test Story",
        "description": "A test story",
        "quests": [],
    }
    story_system.initialize_story(test_data)
    
    var retrieved_data = story_system.get_story_data()
    assert_that(retrieved_data).contains_keys(["title", "description", "quests"])
    assert_that(retrieved_data["title"]).is_equal("Test Story")

func test_quest_addition() -> void:
    var test_quest = MockStoryQuestData.new()
    test_quest.id = "test_quest"
    test_quest.title = "Test Quest"
    test_quest.description = "A test quest"
    
    var success: bool = story_system.add_quest(test_quest)
    assert_that(success).is_true()
    
    var quests: Array[MockStoryQuestData] = story_system.get_quests()
    assert_that(quests).has_size(1)
    
    var quest: MockStoryQuestData = quests[0]
    assert_that(quest.get_id()).is_equal("test_quest")

func test_quest_completion() -> void:
    var test_quest = MockStoryQuestData.new()
    test_quest.id = "test_quest"
    story_system.add_quest(test_quest)
    
    var success: bool = story_system.complete_quest(test_quest)
    assert_that(success).is_true()
    
    var state = story_system.get_story_state()
    assert_that(state["completed_quests"]).contains("test_quest")

func test_quest_failure() -> void:
    var test_quest = MockStoryQuestData.new()
    test_quest.id = "test_quest"
    story_system.add_quest(test_quest)
    
    var success: bool = story_system.fail_quest(test_quest)
    assert_that(success).is_true()
    
    var state = story_system.get_story_state()
    assert_that(state["failed_quests"]).contains("test_quest")

func test_quest_dependencies() -> void:
    var quest1 = MockStoryQuestData.new()
    quest1.id = "quest1"
    
    var quest2 = MockStoryQuestData.new()
    quest2.id = "quest2"
    quest2.dependencies = ["quest1"]
    
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
    
    story_system.add_quest(test_quest)
    story_system.complete_quest(test_quest)
    
    var state: Dictionary = story_system.get_story_state()
    assert_that(state).contains_keys(["story", "quests", "completed_quests", "failed_quests"])
    assert_that(state["completed_quests"]).contains("test_quest")

func test_invalid_quest_operations() -> void:
    # Test completing non-existent quest
    var invalid_quest = MockStoryQuestData.new()
    invalid_quest.id = "invalid_quest"
    
    var success: bool = story_system.complete_quest(invalid_quest)
    assert_that(success).is_false()
    
    # Test failing non-existent quest
    _reset_signals()
    var invalid_quest2 = MockStoryQuestData.new()
    invalid_quest2.id = "invalid_quest2"
    success = story_system.fail_quest(invalid_quest2)
    assert_that(success).is_false()
    
    # Test adding duplicate quest
    var test_quest = MockStoryQuestData.new()
    test_quest.id = "test_quest"
    story_system.add_quest(test_quest)
    
    success = story_system.add_quest(test_quest)
    assert_that(success).is_false()

func test_quest_validation() -> void:
    # Test invalid quest with empty ID
    var invalid_quest: MockStoryQuestData = MockStoryQuestData.new()
    invalid_quest.id = ""
    var success: bool = story_system.add_quest(invalid_quest)
    assert_that(success).is_false()
    
    # Test null quest
    success = story_system.add_quest(null)
    assert_that(success).is_false()

func test_complex_story_flow() -> void:
    # Initialize story
    var story_data = {
        "title": "Epic Story",
        "description": "An epic tale",
        "chapter": 1,
    }
    story_system.initialize_story(story_data)
    
    # Create quest chain
    var quest1 = MockStoryQuestData.new()
    quest1.id = "prologue"
    quest1.title = "Prologue"
    
    var quest2 = MockStoryQuestData.new()
    quest2.id = "chapter1"
    quest2.title = "Chapter 1"
    quest2.dependencies = ["prologue"]
    
    var quest3 = MockStoryQuestData.new()
    quest3.id = "chapter2"
    quest3.title = "Chapter 2"
    quest3.dependencies = ["chapter1"]
    
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
    assert_that(final_state["completed_quests"]).has_size(2)
    assert_that(final_state["completed_quests"]).contains_exactly(["prologue", "chapter1"])

func test_story_data_management() -> void:
    var initial_data = {
        "title": "Test Story",
        "description": "A story for testing",
        "version": 1
    }
    story_system.initialize_story(initial_data)
    var retrieved_data = story_system.get_story_data()
    
    assert_that(retrieved_data["title"]).is_equal("Test Story")
    assert_that(retrieved_data["version"]).is_equal(1)

func test_quest_status_tracking() -> void:
    var quest1 = MockStoryQuestData.new()
    quest1.id = "quest1"
    
    var quest2 = MockStoryQuestData.new()
    quest2.id = "quest2"
    
    story_system.add_quest(quest1)
    story_system.add_quest(quest2)
    
    # Complete one, fail another
    story_system.complete_quest(quest1)
    story_system.fail_quest(quest2)
    
    var state = story_system.get_story_state()
    assert_that(state["completed_quests"]).contains("quest1")
    assert_that(state["failed_quests"]).contains("quest2")
    assert_that(state["completed_quests"]).does_not_contain("quest2")
    assert_that(state["failed_quests"]).does_not_contain("quest1")
