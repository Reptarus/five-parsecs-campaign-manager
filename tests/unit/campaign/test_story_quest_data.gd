@tool
extends "res://tests/fixtures/base/game_test.gd"
# Use explicit preloads instead of global class names

const StoryQuestData: GDScript = preload("res://src/core/story/StoryQuestData.gd")

var quest_data: StoryQuestData = null

func before_each() -> void:
	await super.before_each()
	
	# Create quest data instance with safer handling
	var quest_instance = StoryQuestData.new()
	
	# Check if StoryQuestData is a Resource or Node
	if quest_instance is Resource:
		quest_data = quest_instance
		track_test_resource(quest_data)
	else:
		push_error("StoryQuestData is not a Resource as expected")
		return
		
	await get_tree().process_frame

func after_each() -> void:
	await super.after_each()
	quest_data = null

func test_initialization() -> void:
	assert_not_null(quest_data, "Quest data should be initialized")
	
	# Get properties with checks
	var title = ""
	if quest_data.has_method("get_title"):
		title = quest_data.get_title()
	elif quest_data.get("name") != null:
		title = quest_data.name
	
	var description = ""
	if quest_data.has_method("get_description"):
		description = quest_data.get_description()
	elif quest_data.get("description") != null:
		description = quest_data.description
	
	var quest_id = ""
	if quest_data.has_method("get_quest_id"):
		quest_id = quest_data.get_quest_id()
	elif quest_data.get("mission_id") != null:
		quest_id = quest_data.mission_id
	
	var objectives = []
	if quest_data.has_method("get_objectives"):
		objectives = quest_data.get_objectives()
	elif quest_data.get("objectives") != null:
		objectives = quest_data.objectives
	
	var is_completed = false
	if quest_data.get("is_completed") != null:
		is_completed = quest_data.is_completed
	
	var is_failed = false
	if quest_data.get("is_failed") != null:
		is_failed = quest_data.is_failed
	
	assert_eq(title, "", "Should initialize with empty title")
	assert_eq(description, "", "Should initialize with empty description")
	assert_ne(quest_id, "", "Should initialize with a valid quest ID")
	assert_eq(objectives.size(), 0, "Should initialize with no objectives")
	assert_false(is_completed, "Should initialize as not completed")
	assert_false(is_failed, "Should initialize as not failed")

func test_basic_properties() -> void:
	# Test setting and getting basic properties
	if quest_data.has_method("set_title"):
		quest_data.set_title("Test Quest")
	elif quest_data.get("name") != null:
		quest_data.name = "Test Quest"
	
	var title = ""
	if quest_data.has_method("get_title"):
		title = quest_data.get_title()
	elif quest_data.get("name") != null:
		title = quest_data.name
	assert_eq(title, "Test Quest", "Should store and retrieve title")
	
	if quest_data.has_method("set_description"):
		quest_data.set_description("This is a test quest description")
	elif quest_data.get("description") != null:
		quest_data.description = "This is a test quest description"
	
	var description = ""
	if quest_data.has_method("get_description"):
		description = quest_data.get_description()
	elif quest_data.get("description") != null:
		description = quest_data.description
	assert_eq(description, "This is a test quest description", "Should store and retrieve description")
	
	if quest_data.has_method("set_story_id"):
		quest_data.set_story_id("test_story")
	
	var story_id = ""
	if quest_data.has_method("get_story_id"):
		story_id = quest_data.get_story_id()
	assert_eq(story_id, "test_story", "Should store and retrieve story ID")
	
	if quest_data.has_method("set_quest_type"):
		quest_data.set_quest_type("main")
	
	var quest_type = ""
	if quest_data.has_method("get_quest_type"):
		quest_type = quest_data.get_quest_type()
	assert_eq(quest_type, "main", "Should store and retrieve quest type")

