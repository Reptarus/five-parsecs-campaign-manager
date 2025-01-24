extends "res://addons/gut/test.gd"

const UnifiedStorySystem = preload("res://src/core/story/UnifiedStorySystem.gd")
const StoryQuestData = preload("res://src/core/story/StoryQuestData.gd")

var story_system: UnifiedStorySystem
var signal_received: bool
var last_signal_data: Dictionary

func before_each() -> void:
	story_system = UnifiedStorySystem.new()
	add_child(story_system)
	signal_received = false
	last_signal_data = {}
	
	story_system.quest_added.connect(_on_signal_received.bind("quest_added"))
	story_system.quest_completed.connect(_on_signal_received.bind("quest_completed"))
	story_system.quest_failed.connect(_on_signal_received.bind("quest_failed"))
	story_system.story_progressed.connect(_on_signal_received.bind("story_progressed"))

func after_each() -> void:
	story_system.queue_free()
	story_system = null

func _on_signal_received(signal_name: String) -> void:
	signal_received = true
	last_signal_data["signal_name"] = signal_name

func test_initialization() -> void:
	assert_eq(story_system.get_active_quests().size(), 0, "Should start with no active quests")
	assert_eq(story_system.get_completed_quests().size(), 0, "Should start with no completed quests")
	assert_eq(story_system.get_story_progress(), 0, "Should start with no story progress")

func test_add_quest() -> void:
	var quest = StoryQuestData.new()
	quest.quest_id = "test_quest"
	quest.quest_title = "Test Quest"
	quest.quest_type = GameEnums.QuestType.STORY
	
	story_system.add_quest(quest)
	assert_eq(story_system.get_active_quests().size(), 1, "Should add quest to active quests")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit quest_added signal")
	assert_eq(last_signal_data.signal_name, "quest_added", "Should emit correct signal")

func test_complete_quest() -> void:
	var quest = StoryQuestData.new()
	quest.quest_id = "test_quest"
	quest.quest_title = "Test Quest"
	quest.quest_type = GameEnums.QuestType.STORY
	
	story_system.add_quest(quest)
	story_system.complete_quest(quest)
	
	assert_eq(story_system.get_active_quests().size(), 0, "Should remove from active quests")
	assert_eq(story_system.get_completed_quests().size(), 1, "Should add to completed quests")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit quest_completed signal")
	assert_eq(last_signal_data.signal_name, "quest_completed", "Should emit correct signal")

func test_fail_quest() -> void:
	var quest = StoryQuestData.new()
	quest.quest_id = "test_quest"
	quest.quest_title = "Test Quest"
	quest.quest_type = GameEnums.QuestType.STORY
	
	story_system.add_quest(quest)
	story_system.fail_quest(quest)
	
	assert_eq(story_system.get_active_quests().size(), 0, "Should remove from active quests")
	assert_eq(story_system.get_failed_quests().size(), 1, "Should add to failed quests")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit quest_failed signal")
	assert_eq(last_signal_data.signal_name, "quest_failed", "Should emit correct signal")

func test_story_progression() -> void:
	story_system.advance_story()
	assert_eq(story_system.get_story_progress(), 1, "Should increment story progress")
	
	await get_tree().create_timer(0.1).timeout
	assert_true(signal_received, "Should emit story_progressed signal")
	assert_eq(last_signal_data.signal_name, "story_progressed", "Should emit correct signal")

func test_quest_tracking() -> void:
	var quest = StoryQuestData.new()
	quest.quest_id = "test_quest"
	quest.quest_title = "Test Quest"
	quest.quest_type = GameEnums.QuestType.STORY
	
	story_system.add_quest(quest)
	assert_not_null(story_system.get_quest("test_quest"), "Should track quest by ID")
	assert_eq(story_system.get_quest("test_quest").quest_title, "Test Quest", "Should preserve quest data")

func test_quest_requirements() -> void:
	var quest = StoryQuestData.new()
	quest.quest_id = "test_quest"
	quest.quest_title = "Test Quest"
	quest.quest_type = GameEnums.QuestType.STORY
	
	var requirement = {
		"type": GameEnums.ResourceType.REPUTATION,
		"value": 5,
		"met": false
	}
	quest.add_requirement(requirement)
	
	story_system.add_quest(quest)
	assert_false(story_system.can_start_quest(quest), "Should not allow starting quest with unmet requirements")
	
	quest.update_requirement(0, true)
	assert_true(story_system.can_start_quest(quest), "Should allow starting quest with met requirements")

func test_serialization() -> void:
	var quest = StoryQuestData.new()
	quest.quest_id = "test_quest"
	quest.quest_title = "Test Quest"
	quest.quest_type = GameEnums.QuestType.STORY
	
	story_system.add_quest(quest)
	story_system.advance_story()
	
	var data = story_system.serialize()
	var new_system = UnifiedStorySystem.new()
	new_system.deserialize(data)
	
	assert_eq(new_system.get_active_quests().size(), story_system.get_active_quests().size(), "Should preserve active quests")
	assert_eq(new_system.get_completed_quests().size(), story_system.get_completed_quests().size(), "Should preserve completed quests")
	assert_eq(new_system.get_story_progress(), story_system.get_story_progress(), "Should preserve story progress")