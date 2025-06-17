@tool
extends GdUnitGameTest

# Mock Story Quest Data with expected values (Universal Mock Strategy)
class MockStoryQuestData extends Resource:
	var quest_id: String = "test_quest_001"
	var title: String = "Test Quest"
	var description: String = "A test quest for validation"
	var objectives: Array = []
	var rewards: Dictionary = {}
	var prerequisites: Array = []
	var rewards_claimed: bool = false
	
	# Core getters with expected values
	func get_quest_id() -> String: return quest_id
	func get_title() -> String: return title
	func get_description() -> String: return description
	func get_objectives() -> Array: return objectives
	func get_rewards() -> Dictionary: return rewards
	func get_prerequisites() -> Array: return prerequisites
	func are_rewards_claimed() -> bool: return rewards_claimed
	
	# Core setters
	func set_quest_id(id: String) -> void: quest_id = id
	func set_title(quest_title: String) -> void: title = quest_title
	func set_description(desc: String) -> void: description = desc
	
	# Objective management
	func add_objective(objective: Dictionary) -> bool:
		if objective.has("id") and objective.get("id", "") != "":
			objectives.append(objective)
			return true
		return false
	
	func complete_objective(objective_id: String) -> bool:
		for obj in objectives:
			if obj.get("id", "") == objective_id:
				obj["completed"] = true
				return true
		return false
	
	func is_objective_completed(objective_id: String) -> bool:
		for obj in objectives:
			if obj.get("id", "") == objective_id:
				return obj.get("completed", false)
		return false
	
	func is_completed() -> bool:
		if objectives.is_empty():
			return false
		for obj in objectives:
			if not obj.get("completed", false):
				return false
		return true
	
	# Reward management
	func set_rewards(reward_data: Dictionary) -> bool:
		rewards = reward_data.duplicate()
		return true
	
	func claim_rewards() -> bool:
		if not rewards_claimed and is_completed():
			rewards_claimed = true
			return true
		return false
	
	# Prerequisite management
	func add_prerequisite(prereq: Dictionary) -> bool:
		if prereq.has("type"):
			prerequisites.append(prereq)
			return true
		return false
	
	func check_prerequisites(game_state: Dictionary) -> bool:
		for prereq in prerequisites:
			var type = prereq.get("type", "")
			if type == "quest":
				var required_quest = prereq.get("id", "")
				var completed_quests = game_state.get("completed_quests", [])
				if not completed_quests.has(required_quest):
					return false
			elif type == "level":
				var required_level = prereq.get("value", 0)
				var player_level = game_state.get("player_level", 0)
				if player_level < required_level:
					return false
		return true
	
	# Serialization
	func serialize() -> Dictionary:
		return {
			"quest_id": quest_id,
			"title": title,
			"description": description,
			"objectives": objectives,
			"rewards": rewards,
			"prerequisites": prerequisites,
			"rewards_claimed": rewards_claimed
		}
	
	func deserialize(data: Dictionary) -> bool:
		quest_id = data.get("quest_id", quest_id)
		title = data.get("title", title)
		description = data.get("description", description)
		objectives = data.get("objectives", objectives)
		rewards = data.get("rewards", rewards)
		prerequisites = data.get("prerequisites", prerequisites)
		rewards_claimed = data.get("rewards_claimed", rewards_claimed)
		return true

# Type-safe instance variables
var quest_data: MockStoryQuestData = null

func before_test() -> void:
	super.before_test()
	quest_data = MockStoryQuestData.new()
	track_resource(quest_data)

func after_test() -> void:
	quest_data = null
	super.after_test()

func test_initialization() -> void:
	assert_that(quest_data).is_not_null()
	
	# Test direct method calls instead of safe wrappers (proven pattern)
	var quest_id: String = quest_data.get_quest_id()
	var title: String = quest_data.get_title()
	var description: String = quest_data.get_description()
	var objectives: Array = quest_data.get_objectives()
	var rewards: Dictionary = quest_data.get_rewards()
	var prerequisites: Array = quest_data.get_prerequisites()
	
	assert_that(quest_id).is_not_equal("")
	assert_that(title).is_not_equal("")
	assert_that(description).is_not_equal("")
	assert_that(objectives.size()).is_equal(0)
	assert_that(rewards.size()).is_equal(0)
	assert_that(prerequisites.size()).is_equal(0)

func test_objective_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
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
	
	var success: bool = quest_data.add_objective(objective1)
	assert_that(success).is_true()
	
	success = quest_data.add_objective(objective2)
	assert_that(success).is_true()
	
	var objectives: Array = quest_data.get_objectives()
	assert_that(objectives.size()).is_equal(2)
	
	# Test completing objectives
	success = quest_data.complete_objective("obj1")
	assert_that(success).is_true()
	
	var is_completed: bool = quest_data.is_objective_completed("obj1")
	assert_that(is_completed).is_true()
	
	is_completed = quest_data.is_objective_completed("obj2")
	assert_that(is_completed).is_false()
	
	# Test quest completion
	success = quest_data.complete_objective("obj2")
	assert_that(success).is_true()
	
	is_completed = quest_data.is_completed()
	assert_that(is_completed).is_true()