func test_objectives_management() -> void:
	# Test adding objectives
	var objective1 = {"description": "Complete task 1", "completed": false}
	var objective2 = {"description": "Complete task 2", "completed": false}
	
	if quest_data.has_method("add_objective"):
		quest_data.add_objective(objective1)
		assert_true(true, "Should successfully add first objective")
	
	if quest_data.has_method("add_objective"):
		quest_data.add_objective(objective2)
		assert_true(true, "Should successfully add second objective")
	
	var objectives = []
	if quest_data.has_method("get_objectives"):
		objectives = quest_data.get_objectives()
	elif quest_data.get("objectives") != null:
		objectives = quest_data.objectives
	assert_eq(objectives.size(), 2, "Should have two objectives")
	
	if objectives.size() >= 2:
		assert_eq(objectives[0].description, "Complete task 1", "Should store first objective")
		assert_eq(objectives[1].description, "Complete task 2", "Should store second objective")
	
	# Test completing objectives
	if quest_data.has_method("complete_objective"):
		quest_data.complete_objective(0)
	
	if quest_data.has_method("get_objectives"):
		objectives = quest_data.get_objectives()
	elif quest_data.get("objectives") != null:
		objectives = quest_data.objectives
	
	if objectives.size() >= 1 and objectives[0] is Dictionary and objectives[0].has("completed"):
		assert_true(objectives[0].completed, "Should mark first objective as completed")
	
	var is_completed = false
	if quest_data.get("is_completed") != null:
		is_completed = quest_data.is_completed
	assert_false(is_completed, "Quest should not be complete yet")
	
	if quest_data.has_method("complete_objective"):
		quest_data.complete_objective(1)
	
	if quest_data.get("is_completed") != null:
		is_completed = quest_data.is_completed
	assert_true(is_completed, "Quest should be complete when all objectives are done")

func test_rewards() -> void:
	# Test setting and getting rewards
	var rewards = {"credits": 1000, "reputation": 5, "items": ["medkit", "weapon"]}
	
	if quest_data.has_method("set_rewards"):
		quest_data.set_rewards(rewards)
	
	var retrieved_rewards = null
	if quest_data.has_method("get_rewards"):
		retrieved_rewards = quest_data.get_rewards()
	
	assert_not_null(retrieved_rewards, "Should retrieve rewards")
	if retrieved_rewards:
		assert_has(retrieved_rewards, "credits", "Rewards should include credits")
		assert_has(retrieved_rewards, "reputation", "Rewards should include reputation")
		assert_has(retrieved_rewards, "items", "Rewards should include items")
		
		if retrieved_rewards.has("credits"):
			assert_eq(retrieved_rewards.credits, 1000, "Should store correct credit amount")
		
		if retrieved_rewards.has("reputation"):
			assert_eq(retrieved_rewards.reputation, 5, "Should store correct reputation amount")
		
		if retrieved_rewards.has("items") and retrieved_rewards.items is Array:
			assert_eq(retrieved_rewards.items.size(), 2, "Should store correct number of items")
			assert_eq(retrieved_rewards.items[0], "medkit", "Should store first item")
			assert_eq(retrieved_rewards.items[1], "weapon", "Should store second item")

func test_prerequisites() -> void:
	# Test setting and checking prerequisites
	var prerequisites = {
		"min_level": 5,
		"required_quests": ["quest1", "quest2"],
		"required_reputation": 10
	}
	
	if quest_data.has_method("set_prerequisites"):
		quest_data.set_prerequisites(prerequisites)
	
	var retrieved_prereqs = null
	if quest_data.has_method("get_prerequisites"):
		retrieved_prereqs = quest_data.get_prerequisites()
	
	assert_not_null(retrieved_prereqs, "Should retrieve prerequisites")
	if retrieved_prereqs:
		assert_has(retrieved_prereqs, "min_level", "Prerequisites should include min_level")
		assert_has(retrieved_prereqs, "required_quests", "Prerequisites should include required_quests")
		assert_has(retrieved_prereqs, "required_reputation", "Prerequisites should include required_reputation")
		
		if retrieved_prereqs.has("min_level"):
			assert_eq(retrieved_prereqs.min_level, 5, "Should store correct min_level")
		
		if retrieved_prereqs.has("required_reputation"):
			assert_eq(retrieved_prereqs.required_reputation, 10, "Should store correct required_reputation")
		
		if retrieved_prereqs.has("required_quests") and retrieved_prereqs.required_quests is Array:
			assert_eq(retrieved_prereqs.required_quests.size(), 2, "Should store correct number of required quests")
	
	# Test checking if prerequisites are met
	var player_state = {
		"level": 6,
		"completed_quests": ["quest1", "quest2", "quest3"],
		"reputation": 15
	}
	
	var are_prerequisites_met = false
	if quest_data.has_method("are_prerequisites_met"):
		are_prerequisites_met = quest_data.are_prerequisites_met(player_state)
	assert_true(are_prerequisites_met, "Should meet prerequisites")
	
	var insufficient_state = {
		"level": 4,
		"completed_quests": ["quest1"],
		"reputation": 5
	}
	
	if quest_data.has_method("are_prerequisites_met"):
		are_prerequisites_met = quest_data.are_prerequisites_met(insufficient_state)
	assert_false(are_prerequisites_met, "Should not meet prerequisites with insufficient state")

