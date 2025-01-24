extends "res://addons/gut/test.gd"

var quest_data: StoryQuestData

func before_each() -> void:
	quest_data = StoryQuestData.new()
	quest_data.quest_id = "test_quest"
	quest_data.quest_title = "Test Quest"
	quest_data.quest_type = GameEnums.QuestType.STORY
	quest_data.quest_status = GameEnums.QuestStatus.ACTIVE

func after_each() -> void:
	quest_data = null

func test_initialization() -> void:
	assert_eq(quest_data.quest_id, "test_quest", "Should set quest ID")
	assert_eq(quest_data.quest_title, "Test Quest", "Should set quest title")
	assert_eq(quest_data.quest_type, GameEnums.QuestType.STORY, "Should set quest type")
	assert_eq(quest_data.quest_status, GameEnums.QuestStatus.ACTIVE, "Should set quest status")

func test_quest_objectives() -> void:
	var objective = {
		"id": 1,
		"description": "Test Objective",
		"completed": false,
		"required": true
	}
	
	quest_data.add_objective(objective)
	assert_eq(quest_data.get_objectives().size(), 1, "Should add objective")
	assert_false(quest_data.completed, "Quest should not be completed")
	
	quest_data.complete_objective(1)
	assert_true(quest_data.get_objective(1).completed, "Should complete objective")
	assert_true(quest_data.completed, "Quest should be completed")

func test_quest_rewards() -> void:
	var reward = {
		"type": GameEnums.ResourceType.CREDITS,
		"amount": 1000,
		"claimed": false
	}
	
	quest_data.add_reward(reward)
	assert_eq(quest_data.get_rewards().size(), 1, "Should add reward")
	assert_false(quest_data.rewards_claimed, "Rewards should not be claimed")
	
	quest_data.claim_reward(0)
	assert_true(quest_data.get_rewards()[0].claimed, "Should claim reward")
	assert_true(quest_data.rewards_claimed, "All rewards should be claimed")

func test_quest_requirements() -> void:
	var requirement = {
		"type": GameEnums.ResourceType.REPUTATION,
		"value": 5,
		"met": false
	}
	
	quest_data.add_requirement(requirement)
	assert_eq(quest_data.get_requirements().size(), 1, "Should add requirement")
	assert_false(quest_data.requirements_met, "Requirements should not be met")
	
	quest_data.update_requirement(0, true)
	assert_true(quest_data.get_requirements()[0].met, "Should update requirement")
	assert_true(quest_data.requirements_met, "Requirements should be met")

func test_quest_location() -> void:
	var location = {
		"id": "loc_1",
		"name": "Test Location",
		"type": GameEnums.LocationType.TRADE_CENTER,
		"coordinates": Vector2(100, 100)
	}
	
	quest_data.set_location(location)
	assert_not_null(quest_data.get_location(), "Should set location")
	assert_eq(quest_data.get_location().id, "loc_1", "Should preserve location ID")
	assert_eq(quest_data.get_location().type, GameEnums.LocationType.TRADE_CENTER, "Should preserve location type")

func test_quest_progress() -> void:
	quest_data.set_progress(50)
	assert_eq(quest_data.get_progress(), 50, "Should set progress")
	
	quest_data.increment_progress(25)
	assert_eq(quest_data.get_progress(), 75, "Should increment progress")
	
	quest_data.increment_progress(50)
	assert_eq(quest_data.get_progress(), 100, "Should clamp progress at maximum")

func test_quest_completion() -> void:
	quest_data.complete_quest()
	assert_eq(quest_data.quest_status, GameEnums.QuestStatus.COMPLETED, "Should mark quest as completed")
	assert_true(quest_data.completed, "Should report quest as completed")
	
	quest_data.fail_quest()
	assert_eq(quest_data.quest_status, GameEnums.QuestStatus.FAILED, "Should mark quest as failed")
	assert_false(quest_data.completed, "Should report quest as not completed")

func test_serialization() -> void:
	quest_data.quest_id = "test_quest"
	quest_data.quest_title = "Test Quest"
	quest_data.quest_type = GameEnums.QuestType.STORY
	quest_data.quest_status = GameEnums.QuestStatus.ACTIVE
	
	var objective = {
		"id": 1,
		"description": "Test Objective",
		"completed": false,
		"required": true
	}
	quest_data.add_objective(objective)
	
	var reward = {
		"type": GameEnums.ResourceType.CREDITS,
		"amount": 1000,
		"claimed": false
	}
	quest_data.add_reward(reward)
	
	var location = {
		"id": "loc_1",
		"name": "Test Location",
		"type": GameEnums.LocationType.TRADE_CENTER,
		"coordinates": Vector2(100, 100)
	}
	quest_data.set_location(location)
	
	var data = quest_data.serialize()
	var new_quest = StoryQuestData.new()
	new_quest.deserialize(data)
	
	assert_eq(new_quest.quest_id, quest_data.quest_id, "Should preserve quest ID")
	assert_eq(new_quest.quest_title, quest_data.quest_title, "Should preserve quest title")
	assert_eq(new_quest.quest_type, quest_data.quest_type, "Should preserve quest type")
	assert_eq(new_quest.quest_status, quest_data.quest_status, "Should preserve quest status")
	assert_eq(new_quest.get_objectives().size(), quest_data.get_objectives().size(), "Should preserve objectives")
	assert_eq(new_quest.get_rewards().size(), quest_data.get_rewards().size(), "Should preserve rewards")
	assert_not_null(new_quest.get_location(), "Should preserve location")