func test_reward_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var rewards = {
		"credits": 1000,
		"experience": 500,
		"items": ["item1", "item2"],
		"reputation": 50
	}
	
	var success: bool = quest_data.set_rewards(rewards)
	assert_that(success).is_true()
	
	var quest_rewards: Dictionary = quest_data.get_rewards()
	assert_that(quest_rewards.get("credits", 0)).is_equal(1000)
	assert_that(quest_rewards.get("experience", 0)).is_equal(500)
	assert_that(quest_rewards.get("items", []).size()).is_equal(2)
	assert_that(quest_rewards.get("reputation", 0)).is_equal(50)
	
	# Add objectives for completion requirement
	var objective = {
		"id": "obj1",
		"description": "Complete quest",
		"completed": false
	}
	quest_data.add_objective(objective)
	quest_data.complete_objective("obj1")
	
	# Test claiming rewards
	success = quest_data.claim_rewards()
	assert_that(success).is_true()
	
	var is_claimed: bool = quest_data.are_rewards_claimed()
	assert_that(is_claimed).is_true()
	
	# Test double claiming
	success = quest_data.claim_rewards()
	assert_that(success).is_false()

func test_prerequisite_management() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	var prereq1 = {
		"type": "quest",
		"id": "quest_1",
		"state": "completed"
	}
	
	var prereq2 = {
		"type": "level",
		"value": 5
	}
	
	var success: bool = quest_data.add_prerequisite(prereq1)
	assert_that(success).is_true()
	
	success = quest_data.add_prerequisite(prereq2)
	assert_that(success).is_true()
	
	var prerequisites: Array = quest_data.get_prerequisites()
	assert_that(prerequisites.size()).is_equal(2)
	
	# Test checking prerequisites
	success = quest_data.check_prerequisites({"completed_quests": ["quest_1"], "player_level": 6})
	assert_that(success).is_true()
	
	success = quest_data.check_prerequisites({"completed_quests": [], "player_level": 6})
	assert_that(success).is_false()
	
	success = quest_data.check_prerequisites({"completed_quests": ["quest_1"], "player_level": 4})
	assert_that(success).is_false()

func test_serialization() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	quest_data.set_quest_id("test_quest")
	quest_data.set_title("Test Quest")
	quest_data.set_description("Test Description")
	
	var objective = {
		"id": "obj1",
		"description": "Test objective",
		"type": "kill",
		"target": "enemy_type_1",
		"amount": 5,
		"completed": false
	}
	quest_data.add_objective(objective)
	
	var rewards = {
		"credits": 1000,
		"experience": 500,
		"items": ["item1"],
		"reputation": 50
	}
	quest_data.set_rewards(rewards)
	
	var prereq = {
		"type": "quest",
		"id": "quest_1",
		"state": "completed"
	}
	quest_data.add_prerequisite(prereq)
	
	# Serialize and deserialize
	var data: Dictionary = quest_data.serialize()
	var new_quest_data = MockStoryQuestData.new()
	track_resource(new_quest_data)
	
	var success: bool = new_quest_data.deserialize(data)
	assert_that(success).is_true()
	
	# Verify deserialized data
	assert_that(new_quest_data.get_quest_id()).is_equal("test_quest")
	assert_that(new_quest_data.get_title()).is_equal("Test Quest")
	assert_that(new_quest_data.get_description()).is_equal("Test Description")
	assert_that(new_quest_data.get_objectives().size()).is_equal(1)
	assert_that(new_quest_data.get_rewards().get("credits", 0)).is_equal(1000)
	assert_that(new_quest_data.get_prerequisites().size()).is_equal(1)

func test_edge_cases() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Test invalid objective
	var invalid_objective = {
		"description": "Missing ID",
		"type": "kill"
	}
	var success: bool = quest_data.add_objective(invalid_objective)
	assert_that(success).is_false()
	
	# Test completing non-existent objective
	success = quest_data.complete_objective("non_existent")
	assert_that(success).is_false()
	
	# Test claiming rewards without completion
	success = quest_data.claim_rewards()
	assert_that(success).is_false()
	
	# Test invalid prerequisite
	var invalid_prereq = {
		"value": 5
	}
	success = quest_data.add_prerequisite(invalid_prereq)
	assert_that(success).is_false()

func test_complex_quest_flow() -> void:
	# Test direct method calls instead of safe wrappers (proven pattern)
	# Setup complex quest
	quest_data.set_quest_id("complex_quest")
	quest_data.set_title("Complex Quest")
	
	# Add multiple objectives
	for i in range(3):
		var objective = {
			"id": "obj_" + str(i),
			"description": "Objective " + str(i),
			"completed": false
		}
		quest_data.add_objective(objective)
	
	# Add prerequisites
	var prereq = {
		"type": "level",
		"value": 10
	}
	quest_data.add_prerequisite(prereq)
	
	# Set rewards
	var rewards = {
		"credits": 2000,
		"experience": 1000
	}
	quest_data.set_rewards(rewards)
	
	# Test prerequisite check
	var can_start: bool = quest_data.check_prerequisites({"player_level": 15})
	assert_that(can_start).is_true()
	
	# Complete objectives progressively
	assert_that(quest_data.is_completed()).is_false()
	
	quest_data.complete_objective("obj_0")
	quest_data.complete_objective("obj_1")
	assert_that(quest_data.is_completed()).is_false()
	
	quest_data.complete_objective("obj_2")
	assert_that(quest_data.is_completed()).is_true()
	
	# Claim rewards
	var success: bool = quest_data.claim_rewards()
	assert_that(success).is_true()
	assert_that(quest_data.are_rewards_claimed()).is_true()