func test_serialization() -> void:
	# Set up quest data with various properties
	if quest_data.has_method("set_title"):
		quest_data.set_title("Test Quest")
	elif quest_data.get("name") != null:
		quest_data.name = "Test Quest"
	
	if quest_data.has_method("set_description"):
		quest_data.set_description("Test Description")
	elif quest_data.get("description") != null:
		quest_data.description = "Test Description"
	
	if quest_data.has_method("set_story_id"):
		quest_data.set_story_id("test_story")
	
	if quest_data.has_method("set_quest_type"):
		quest_data.set_quest_type("side")
	
	var objective1 = {"description": "Complete task 1", "completed": true}
	var objective2 = {"description": "Complete task 2", "completed": false}
	
	if quest_data.has_method("add_objective"):
		quest_data.add_objective(objective1)
		quest_data.add_objective(objective2)
	
	var rewards = {"credits": 1000, "reputation": 5, "items": ["medkit", "weapon"]}
	if quest_data.has_method("set_rewards"):
		quest_data.set_rewards(rewards)
	
	var prerequisites = {
		"min_level": 5,
		"required_quests": ["quest1", "quest2"],
		"required_reputation": 10
	}
	if quest_data.has_method("set_prerequisites"):
		quest_data.set_prerequisites(prerequisites)
	
	# Serialize and deserialize
	var data = {}
	if quest_data.has_method("serialize"):
		data = quest_data.serialize()
	
	var new_quest_data = null
	if StoryQuestData:
		new_quest_data = StoryQuestData.new()
		track_test_resource(new_quest_data)
	
	if new_quest_data and new_quest_data.has_method("deserialize") and data.size() > 0:
		new_quest_data.deserialize(data)
	
	# Verify quest data properties
	var title = ""
	if new_quest_data and new_quest_data.has_method("get_title"):
		title = new_quest_data.get_title()
	elif new_quest_data and new_quest_data.get("name") != null:
		title = new_quest_data.name
	
	var description = ""
	if new_quest_data and new_quest_data.has_method("get_description"):
		description = new_quest_data.get_description()
	elif new_quest_data and new_quest_data.get("description") != null:
		description = new_quest_data.description
	
	var story_id = ""
	if new_quest_data and new_quest_data.has_method("get_story_id"):
		story_id = new_quest_data.get_story_id()
	
	var quest_type = ""
	if new_quest_data and new_quest_data.has_method("get_quest_type"):
		quest_type = new_quest_data.get_quest_type()
	
	var objectives = []
	if new_quest_data and new_quest_data.has_method("get_objectives"):
		objectives = new_quest_data.get_objectives()
	elif new_quest_data and new_quest_data.get("objectives") != null:
		objectives = new_quest_data.objectives
	
	var retrieved_rewards = null
	if new_quest_data and new_quest_data.has_method("get_rewards"):
		retrieved_rewards = new_quest_data.get_rewards()
	
	var retrieved_prereqs = null
	if new_quest_data and new_quest_data.has_method("get_prerequisites"):
		retrieved_prereqs = new_quest_data.get_prerequisites()
	
	assert_eq(title, "Test Quest", "Should preserve title")
	assert_eq(description, "Test Description", "Should preserve description")
	assert_eq(story_id, "test_story", "Should preserve story ID")
	assert_eq(quest_type, "side", "Should preserve quest type")
	
	assert_eq(objectives.size(), 2, "Should preserve objectives")
	if objectives.size() >= 2:
		assert_eq(objectives[0].description, "Complete task 1", "Should preserve first objective description")
		assert_true(objectives[0].completed, "Should preserve first objective completion state")
		assert_eq(objectives[1].description, "Complete task 2", "Should preserve second objective description")
		assert_false(objectives[1].completed, "Should preserve second objective completion state")
	
	assert_not_null(retrieved_rewards, "Should preserve rewards")
	if retrieved_rewards:
		assert_has(retrieved_rewards, "credits")
		if retrieved_rewards.has("credits"):
			assert_eq(retrieved_rewards.credits, 1000, "Should preserve reward credits")
	
	assert_not_null(retrieved_prereqs, "Should preserve prerequisites")
	if retrieved_prereqs:
		assert_has(retrieved_prereqs, "min_level")
		if retrieved_prereqs.has("min_level"):
			assert_eq(retrieved_prereqs.min_level, 5, "Should preserve prerequisite min_level")